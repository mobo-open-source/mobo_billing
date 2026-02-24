import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/currency_provider.dart';

class ProductListTile extends StatelessWidget {
  final String id;
  final String name;
  final String? defaultCode;
  final double price;
  final List? currencyId;
  final String? category;
  final int stockQuantity;
  final String? imageBase64;
  final int? variantCount;
  final bool isDark;
  final VoidCallback? onTap;

  const ProductListTile({
    Key? key,
    required this.id,
    required this.name,
    this.defaultCode,
    required this.price,
    this.currencyId,
    this.category,
    required this.stockQuantity,
    this.imageBase64,
    this.variantCount,
    required this.isDark,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductImage(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.primaryColor,
                                    letterSpacing: -0.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Consumer<CurrencyProvider>(
                                  builder: (context, currencyProvider, _) {
                                    String? currencyCode =
                                        (currencyId != null &&
                                            currencyId!.length > 1)
                                        ? currencyId![1].toString()
                                        : null;
                                    final formattedPrice = currencyProvider
                                        .formatAmount(
                                          price,
                                          currency: currencyCode,
                                        );
                                    return Text(
                                      formattedPrice,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[800],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 0),
                      child: Text(
                        "SKU: ${_getDisplaySku()}",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (category != null && category!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Text(
                              "Category:",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                category!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[900],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "$stockQuantity in stock",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white
                                    : (stockQuantity > 0
                                          ? Colors.green[700]
                                          : Colors.red[700]),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (variantCount != null && variantCount! > 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.blue[50]!,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "$variantCount variants",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.blue[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    Widget imageWidget;

    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      try {
        final base64String = imageBase64!.contains(',')
            ? imageBase64!.split(',').last
            : imageBase64!;
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(
          bytes,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(),
        );
      } catch (e) {
        imageWidget = _buildAvatarFallback();
      }
    } else {
      imageWidget = _buildAvatarFallback();
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final initials = _initialsFromName(name);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[300]!, Colors.grey[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _getDisplaySku() {
    if (defaultCode != null &&
        defaultCode!.trim().isNotEmpty &&
        defaultCode!.toLowerCase() != 'false' &&
        defaultCode!.toLowerCase() != 'null') {
      return defaultCode!;
    }
    return '—';
  }

  String _initialsFromName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '?';

    final clean = trimmed.replaceAll(RegExp(r"\s+"), ' ');
    return clean.length >= 2
        ? clean.substring(0, 2).toUpperCase()
        : clean[0].toUpperCase();
  }
}
