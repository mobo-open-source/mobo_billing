import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

bool _looksLikeImageBytes(List<int> bytes) {
  if (bytes.length < 4) return false;

  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47)
    return true;

  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;

  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;

  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50)
    return true;
  return false;
}

class OdooImageWidget extends StatelessWidget {
  final String? base64Image;
  final double? width;
  final double? height;
  final double? radius;
  final Widget? placeholder;
  final BoxFit fit;

  const OdooImageWidget({
    Key? key,
    this.base64Image,
    this.width,
    this.height,
    this.radius,
    this.placeholder,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (base64Image == null ||
        base64Image!.trim().isEmpty ||
        base64Image == 'false') {
      return placeholder ?? _buildDefaultPlaceholder(context);
    }

    try {
      var raw = base64Image!.trim();
      final dataUrlPrefix = RegExp(r'^data:image\/[a-zA-Z0-9.+-]+;base64,');
      raw = raw.replaceFirst(dataUrlPrefix, '');
      final clean = raw.replaceAll(RegExp(r'\s+'), '');
      if (clean.isEmpty) {
        return placeholder ?? _buildDefaultPlaceholder(context);
      }

      final Uint8List imageBytes = base64Decode(clean);
      if (!_looksLikeImageBytes(imageBytes)) {
        return placeholder ?? _buildDefaultPlaceholder(context);
      }

      Widget imageWidget = Image.memory(
        imageBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return placeholder ?? _buildDefaultPlaceholder(context);
        },
      );

      if (radius != null) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(radius!),
          child: imageWidget,
        );
      }

      return imageWidget;
    } catch (e) {
      return placeholder ?? _buildDefaultPlaceholder(context);
    }
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: radius != null ? BorderRadius.circular(radius!) : null,
      ),
      child: Icon(
        Icons.image,
        size: (width != null && height != null) ? (width! + height!) / 4 : 24,
        color: Theme.of(context).primaryColor.withOpacity(0.5),
      ),
    );
  }
}
