import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:math';

Future<void> showInvoiceSentConfettiDialog(
  BuildContext context,
  String invoiceName, {
  String documentType = 'Invoice',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => UniversalConfettiDialog(
      title: '$documentType Sent Successfully',
      itemName: invoiceName,
      message:
          'Your ${documentType.toLowerCase()} has been successfully delivered to the recipient\'s email address.',
      buttonText: 'Perfect!',
      logName: 'InvoiceDialog',
    ),
  );
}

Future<void> showCustomerCreatedConfettiDialog(
  BuildContext context,
  String customerName,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => UniversalConfettiDialog(
      title: 'Customer Created Successfully',
      itemName: customerName,
      message: 'The customer has been successfully added to the database.',
      buttonText: 'Perfect!',
      logName: 'CustomerDialog',
    ),
  );
}

Future<void> showInvoiceCreatedConfettiDialog(
  BuildContext context,
  String invoiceName, {
  String documentType = 'Invoice',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => UniversalConfettiDialog(
      title: 'Draft $documentType Created',
      itemName: invoiceName,
      message:
          'Your draft ${documentType.toLowerCase()} has been created. You can review and confirm it in Odoo before sending to your customer.',
      buttonText: 'Perfect!',
      logName: 'InvoiceCreatedDialog',
    ),
  );
}

Future<void> showPaymentCreatedConfettiDialog(
  BuildContext context,
  String paymentName,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => UniversalConfettiDialog(
      title: 'Payment Registered Successfully',
      itemName: paymentName,
      message: 'The payment has been successfully registered and posted.',
      buttonText: 'Perfect!',
      logName: 'PaymentCreatedDialog',
    ),
  );
}

class UniversalConfettiDialog extends StatefulWidget {
  final String title;
  final String itemName;
  final String message;
  final String buttonText;
  final String logName;

  const UniversalConfettiDialog({
    super.key,
    required this.title,
    required this.itemName,
    required this.message,
    required this.buttonText,
    required this.logName,
  });

  @override
  State<UniversalConfettiDialog> createState() =>
      _UniversalConfettiDialogState();
}

class _UniversalConfettiDialogState extends State<UniversalConfettiDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          try {
            _confettiController.play();
          } catch (e) {}
        }
      });
    });
  }

  @override
  void dispose() {
    _confettiController.stop();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 40.0,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 340.0, minHeight: 300.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.0),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        isDark
                            ? Colors.white.withOpacity(0.02)
                            : colorScheme.primary.withOpacity(0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: ConfettiWidget(
                            confettiController: _confettiController,
                            blastDirection: pi / 2,
                            blastDirectionality:
                                BlastDirectionality.directional,
                            shouldLoop: false,
                            numberOfParticles: 10,
                            maxBlastForce: 10,
                            minBlastForce: 5,
                            emissionFrequency: 0.05,
                            gravity: 0.12,
                            particleDrag: 0.03,
                            colors: isDark
                                ? [
                                    Colors.white.withOpacity(0.9),
                                    const Color(0xFFE5E5E7),
                                    const Color(0xFFD1D1D6),
                                    Colors.grey.shade200,
                                  ]
                                : [
                                    colorScheme.primary.withOpacity(0.8),
                                    colorScheme.secondary.withOpacity(0.7),
                                    const Color(0xFFFFD700),
                                    const Color(0xFF00C896),
                                    colorScheme.tertiary.withOpacity(0.6),
                                  ],
                            createParticlePath: (size) {
                              final path = Path();
                              if (Random().nextBool()) {
                                path.addRRect(
                                  RRect.fromRectAndRadius(
                                    Rect.fromLTWH(
                                      0,
                                      0,
                                      size.width * 0.6,
                                      size.height * 0.8,
                                    ),
                                    const Radius.circular(1),
                                  ),
                                );
                              } else {
                                path.moveTo(size.width / 2, 0);
                                path.lineTo(size.width, size.height / 2);
                                path.lineTo(size.width / 2, size.height);
                                path.lineTo(0, size.height / 2);
                                path.close();
                              }
                              return path;
                            },
                          ),
                        ),
                        Positioned(
                          top: 20,
                          left: 0,
                          right: 0,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConfettiWidget(
                              confettiController: _confettiController,
                              blastDirection: pi / 2,
                              blastDirectionality:
                                  BlastDirectionality.directional,
                              shouldLoop: false,
                              numberOfParticles: 5,
                              maxBlastForce: 6,
                              minBlastForce: 3,
                              emissionFrequency: 0.03,
                              gravity: 0.1,
                              particleDrag: 0.04,
                              colors: isDark
                                  ? [
                                      Colors.white.withOpacity(0.4),
                                      Colors.grey.shade300.withOpacity(0.5),
                                    ]
                                  : [
                                      colorScheme.primary.withOpacity(0.3),
                                      colorScheme.secondary.withOpacity(0.4),
                                      const Color(0xFFFFD700).withOpacity(0.5),
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : colorScheme.onSurface,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800.withOpacity(0.6)
                            : colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : colorScheme.primary.withOpacity(0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        widget.itemName,
                        style: textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white : colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      widget.message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Colors.grey.shade400
                            : colorScheme.onSurface.withOpacity(0.65),
                        height: 1.4,
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28.0),
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ).copyWith(
                              overlayColor: MaterialStateProperty.all(
                                colorScheme.onPrimary.withOpacity(0.08),
                              ),
                            ),
                        onPressed: () {
                          _confettiController.stop();
                          Navigator.of(context).pop();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                              size: 18.0,
                              color: isDark
                                  ? Colors.white
                                  : colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              widget.buttonText,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15.0,
                                letterSpacing: 0.2,
                                color: isDark
                                    ? Colors.white
                                    : colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
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
}
