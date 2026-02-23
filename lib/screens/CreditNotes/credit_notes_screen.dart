import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/credit_note_provider.dart';
import '../../widgets/shimmer_loading.dart';
import 'create_credit_note_screen.dart';
import 'credit_note_detail_screen.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/filter_badges.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/invoice_filter_bottomsheet.dart';
import 'package:intl/intl.dart';
import '../../models/invoice.dart';
import '../../widgets/custom_snackbar.dart';

class CreditNotesScreen extends StatefulWidget {
  const CreditNotesScreen({Key? key}) : super(key: key);

  @override
  State<CreditNotesScreen> createState() => _CreditNotesScreenState();
}

class _CreditNotesScreenState extends State<CreditNotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  final Set<String> _activeFilters = {};
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGroupBy;

  final Map<String, bool> _expandedGroups = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CreditNoteProvider>(
        context,
        listen: false,
      ).loadCreditNotes().then((_) {
        if (mounted) setState(() => _isFirstLoad = false);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<CreditNoteProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16.0,
                    left: 16.0,
                    right: 16.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF000000).withOpacity(0.05),
                          offset: const Offset(0, 6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      enabled: true,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xff1E1E1E),
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.normal,
                        fontSize: 15,
                        height: 1.0,
                        letterSpacing: 0.0,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search credit notes...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xff1E1E1E),
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
                          fontSize: 15,
                          height: 1.0,
                          letterSpacing: 0.0,
                        ),
                        prefixIcon: IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedFilterHorizontal,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 18,
                          ),
                          onPressed: () {
                            _showFilterBottomSheet();
                          },
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty ||
                                _activeFilters.isNotEmpty ||
                                _startDate != null ||
                                _endDate != null ||
                                _selectedGroupBy != null
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchDebounce?.cancel();
                                  setState(() {
                                    _activeFilters.clear();
                                    _startDate = null;
                                    _endDate = null;
                                    _selectedGroupBy = null;
                                  });
                                  provider.loadCreditNotes();
                                },
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              )
                            : null,

                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[850]! : Colors.white,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[850]! : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        isDense: true,
                        alignLabelWithHint: true,
                      ),
                      onChanged: (value) {
                        setState(() {});
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 350),
                          () {
                            if (!mounted) return;
                            if (value.isEmpty) {
                              provider.loadCreditNotes();
                            } else {
                              provider.searchCreditNotes(value);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 8.0,
                    left: 16.0,
                    right: 16.0,
                  ),
                  child: Row(
                    children: [
                      ActiveFiltersBadge(
                        count:
                            _activeFilters.length +
                            (_startDate != null || _endDate != null ? 1 : 0),
                        hasGroupBy: _selectedGroupBy != null,
                      ),
                      if (_selectedGroupBy != null) ...[
                        const SizedBox(width: 8),
                        GroupByPill(label: _getGroupByLabel(_selectedGroupBy!)),
                      ],

                      const Spacer(),

                      if (provider.error == null)
                        _buildTopPaginationBar(provider),
                    ],
                  ),
                ),

                Expanded(
                  child: Consumer2<ConnectivityService, SessionService>(
                    builder: (context, connectivityService, sessionService, child) {
                      if (!connectivityService.isConnected) {
                        return ConnectionStatusWidget(
                          onRetry: () {
                            if (connectivityService.isConnected &&
                                sessionService.hasValidSession) {
                              if (_searchController.text.isNotEmpty) {
                                provider.searchCreditNotes(
                                  _searchController.text,
                                );
                              } else {
                                provider.loadCreditNotes();
                              }
                            }
                          },
                          customMessage:
                              'No internet connection. Please check your connection and try again.',
                        );
                      }

                      if (provider.error != null &&
                          provider.creditNotes.isEmpty) {
                        final errorLower = provider.error!.toLowerCase();
                        if (errorLower.contains('html') ||
                            errorLower.contains('server') ||
                            errorLower.contains('connection') ||
                            errorLower.contains('connect') ||
                            errorLower.contains('socketexception') ||
                            errorLower.contains('clientexception') ||
                            errorLower.contains('timeoutexception') ||
                            errorLower.contains('timeout') ||
                            errorLower.contains('failed host lookup')) {
                          return ConnectionStatusWidget(
                            serverUnreachable: true,
                            serverErrorMessage: provider.error,
                            onRetry: () {
                              if (_searchController.text.isNotEmpty) {
                                provider.searchCreditNotes(
                                  _searchController.text,
                                );
                              } else {
                                provider.loadCreditNotes();
                              }
                            },
                          );
                        }
                      }

                      final Widget content;
                      if (_selectedGroupBy != null) {
                        content = _buildGroupedContent(provider);
                      } else if (_isFirstLoad || provider.isLoading) {
                        content = const CommonListShimmer();
                      } else if (provider.error != null) {
                        content = ConnectionStatusWidget(
                          serverUnreachable: true,
                          serverErrorMessage: provider.error,
                          onRetry: () => provider.loadCreditNotes(),
                        );
                      } else if (provider.creditNotes.isEmpty) {
                        content = EmptyStateWidget(
                          title: _hasActiveFilters()
                              ? 'No results found'
                              : 'No credit notes found',
                          subtitle: _hasActiveFilters()
                              ? 'Try adjusting your filters'
                              : 'There are no credit note records to display',
                          showClearButton: _hasActiveFilters(),
                          onClearFilters: () {
                            setState(() {
                              _activeFilters.clear();
                              _startDate = null;
                              _endDate = null;
                              _selectedGroupBy = null;
                            });
                            provider.loadCreditNotes();
                          },
                        );
                      } else {
                        content = ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: provider.creditNotes.length,
                          itemBuilder: (context, index) {
                            final creditNote = provider.creditNotes[index];
                            return _buildCreditNoteCard(creditNote);
                          },
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          try {
                            if (_searchController.text.isNotEmpty) {
                              await provider.searchCreditNotes(
                                _searchController.text,
                              );
                            } else {
                              await provider.loadCreditNotes();
                            }

                            if (provider.error != null && mounted) {
                              _showErrorSnackBar(provider.error!);
                            }
                          } catch (e) {
                            if (mounted) _showErrorSnackBar(e.toString());
                          }
                        },
                        child:
                            (provider.error != null ||
                                (provider.creditNotes.isEmpty &&
                                    _selectedGroupBy == null &&
                                    !provider.isLoading))
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: Center(child: content),
                                    ),
                                  );
                                },
                              )
                            : content,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_create_credit_note',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateCreditNoteScreen(),
            ),
          );
          if (result == true && context.mounted) {
            Provider.of<CreditNoteProvider>(
              context,
              listen: false,
            ).loadCreditNotes();
          }
        },
        backgroundColor: isDark ? Colors.white : AppTheme.primaryColor,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedFileAdd,
          color: isDark ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildTopPaginationBar(CreditNoteProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paginationText = _selectedGroupBy != null
        ? '${provider.totalCount}/${provider.totalCount}'
        : '${provider.startRecord}-${provider.endRecord}/${provider.totalCount}';

    return Container(
      padding: const EdgeInsets.only(right: 0, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paginationText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          if (_selectedGroupBy == null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (provider.hasPreviousPage && !provider.isLoading)
                      ? () => provider.goToPreviousPage()
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      size: 20,
                      color: (provider.hasPreviousPage && !provider.isLoading)
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (provider.hasNextPage && !provider.isLoading)
                      ? () => provider.goToNextPage()
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 20,
                      color: (provider.hasNextPage && !provider.isLoading)
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreditNoteCard(Invoice creditNote) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customerName = creditNote.customerName;

    final amount = creditNote.amountTotal ?? 0.0;
    final currency = creditNote.currencySymbol;

    final state = creditNote.state ?? 'draft';
    final paymentState = creditNote.paymentState ?? '';

    String name = creditNote.name ?? 'Draft Credit Note';
    if (name.toLowerCase() == 'false' || name.isEmpty) {
      name = 'Draft Credit Note';
    }

    String invoiceDate = creditNote.invoiceDate != null
        ? DateFormat('yyyy-MM-dd').format(creditNote.invoiceDate!)
        : '';

    Color statusColor;
    String statusText;

    switch (state) {
      case 'posted':
        statusColor = paymentState == 'paid' ? Colors.green : Colors.orange;
        statusText = paymentState == 'paid' ? 'Paid' : 'Posted';
        break;
      case 'draft':
        statusColor = Colors.orange;
        statusText = 'Draft';
        break;
      case 'cancel':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusText = state.isNotEmpty
            ? state.substring(0, 1).toUpperCase() + state.substring(1)
            : 'Unknown';
    }

    return InkWell(
      onTap: () async {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreditNoteDetailScreen(creditNote: creditNote),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.05),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppTheme.primaryColor,
                            letterSpacing: -0.1,
                            fontFamily: GoogleFonts.manrope().fontFamily,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (customerName != 'Unknown Customer')
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              customerName,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[300]
                                    : const Color(0xff6D717F),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                fontFamily: GoogleFonts.manrope().fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isDark ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.white : statusColor,
                        letterSpacing: 0.1,
                        fontFamily: GoogleFonts.manrope().fontFamily,
                      ),
                    ),
                  ),
                ],
              ),

              if (invoiceDate.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar03,
                        size: 14,
                        color: isDark
                            ? Colors.grey[100]
                            : const Color(0xffC5C5C5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        invoiceDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey[100]
                              : const Color(0xff6D717F),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          fontFamily: GoogleFonts.manrope().fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.grey[200]
                            : const Color(0xff5E5E5E),
                        fontFamily: GoogleFonts.manrope().fontFamily,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final formatter = Provider.of<CurrencyProvider>(
                        context,
                        listen: false,
                      );

                      final formatted = formatter.formatAmount(
                        -amount,
                        currency: currency,
                      );
                      return Text(
                        formatted,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xff101010),
                          fontFamily: GoogleFonts.manrope().fontFamily,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreditNoteDetails(Map<String, dynamic> creditNote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.receipt_long,
                              color: Colors.red.shade600,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  creditNote['name']?.toString() ??
                                      'Unknown Credit Note',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Credit Note ID: ${creditNote['id']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Credit Note Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        HugeIcons.strokeRoundedUser,
                        'Customer',
                        creditNote['partner_id'] is List
                            ? creditNote['partner_id'][1]
                            : null,
                      ),
                      _buildDetailRow(
                        HugeIcons.strokeRoundedCalendar03,
                        'Date',
                        creditNote['invoice_date'],
                      ),
                      _buildDetailRow(
                        HugeIcons.strokeRoundedCalendar03,
                        'Due Date',
                        creditNote['invoice_date_due'],
                      ),
                      Builder(
                        builder: (context) {
                          final currencyCode = creditNote['currency_id'] is List
                              ? creditNote['currency_id'][1]?.toString()
                              : null;
                          final formatted =
                              Provider.of<CurrencyProvider>(
                                context,
                                listen: false,
                              ).formatAmount(
                                (creditNote['amount_total'] ?? 0.0).toDouble(),
                                currency: currencyCode,
                              );
                          return _buildDetailRow(
                            HugeIcons.strokeRoundedMoney01,
                            'Total Amount',
                            formatted,
                          );
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final currencyCode = creditNote['currency_id'] is List
                              ? creditNote['currency_id'][1]?.toString()
                              : null;
                          final formatted =
                              Provider.of<CurrencyProvider>(
                                context,
                                listen: false,
                              ).formatAmount(
                                (creditNote['amount_residual'] ?? 0.0)
                                    .toDouble(),
                                currency: currencyCode,
                              );
                          return _buildDetailRow(
                            HugeIcons.strokeRoundedWallet01,
                            'Residual Amount',
                            formatted,
                          );
                        },
                      ),
                      _buildDetailRow(
                        HugeIcons.strokeRoundedInformationCircle,
                        'State',
                        creditNote['state'],
                      ),
                      _buildDetailRow(
                        HugeIcons.strokeRoundedCreditCard,
                        'Payment State',
                        creditNote['payment_state'],
                      ),
                      _buildDetailRow(
                        HugeIcons.strokeRoundedNote01,
                        'Reference',
                        creditNote['ref'],
                      ),
                      _buildDetailRow(
                        HugeIcons.strokeRoundedLink01,
                        'Origin',
                        creditNote['invoice_origin'],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvoiceFilterBottomSheet(
        activeFilters: _activeFilters,
        startDate: _startDate,
        endDate: _endDate,
        selectedGroupBy: _selectedGroupBy,
        onApply: (filters, start, end, groupBy) {
          setState(() {
            _activeFilters.clear();
            _activeFilters.addAll(filters);
            _startDate = start;
            _endDate = end;
            _selectedGroupBy = groupBy;
          });
          _applyFilters();
        },
      ),
    );
  }

  bool _hasActiveFilters() {
    return _activeFilters.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _selectedGroupBy != null;
  }

  String _getGroupByLabel(String key) {
    switch (key) {
      case 'state':
        return 'Status';
      case 'invoice_user_id':
        return 'Salesperson';
      case 'partner_id':
        return 'Partner';
      case 'team_id':
        return 'Sales Team';
      default:
        return key
            .split('_')
            .map((e) => e[0].toUpperCase() + e.substring(1))
            .join(' ');
    }
  }

  Widget _buildFilterIndicator() {
    if (!_hasActiveFilters()) {
      return const SizedBox.shrink();
    }

    int filterCount = 0;
    filterCount += _activeFilters.length;
    if (_startDate != null || _endDate != null) filterCount++;
    if (_selectedGroupBy != null) filterCount++;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            filterCount == 1 ? '1 filter' : '$filterCount filters',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              setState(() {
                _activeFilters.clear();
                _startDate = null;
                _endDate = null;
                _selectedGroupBy = null;
              });
              _applyFilters();
            },
            child: Icon(
              Icons.close,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyFilters() async {
    final provider = Provider.of<CreditNoteProvider>(context, listen: false);

    if (_selectedGroupBy != null) {
      final filterDomain = _buildFilterDomain();
      provider.fetchGroupSummary(
        groupByField: _selectedGroupBy!,
        customFilter: filterDomain.isNotEmpty ? filterDomain : null,
      );
    } else {
      final domain = _buildFilterDomain();
      provider.loadCreditNotes(
        offset: 0,
        limit: 40,
        customFilter: domain.isNotEmpty ? domain : null,
      );
    }
  }

  List<dynamic> _buildFilterDomain() {
    List<dynamic> domain = [];

    if (_activeFilters.isNotEmpty) {
      List<dynamic> statusConditions = [];
      for (String filter in _activeFilters) {
        switch (filter) {
          case 'draft':
            statusConditions.add(['state', '=', 'draft']);
            break;
          case 'posted':
            statusConditions.add('&');
            statusConditions.add(['state', '=', 'posted']);
            statusConditions.add(['payment_state', '=', 'not_paid']);
            break;
          case 'paid':
            statusConditions.add(['payment_state', '=', 'paid']);
            break;
          case 'partial':
            statusConditions.add(['payment_state', '=', 'partial']);
            break;
          case 'not_paid':
            statusConditions.add('&');
            statusConditions.add(['state', '=', 'posted']);
            statusConditions.add(['payment_state', '=', 'not_paid']);
            break;
          case 'in_payment':
            statusConditions.add(['payment_state', '=', 'in_payment']);
            break;
          case 'reversed':
            statusConditions.add(['payment_state', '=', 'reversed']);
            break;
          case 'blocked':
            statusConditions.add(['payment_state', '=', 'blocked']);
            break;
          case 'cancelled':
            statusConditions.add(['state', '=', 'cancel']);
            break;
        }
      }

      if (statusConditions.isNotEmpty) {
        int n = _activeFilters.length;
        if (n > 1) {
          for (int i = 0; i < n - 1; i++) {
            domain.add('|');
          }
        }
        domain.addAll(statusConditions);
      }
    }

    if (_startDate != null) {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      domain.add(['invoice_date', '>=', startDateStr]);
    }

    if (_endDate != null) {
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      domain.add(['invoice_date', '<=', endDateStr]);
    }

    return domain;
  }

  Widget _buildGroupedContent(CreditNoteProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.groupSummary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No groups found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final groups = provider.groupSummary.entries.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      itemCount: groups.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final group = groups[index];
        final groupKey = group.key;
        final count = group.value;
        final isExpanded = _expandedGroups[groupKey] ?? false;
        final loadedInvoices = provider.loadedGroups[groupKey] ?? [];

        return _buildOdooStyleGroupTile(
          groupKey,
          count,
          loadedInvoices,
          isExpanded,
          isDark,
          provider,
        );
      },
    );
  }

  Widget _buildOdooStyleGroupTile(
    String groupKey,
    int count,
    List<Invoice> loadedInvoices,
    bool isExpanded,
    bool isDark,
    CreditNoteProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.08),
            ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
              });

              if (!isExpanded && !provider.loadedGroups.containsKey(groupKey)) {
                await _loadGroupInvoices(provider, groupKey);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupKey,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count Credit Notes',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            if (loadedInvoices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: loadedInvoices.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final creditNote = loadedInvoices[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: _buildCreditNoteCard(creditNote),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _loadGroupInvoices(
    CreditNoteProvider provider,
    String groupKey,
  ) async {
    final filterDomain = _buildFilterDomain();
    await provider.loadGroupInvoices(
      groupByField: _selectedGroupBy!,
      groupKey: groupKey,
      customFilter: filterDomain.isNotEmpty ? filterDomain : null,
    );
  }

  Widget _buildDetailRow(
    List<List<dynamic>> icon,
    String label,
    dynamic value,
  ) {
    if (value == null || value == false || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    if (!mounted) return;
    CustomSnackbar.showError(
      context,
      error.contains('502')
          ? 'Server is temporarily unavailable (502). Showing cached data.'
          : 'Failed to refresh: $error',
    );
  }
}
