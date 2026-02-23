import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/odoo_api_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/dashboard_metric_card.dart';
import '../../widgets/shimmer_loading.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final OdooApiService _apiService = OdooApiService();
  bool _isLoading = true;
  String _error = '';

  String _selectedRange = 'Last 30 Days';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Map<String, double> _summaryStats = {
    'total_invoiced': 0.0,
    'total_paid': 0.0,
    'total_due': 0.0,
    'invoice_count': 0.0,
  };

  List<FlSpot> _trendData = [];
  double _maxTrendValue = 0;
  List<String> _trendLabels = [];

  Map<String, double> _statusDistribution = {};
  List<Map<String, dynamic>> _topCustomers = [];

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is bool) return 0.0;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _updateDateRange(String range) {
    final now = DateTime.now();
    setState(() {
      _selectedRange = range;
      switch (range) {
        case 'Last 7 Days':
          _startDate = now.subtract(const Duration(days: 7));
          break;
        case 'Last 30 Days':
          _startDate = now.subtract(const Duration(days: 30));
          break;
        case 'Last 90 Days':
          _startDate = now.subtract(const Duration(days: 90));
          break;
        case 'This Year':
          _startDate = DateTime(now.year, 1, 1);
          break;
      }
      _endDate = now;
    });
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      await Future.wait([
        _fetchSummaryStats(),
        _fetchTrendData(),
        _fetchStatusDistribution(),
        _fetchTopCustomers(),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Reports loading timed out after 30 seconds');
        },
      );
    } on TimeoutException catch (e) {
      _error = 'Request timed out. Please check your connection and try again.';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchSummaryStats() async {
    final domain = [
      ['move_type', '=', 'out_invoice'],
      ['state', '=', 'posted'],
      ['invoice_date', '>=', DateFormat('yyyy-MM-dd').format(_startDate)],
      ['invoice_date', '<=', DateFormat('yyyy-MM-dd').format(_endDate)],
    ];

    final data = await _apiService.call('account.move', 'read_group', [
      domain,
      ['amount_total', 'amount_residual'],
      [],
    ]);

    if (data is List && data.isNotEmpty) {
      final total = _safeDouble(data[0]['amount_total']);
      final residual = _safeDouble(data[0]['amount_residual']);

      final countResult = await _apiService.call(
        'account.move',
        'search_count',
        [domain],
      );

      _summaryStats = {
        'total_invoiced': total,
        'total_paid': total - residual,
        'total_due': residual,
        'invoice_count': (countResult is int) ? countResult.toDouble() : 0.0,
      };
    }
  }

  Future<void> _fetchTrendData() async {
    final domain = [
      ['move_type', '=', 'out_invoice'],
      ['state', '=', 'posted'],
      ['invoice_date', '>=', DateFormat('yyyy-MM-dd').format(_startDate)],
      ['invoice_date', '<=', DateFormat('yyyy-MM-dd').format(_endDate)],
    ];

    String groupBy = 'invoice_date:day';
    if (_selectedRange == 'This Year' || _selectedRange == 'Last 90 Days') {
      groupBy = 'invoice_date:month';
    }

    final data = await _apiService.call('account.move', 'read_group', [
      domain,
      ['amount_total'],
      [groupBy],
    ]);

    List<FlSpot> spots = [];
    List<String> labels = [];
    double maxVal = 0;

    if (data is List) {
      data.sort((a, b) => (a[groupBy] ?? '').compareTo(b[groupBy] ?? ''));

      for (int i = 0; i < data.length; i++) {
        final amount = _safeDouble(data[i]['amount_total']);
        if (amount > maxVal) maxVal = amount;
        spots.add(FlSpot(i.toDouble(), amount));

        String rawLabel = data[i][groupBy] ?? '';

        labels.add(_formatChartLabel(rawLabel, groupBy));
      }
    }

    _trendData = spots;
    _maxTrendValue = maxVal;
    _trendLabels = labels;
  }

  String _formatChartLabel(String label, String groupBy) {
    try {
      final parts = label.split(' ');

      if (groupBy.contains('month')) {
        if (parts.isNotEmpty) {
          String month = parts[0];
          if (month.length > 3) month = month.substring(0, 3);
          return month;
        }
      } else {
        try {
          DateTime date = DateTime.parse(label);
          return DateFormat('dd MMM').format(date);
        } catch (_) {
          if (parts.length >= 2) {
            String day = parts[0];
            String month = parts[1];

            if (day.contains('-')) {
              DateTime date = DateTime.parse(day);
              return DateFormat('dd MMM').format(date);
            }
            if (month.length > 3) month = month.substring(0, 3);
            return '$day $month';
          }
        }
      }
      return label;
    } catch (e) {
      return label;
    }
  }

  Future<void> _fetchStatusDistribution() async {
    final domain = [
      ['move_type', '=', 'out_invoice'],
      ['state', '=', 'posted'],
      ['invoice_date', '>=', DateFormat('yyyy-MM-dd').format(_startDate)],
      ['invoice_date', '<=', DateFormat('yyyy-MM-dd').format(_endDate)],
    ];

    final data = await _apiService.call('account.move', 'read_group', [
      domain,
      ['amount_total'],
      ['payment_state'],
    ]);

    Map<String, double> distribution = {};
    if (data is List) {
      for (var item in data) {
        String status = item['payment_state'] ?? 'Unknown';

        if (status == 'not_paid') status = 'Unpaid';
        if (status == 'paid') status = 'Paid';
        if (status == 'partial') status = 'Partial';
        if (status == 'reversed') status = 'Reversed';
        if (status == 'in_payment') status = 'In Payment';

        distribution[status] = _safeDouble(item['amount_total']);
      }
    }
    _statusDistribution = distribution;
  }

  Future<void> _fetchTopCustomers() async {
    final domain = [
      ['move_type', '=', 'out_invoice'],
      ['state', '=', 'posted'],
      ['invoice_date', '>=', DateFormat('yyyy-MM-dd').format(_startDate)],
      ['invoice_date', '<=', DateFormat('yyyy-MM-dd').format(_endDate)],
    ];

    final data = await _apiService.call(
      'account.move',
      'read_group',
      [
        domain,
        ['amount_total'],
        ['partner_id'],
      ],
      {'limit': 5, 'orderby': 'amount_total desc'},
    );

    List<Map<String, dynamic>> customers = [];
    if (data is List) {
      for (var item in data) {
        if (item['partner_id'] != null) {
          final partnerName = (item['partner_id'] is List)
              ? item['partner_id'][1]
              : 'Unknown';
          final amount = _safeDouble(item['amount_total']);
          customers.add({'name': partnerName, 'amount': amount});
        }
      }
    }

    customers.sort(
      (a, b) => (_safeDouble(b['amount'])).compareTo(_safeDouble(a['amount'])),
    );
    _topCustomers = customers.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.grey[50],
      body: Consumer2<ConnectivityService, SessionService>(
        builder: (context, connectivity, session, _) {
          if (!connectivity.isConnected) {
            return const ConnectionStatusWidget();
          }
          if (!session.hasValidSession) {
            return const ConnectionStatusWidget();
          }

          return RefreshIndicator(
            onRefresh: _loadAllData,
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateFilter(),
                      const SizedBox(height: 20),
                      if (_isLoading &&
                          _summaryStats['total_invoiced'] == 0.0 &&
                          _trendData.isEmpty)
                        const ReportsShimmerLoading()
                      else if (_error.isNotEmpty)
                        ConnectionStatusWidget(
                          serverUnreachable: true,
                          serverErrorMessage: _error,
                          onRetry: _loadAllData,
                        )
                      else ...[
                        _buildSectionTitle('Overview', isDark),
                        const SizedBox(height: 12),
                        _buildSummaryGrid(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Sales Trend', isDark),
                        const SizedBox(height: 12),
                        _buildTrendChart(),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Invoice Status', isDark),
                                  const SizedBox(height: 12),
                                  _buildStatusChart(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Top Customers', isDark),
                        const SizedBox(height: 12),
                        _buildTopCustomersList(isDark),
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
                if (_isLoading &&
                    (_summaryStats['total_invoiced'] != 0.0 ||
                        _trendData.isNotEmpty))
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'This Year']
            .map((range) {
              final isSelected = _selectedRange == range;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _updateDateRange(range),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.transparent : Colors.white),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      range,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final bool isWide = width > 700;

    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      childAspectRatio: isWide ? 1.8 : 1.6,
      children: [
        _buildSummaryCard(
          'Total Invoiced',
          _summaryStats['total_invoiced']!,
          Icons.attach_money,
          Colors.blue,
          isDark,
        ),
        _buildSummaryCard(
          'Total Paid',
          _summaryStats['total_paid']!,
          Icons.check_circle,
          Colors.green,
          isDark,
        ),
        _buildSummaryCard(
          'Due Amount',
          _summaryStats['total_due']!,
          Icons.pending,
          Colors.orange,
          isDark,
        ),
        _buildSummaryCard(
          'Invoices',
          _summaryStats['invoice_count']!,
          Icons.receipt,
          Colors.purple,
          isDark,
          isCurrency: false,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    double value,
    IconData icon,
    Color color,
    bool isDark, {
    bool isCurrency = true,
  }) {
    return Consumer<CurrencyProvider>(
      builder: (context, currency, child) {
        String subtitle = '';
        switch (title) {
          case 'Total Invoiced':
            subtitle = 'Total billed amount';
            break;
          case 'Total Paid':
            subtitle = 'Total collected amount';
            break;
          case 'Due Amount':
            subtitle = 'Total outstanding';
            break;
          case 'Invoices':
            subtitle = 'Total invoice count';
            break;
          default:
            subtitle = '';
        }

        return DashboardMetricCard(
          title: title,
          value: isCurrency
              ? currency.formatAmount(value)
              : value.toInt().toString(),
          subtitle: subtitle,
          accentColor: color,
          isCompact: true,
        );
      },
    );
  }

  Widget _buildEmptyState({double? height, required bool isDark}) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildTrendChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: _trendData.isEmpty
                ? _buildEmptyState(isDark: isDark)
                : Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _maxTrendValue > 0
                              ? _maxTrendValue / 4
                              : 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (value % 1 != 0)
                                  return const SizedBox.shrink();

                                final index = value.toInt();
                                if (index < 0 || index >= _trendLabels.length) {
                                  return const SizedBox.shrink();
                                }

                                int total = _trendLabels.length;
                                if (total > 7 &&
                                    index % (total ~/ 5) != 0 &&
                                    index != total - 1) {
                                  return const SizedBox.shrink();
                                }

                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    _trendLabels[index],
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: _maxTrendValue > 0
                                  ? _maxTrendValue / 4
                                  : 1,
                              getTitlesWidget: (value, meta) {
                                final style = TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                );
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    NumberFormat.compact().format(value),
                                    style: style,
                                  ),
                                );
                              },
                              reservedSize: 42,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (_trendData.length - 1).toDouble(),
                        minY: 0,
                        maxY: _maxTrendValue > 0 ? _maxTrendValue * 1.2 : 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _trendData,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: AppTheme.primaryColor,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.primaryColor.withOpacity(0.1),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) =>
                                isDark ? Colors.grey[800]! : Colors.white,
                            getTooltipItems:
                                (List<LineBarSpot> touchedBarSpots) {
                                  return touchedBarSpots.map((barSpot) {
                                    final index = barSpot.x.toInt();
                                    if (index < 0 ||
                                        index >= _trendLabels.length)
                                      return null;
                                    return LineTooltipItem(
                                      '${_trendLabels[index]}\n',
                                      TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: context
                                              .read<CurrencyProvider>()
                                              .formatAmount(barSpot.y),
                                          style: const TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _statusDistribution.isEmpty
          ? _buildEmptyState(isDark: isDark)
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: _statusDistribution.entries.map((entry) {
                        final color = _getStatusColor(entry.key);
                        final totalInvoiced = _summaryStats['total_invoiced']!;
                        final percentage = totalInvoiced > 0
                            ? (entry.value / totalInvoiced * 100)
                                  .toStringAsFixed(0)
                            : '0';
                        return PieChartSectionData(
                          color: color,
                          value: entry.value,
                          title: '$percentage%',
                          radius: 40,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _statusDistribution.keys.map((status) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'unpaid':
      case 'not_paid':
        return Colors.red;
      case 'partial':
        return Colors.orange;
      case 'in payment':
      case 'in_payment':
        return Colors.blue;
      case 'reversed':
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }

  Widget _buildTopCustomersList(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _topCustomers.isEmpty
          ? _buildEmptyState(height: 200, isDark: isDark)
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _topCustomers.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              itemBuilder: (context, index) {
                final customer = _topCustomers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          customer['name'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Consumer<CurrencyProvider>(
                        builder: (context, currency, _) {
                          return Text(
                            currency.formatAmount(customer['amount']),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
