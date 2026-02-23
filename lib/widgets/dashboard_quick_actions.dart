import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';
import 'dashboard_empty_state.dart';

class RecentItemsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> recentItems;
  final bool isLoading;
  final bool isDark;
  final VoidCallback? onViewAll;

  const RecentItemsWidget({
    super.key,
    required this.recentItems,
    required this.isLoading,
    required this.isDark,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue Working On',
          style: TextStyle(
            fontSize: 18,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          _buildLoadingState()
        else if (recentItems.isEmpty)
          _buildEmptyState()
        else
          _buildRecentItemsList(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          constraints: const BoxConstraints(minHeight: 80),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
          child: _buildRecentItemShimmer(),
        ),
      ),
    );
  }

  Widget _buildRecentItemShimmer() {
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 11,
            width: 50,
            decoration: BoxDecoration(
              color: shimmerBase,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return DashboardEmptyStateWidget(
      title: 'No recent items',
      subtitle: 'Your recently viewed items will appear here',
      icon: HugeIcons.strokeRoundedClock01,
      isDark: isDark,
      height: 200,
    );
  }

  Widget _buildRecentItemsList() {
    return Column(
      children: recentItems
          .take(5)
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildRecentItem(item),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Unknown';
    final subtitle = item['subtitle'] ?? '';
    final lastModified = item['lastModified'] ?? '';
    final onTap = item['onTap'] as VoidCallback?;

    final iconKey = item['icon'] as String? ?? 'page';
    final type = item['type'] as String? ?? '';
    final typeColor = _getTypeColor(type);

    final icon = _getHugeIconFromKey(iconKey);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (lastModified.isNotEmpty)
            Text(
              lastModified,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }

  List<List<dynamic>> _getHugeIconFromKey(String key) {
    switch (key) {
      case 'description_outlined':
        return HugeIcons.strokeRoundedFile01;
      case 'receipt_outlined':
        return HugeIcons.strokeRoundedInvoice01;
      case 'inventory_2_outlined':
        return HugeIcons.strokeRoundedPackage;
      case 'person_outline':
        return HugeIcons.strokeRoundedUser;
      case 'settings':
        return HugeIcons.strokeRoundedSettings02;
      case 'profile':
        return HugeIcons.strokeRoundedUserCircle;
      case 'dashboard':
        return HugeIcons.strokeRoundedDashboardSquare01;
      case 'payments':
        return HugeIcons.strokeRoundedMoneyBag02;
      default:
        return HugeIcons.strokeRoundedFile01;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'quotation':
        return const Color(0xFF4CAF50);
      case 'invoice':
        return const Color(0xFFFF9800);
      case 'customer':
        return const Color(0xFF2196F3);
      case 'product':
        return const Color(0xFF9C27B0);
      case 'creditnote':
      case 'credit_note':
        return const Color(0xFF607D8B);
      case 'payment':
      case 'payments':
        return const Color(0xFF00BCD4);
      case 'receipt':
        return const Color(0xFFFF5722);
      case 'purchase':
      case 'expense':
        return const Color(0xFFE91E63);
      default:
        return Colors.grey;
    }
  }
}

class SmartSuggestionsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final bool isLoading;
  final bool isDark;

  const SmartSuggestionsWidget({
    super.key,
    required this.suggestions,
    required this.isLoading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty && !isLoading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Suggestions',
          style: TextStyle(
            fontSize: 18,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading) _buildLoadingState() else _buildSuggestionsList(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          constraints: const BoxConstraints(minHeight: 80),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SizedBox(height: 40),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Column(
      children: suggestions
          .take(3)
          .map(
            (suggestion) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black26
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedBulb,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion['title'] ?? '',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
