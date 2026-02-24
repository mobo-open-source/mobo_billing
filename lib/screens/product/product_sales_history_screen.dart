import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/odoo_api_service.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/custom_snackbar.dart';
import '../../theme/app_theme.dart';

class ProductSalesHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductSalesHistoryScreen({Key? key, required this.product})
      : super(key: key);

  @override
  State<ProductSalesHistoryScreen> createState() =>
      _ProductSalesHistoryScreenState();
}

class _ProductSalesHistoryScreenState extends State<ProductSalesHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _salesHistory = [];
  Map<String, dynamic> _analytics = {};
  List<FlSpot> _chartData = [];
  List<Map<String, dynamic>> _chartRawData = [];
  String _selectedPeriod = '6M';
  final Map<int, String> _orderPartnerNames = {};
  final Map<int, String> _orderDates = {};

  @override
  void initState() {
    super.initState();
    _loadSalesHistory();
  }

  Future<void> _loadSalesHistory() async {
    try {
      setState(() => _isLoading = true);

      final apiService = OdooApiService();
      final productId = widget.product['id'];


      final salesResult = await apiService.call(
        'account.move.line',
        'search_read',
        [
          [
            ['product_id', '=', productId],
            ['move_id.move_type', '=', 'out_invoice'],
            ['move_id.state', '=', 'posted']
          ]
        ],
        {
          'fields': [
            'move_id',
            'quantity',
            'price_unit',
            'price_subtotal',
            'create_date',
          ],
          'limit': 200,
          'order': 'create_date desc',
        },
      ).timeout(const Duration(seconds: 20));

      if (salesResult is List) {
        final Set<int> moveIds = {};
        for (final m in salesResult) {
          final mid = (m['move_id'] is List && m['move_id'].isNotEmpty)
              ? (m['move_id'][0] as int)
              : (m['move_id'] is int ? m['move_id'] as int : null);
          if (mid != null) moveIds.add(mid);
        }

        if (moveIds.isNotEmpty) {
          final moveInfo = await apiService.call(
            'account.move',
            'read',
            [moveIds.toList()],
            {'fields': ['id', 'name', 'partner_id', 'invoice_date', 'date']},
          ).timeout(const Duration(seconds: 20));

          if (moveInfo is List) {
            _orderPartnerNames.clear();
            _orderDates.clear();
            for (final o in moveInfo) {
              final int? id = o['id'] as int?;
              String? partnerName;
              final p = o['partner_id'];
              if (p is List && p.length > 1) {
                partnerName = p[1]?.toString();
              }
              
              final String? date = o['invoice_date']?.toString() ?? o['date']?.toString();
              
              if (id != null) {
                if (partnerName != null) _orderPartnerNames[id] = partnerName;
                if (date != null) _orderDates[id] = date;
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _salesHistory = List<Map<String, dynamic>>.from(salesResult);
            _analytics = _calculateAnalytics();
            _chartData = _generateChartData();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        CustomSnackbar.showError(context, 'Failed to load sales history: $e');
      }
    }
  }

  Map<String, dynamic> _calculateAnalytics() {
    double totalRevenue = 0;
    double totalQuantity = 0;
    Set<int> uniqueMoveIds = {};
    Set<String> uniqueCustomers = {};

    for (final sale in _salesHistory) {
      totalRevenue += (sale['price_subtotal'] ?? 0.0);
      totalQuantity += (sale['quantity'] ?? 0.0);

      final mid = (sale['move_id'] is List && sale['move_id'].isNotEmpty)
          ? (sale['move_id'][0] as int)
          : (sale['move_id'] is int ? sale['move_id'] as int : null);
      if (mid != null) {
        uniqueMoveIds.add(mid);
        final name = _orderPartnerNames[mid];
        if (name != null && name.isNotEmpty) {
          uniqueCustomers.add(name);
        }
      }
    }

    return {
      'totalRevenue': totalRevenue,
      'totalQuantity': totalQuantity,
      'totalOrders': uniqueMoveIds.length,
      'uniqueCustomers': uniqueCustomers.length,
    };
  }

  List<FlSpot> _generateChartData() {
    final Map<String, double> monthlyData = {};
    final now = DateTime.now();
    final months = _selectedPeriod == '6M' ? 6 : 12;

    _chartRawData.clear();
    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM yyyy').format(month);
      monthlyData[key] = 0;
    }

    for (final sale in _salesHistory) {
      final mid = (sale['move_id'] is List && sale['move_id'].isNotEmpty)
          ? (sale['move_id'][0] as int)
          : (sale['move_id'] is int ? sale['move_id'] as int : null);
          
      final dateStr = (mid != null ? _orderDates[mid] : null) ?? sale['create_date'];
      
      if (dateStr != null) {
        final date = DateTime.parse(dateStr);
        final monthKey = DateFormat('MMM yyyy').format(date);
        if (monthlyData.containsKey(monthKey)) {
          monthlyData[monthKey] =
              (monthlyData[monthKey] ?? 0) + (sale['price_subtotal'] ?? 0.0);
        }
      }
    }

    int index = 0;
    List<FlSpot> spots = [];
    monthlyData.forEach((key, value) {
      _chartRawData.add({'label': key, 'value': value});
      spots.add(FlSpot(index.toDouble(), value));
      index++;
    });
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales History',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              widget.product['name']?.toString() ?? 'Product',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(icon:HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          (_isLoading && _salesHistory.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadSalesHistory,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnalyticsCards(),
                        const SizedBox(height: 24),
                        _buildSalesChart(),
                        const SizedBox(height: 24),
                        _buildRecentSales(),
                      ],
                    ),
                  ),
                ),
          if (_isLoading && _salesHistory.isNotEmpty)
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
  }

  Widget _buildAnalyticsCards() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildAnalyticsCard(
              'Total Revenue',
              currencyProvider.formatAmount(_analytics['totalRevenue'] ?? 0.0),
              isDark,
            ),
            _buildAnalyticsCard(
              'Total Invoices',
              (_analytics['totalOrders'] ?? 0).toString(),
              isDark,
            ),
            _buildAnalyticsCard(
              'Units Sold',
              (_analytics['totalQuantity'] ?? 0.0).toStringAsFixed(0),
              isDark,
            ),
            _buildAnalyticsCard(
              'Unique Customers',
              (_analytics['uniqueCustomers'] ?? 0).toString(),
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: '6M', child: Text('6 Months')),
                  DropdownMenuItem(value: '12M', child: Text('12 Months')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPeriod = value;
                      _chartData = _generateChartData();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxY() / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _chartRawData.length) {
                          return const SizedBox();
                        }
                        if (_selectedPeriod == '12M' && index % 2 != 0) {
                          return const SizedBox();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _getMonthLabel(index),
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: _getMaxY() / 4,
                      getTitlesWidget: (value, meta) {
                        final style = TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        );
                        String text;
                        if (value >= 1000000) {
                          text = '${(value / 1000000).toStringAsFixed(1)}M';
                        } else if (value >= 1000) {
                          text = '${(value / 1000).toStringAsFixed(1)}K';
                        } else {
                          text = value.toStringAsFixed(0);
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(text, style: style),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => isDark ? Colors.grey[800]! : Colors.white,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final data = _chartRawData[barSpot.x.toInt()];
                        return LineTooltipItem(
                          '${data['label']}\n',
                          TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: Provider.of<CurrencyProvider>(context, listen: false)
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
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartData,
                    isCurved: true,
                    curveSmoothness: 0.35,
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
                minX: 0,
                maxX: (_chartRawData.length - 1).toDouble(),
                minY: 0,
                maxY: _getMaxY(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxY() {
    double max = 0;
    for (var spot in _chartData) {
      if (spot.y > max) max = spot.y;
    }
    return max == 0 ? 100 : max * 1.5;
  }

  String _getMonthLabel(int index) {
    final now = DateTime.now();
    final months = _selectedPeriod == '6M' ? 6 : 12;
    final month = DateTime(now.year, now.month - (months - 1 - index), 1);
    return DateFormat('MMM').format(month);
  }

  Widget _buildRecentSales() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Invoices',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_salesHistory.isEmpty)
            Center(
              child: Text(
                'No invoice history found',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _salesHistory.take(10).length,
              separatorBuilder: (context, index) => Divider(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              itemBuilder: (context, index) {
                final sale = _salesHistory[index];
                final moveId = (sale['move_id'] is List &&
                        sale['move_id'].isNotEmpty)
                    ? sale['move_id'][0] as int
                    : (sale['move_id'] is int ? sale['move_id'] as int : -1);
                final customerName =
                    _orderPartnerNames[moveId] ?? 'Unknown Customer';
                final moveName = sale['move_id'] is List
                    ? sale['move_id'][1]
                    : 'Unknown Invoice';
                final dateStr = _orderDates[moveId] ?? sale['create_date'];
                final date = dateStr != null
                    ? DateFormat('MMM dd, yyyy')
                        .format(DateTime.parse(dateStr))
                    : 'Unknown Date';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    moveName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currencyProvider.formatAmount(sale['price_subtotal'] ?? 0.0),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(sale['quantity'] ?? 0.0).toStringAsFixed(0)} units',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
