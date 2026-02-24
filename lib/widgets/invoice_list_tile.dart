import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/currency_provider.dart';

class InvoiceListTile extends StatelessWidget {
  final Invoice invoice;
  final Function() onTap;

  const InvoiceListTile({
    super.key,
    required this.invoice,
    required this.onTap,
  });

  Color getStateColor() {
    final status = invoice.state;
    final paymentState = invoice.paymentState ?? 'not_paid';

    if (status == 'posted') {
      switch (paymentState) {
        case 'paid':
          return const Color(0xFF10B981);
        case 'in_payment':
          return const Color(0xFF3B82F6);
        case 'partial':
          return const Color(0xFFF59E0B);
        case 'not_paid':
          return const Color(0xFFEF4444);
        default:
          return const Color(0xFFEF4444);
      }
    } else if (status == 'draft') {
      return const Color(0xFFF59E0B);
    } else if (status == 'cancel') {
      return const Color(0xFF6B7280);
    }
    return Colors.grey;
  }

  String getStateValue() {
    final status = invoice.state;
    final paymentState = invoice.paymentState ?? 'not_paid';

    if (status == 'posted') {
      switch (paymentState) {
        case 'paid':
          return 'Paid';
        case 'in_payment':
          return 'In Payment';
        case 'partial':
          return 'Partial';
        case 'not_paid':
          return 'Not Paid';
        default:
          return 'Posted';
      }
    } else if (status == 'draft') {
      return 'Draft';
    } else if (status == 'cancel') {
      return 'Cancelled';
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = invoice.name.isEmpty ? 'Draft Invoice' : invoice.name;

    final partnerName = invoice.customerName.isNotEmpty
        ? invoice.customerName
        : 'Unknown Customer';

    final invoiceDate = invoice.invoiceDate != null
        ? invoice.invoiceDate.toString().split(' ')[0]
        : 'N/A';

    final amount = invoice.amountTotal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
            padding: const EdgeInsets.only(
              left: 14,
              top: 14,
              bottom: 14,
              right: 14,
            ),
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
                            displayName,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFFB91C5C),
                              letterSpacing: -0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              partnerName,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[300]
                                    : const Color(0xff6D717F),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(isDark),
                  ],
                ),
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
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey[100]
                              : const Color(0xff6D717F),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey[200]
                            : const Color(0xff5E5E5E),
                      ),
                    ),
                    Consumer<CurrencyProvider>(
                      builder: (context, currencyProvider, _) {
                        final currencyId = invoice.currencyId;
                        final currencyCode =
                            (currencyId is List && currencyId.length > 1)
                            ? currencyId[1].toString()
                            : null;

                        final isCreditNote = invoice.moveType == 'out_refund';
                        final displayAmount = isCreditNote ? -amount : amount;

                        return Text(
                          currencyProvider.formatAmount(
                            displayAmount,
                            currency: currencyCode,
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xff101010),
                          ),
                          overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    final statusColor = getStateColor();
    final textColor = isDark ? Colors.white : statusColor;
    final backgroundColor = isDark
        ? Colors.white.withOpacity(0.15)
        : statusColor.withOpacity(0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        getStateValue(),
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: isDark ? FontWeight.bold : FontWeight.w600,
          color: textColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
