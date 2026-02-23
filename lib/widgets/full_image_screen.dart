import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_billing/theme/app_theme.dart';
import '../services/odoo_api_service.dart';

class FullImageScreen extends StatefulWidget {
  final Uint8List? imageBytes;
  final String? base64Image;
  final String? title;
  final String? imageName;
  final int? productId;

  const FullImageScreen({
    super.key,
    this.imageBytes,
    this.base64Image,
    this.title,
    this.imageName,
    this.productId,
  });

  @override
  State<FullImageScreen> createState() => _FullImageScreenState();
}

class _FullImageScreenState extends State<FullImageScreen> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  static const double _zoomScale = 2.5;

  bool _isLoadingHighRes = false;
  Uint8List? _highResImageBytes;
  String? _highResBase64;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _fetchHighQualityImage();
    }
  }

  Future<void> _fetchHighQualityImage() async {
    setState(() => _isLoadingHighRes = true);
    try {
      final apiService = OdooApiService();
      final result = await apiService.call(
        'product.product',
        'read',
        [
          [widget.productId],
        ],
        {
          'fields': ['image_1920'],
        },
      );

      if (result is List && result.isNotEmpty) {
        final data = result[0] as Map<String, dynamic>;
        final image1920 = data['image_1920'];

        if (image1920 is String &&
            image1920.isNotEmpty &&
            image1920 != 'false') {
          if (mounted) {
            setState(() {
              _highResBase64 = image1920;
            });
          }
        }
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingHighRes = false);
      }
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final matrix = _transformationController.value;
    if (matrix != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else if (_doubleTapDetails != null) {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(
          -position.dx * (_zoomScale - 1),
          -position.dy * (_zoomScale - 1),
        )
        ..scale(_zoomScale);
    }
  }

  String _getDisplayTitle() {
    if (widget.imageName != null && widget.imageName!.isNotEmpty) {
      return widget.imageName!;
    }
    return widget.title ?? 'Image';
  }

  Widget _buildImageContent(bool isDark) {
    if (_highResBase64 != null) {
      return _buildBase64Image(_highResBase64!, isDark);
    }

    if (widget.base64Image != null &&
        widget.base64Image!.isNotEmpty &&
        widget.base64Image != 'false') {
      final base64ImgWidget = _buildBase64Image(widget.base64Image!, isDark);

      return base64ImgWidget;
    }

    if (widget.imageBytes != null && widget.imageBytes!.isNotEmpty) {
      Widget imageWidget;
      if (_looksLikeImage(widget.imageBytes!)) {
        imageWidget = Image.memory(
          widget.imageBytes!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildErrorIcon(isDark),
        );
      } else {
        try {
          final text = String.fromCharCodes(widget.imageBytes!);
          if (text.trimLeft().startsWith('<svg')) {
            imageWidget = SvgPicture.string(text, fit: BoxFit.contain);
          } else {
            imageWidget = _buildErrorIcon(isDark);
          }
        } catch (_) {
          imageWidget = _buildErrorIcon(isDark);
        }
      }

      return imageWidget;
    }

    if (_isLoadingHighRes) {
      return const SizedBox.shrink();
    }

    return _buildErrorIcon(isDark);
  }

  Widget _buildBase64Image(String base64String, bool isDark) {
    try {
      var raw = base64String.trim();

      final dataUrlSvgUtf8 = RegExp(
        r'^data:image\/svg\+xml;utf8,',
        caseSensitive: false,
      );
      if (dataUrlSvgUtf8.hasMatch(raw)) {
        final svgText = Uri.decodeFull(raw.replaceFirst(dataUrlSvgUtf8, ''));
        return SvgPicture.string(
          svgText,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _buildLoadingIndicator(isDark),
        );
      }

      if (raw.trimLeft().startsWith('<svg')) {
        return SvgPicture.string(
          raw,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _buildLoadingIndicator(isDark),
        );
      }

      final dataUrlBase64 = RegExp(r'^data:image\/[a-zA-Z0-9.+-]+;base64,');
      raw = raw.replaceFirst(dataUrlBase64, '');
      final cleanBase64 = raw.replaceAll(RegExp(r'\s+'), '');

      if (cleanBase64.isNotEmpty) {
        final Uint8List bytes = base64Decode(cleanBase64);
        if (_looksLikeImage(bytes)) {
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _buildErrorIcon(isDark),
          );
        } else {
          try {
            final text = String.fromCharCodes(bytes);
            if (text.trimLeft().startsWith('<svg')) {
              return SvgPicture.string(
                text,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _buildLoadingIndicator(isDark),
              );
            }
          } catch (_) {}
        }
      }
    } catch (e) {}
    return _buildErrorIcon(isDark);
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return Center(
      child: LoadingAnimationWidget.fourRotatingDots(
        color: isDark ? Colors.white : AppTheme.primaryColor,
        size: 40,
      ),
    );
  }

  Widget _buildErrorIcon(bool isDark) {
    return Center(
      child: Icon(
        Icons.error,
        color: isDark ? Colors.red[300] : Colors.red,
        size: 48,
      ),
    );
  }

  bool _looksLikeImage(List<int> bytes) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = _getDisplayTitle();

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.title != null &&
                widget.imageName != null &&
                widget.title != widget.imageName)
              Text(
                widget.title!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        foregroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: SizedBox.expand(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 5.0,
                  boundaryMargin: EdgeInsets.zero,
                  constrained: true,
                  child: _buildImageContent(isDark),
                ),
              ),
            ),
            if (_isLoadingHighRes)
              Center(child: _buildLoadingIndicator(isDark)),
          ],
        ),
      ),
    );
  }
}
