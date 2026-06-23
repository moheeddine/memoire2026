import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/promo_model.dart';
import '../theme/app_theme.dart';

// ─── QR PRINT HELPER ─────────────────────────────────────────────────────────
//
// Generates a publication-quality PDF with the QR code + promo info and
// hands it to the OS print dialog.  Rendering is done in two steps:
//   1. QrPainter → PNG bytes  (so the PDF lib gets a real raster image)
//   2. pw.Document → PDF bytes → Printing.layoutPdf
//
// QrPrintHelper is stateless; pass the BuildContext only for the error snackbar.

class QrPrintHelper {
  // Returns the QR code as a raw PNG Uint8List at 512 × 512 px.
  static Future<Uint8List> _qrPngBytes(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF1A1A2E),
      ),
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF7C3AED),
      ),
    );
    final byteData =
        await painter.toImageData(512, format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<void> print(BuildContext context, PromoModel promo) async {
    try {
      final qrBytes = await _qrPngBytes(promo.qrCodeValue!);

      await Printing.layoutPdf(
        name: promo.title,
        onLayout: (_) async {
          const purple   = PdfColor(0.486, 0.227, 0.929);
          const textDark = PdfColor(0.102, 0.102, 0.180);
          const textGrey = PdfColor(0.420, 0.447, 0.502);
          const bgLight  = PdfColor(0.941, 0.933, 1.0);
          const border   = PdfColor(0.898, 0.902, 0.910);

          final doc    = pw.Document();
          final qrImg  = pw.MemoryImage(qrBytes);

          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(48),
              build: (ctx) => pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // ─── Header bar ─────────────────────────────────────
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: const pw.BoxDecoration(
                      color: purple,
                      borderRadius:
                          pw.BorderRadius.all(pw.Radius.circular(14)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'PromoCity',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.all(
                                pw.Radius.circular(20)),
                          ),
                          child: pw.Text(
                            '-${promo.discount}%',
                            style: pw.TextStyle(
                              color: purple,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 32),

                  // ─── Business name ───────────────────────────────────
                  if (promo.businessName != null) ...[
                    pw.Text(
                      promo.businessName!,
                      style: const pw.TextStyle(
                          color: textGrey, fontSize: 13),
                    ),
                    pw.SizedBox(height: 8),
                  ],

                  // ─── Promo title ─────────────────────────────────────
                  pw.Text(
                    promo.title,
                    style: pw.TextStyle(
                      color: textDark,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),

                  if (promo.description.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      promo.description.length > 120
                          ? '${promo.description.substring(0, 120)}…'
                          : promo.description,
                      style: const pw.TextStyle(
                          color: textGrey, fontSize: 12),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                  pw.SizedBox(height: 28),

                  // ─── QR code ─────────────────────────────────────────
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: border),
                      borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(16)),
                    ),
                    child: pw.Image(qrImg, width: 200, height: 200),
                  ),
                  pw.SizedBox(height: 16),

                  // ─── Promo code badge ────────────────────────────────
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: const pw.BoxDecoration(
                      color: bgLight,
                      borderRadius: pw.BorderRadius.all(
                          pw.Radius.circular(20)),
                    ),
                    child: pw.Text(
                      'Code : ${promo.code}',
                      style: pw.TextStyle(
                        color: purple,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  pw.Text(
                    'Scannez ce QR code avec l\'application PromoCity',
                    style: const pw.TextStyle(
                        color: textGrey, fontSize: 11),
                  ),
                ],
              ),
            ),
          );

          return doc.save();
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur impression : $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  static void share(PromoModel promo) {
    final sb = StringBuffer()
      ..writeln('🏷️ ${promo.title}')
      ..writeln('💸 ${promo.discount}% de réduction');
    if (promo.businessName != null) sb.writeln('🏪 ${promo.businessName}');
    if (promo.description.isNotEmpty) {
      sb
        ..writeln()
        ..writeln(promo.description);
    }
    sb
      ..writeln()
      ..writeln('🔑 Code : ${promo.code}')
      ..writeln()
      ..writeln('Scannez le QR code sur PromoCity pour profiter de l\'offre !');
    Share.share(sb.toString(), subject: promo.title);
  }
}

// ─── QR CARD WIDGET ──────────────────────────────────────────────────────────
//
// Reusable premium card that renders:
//   • gradient header with business name + title + discount badge
//   • styled QR code
//   • description + promo code badge
//   • optional Print / Share action buttons (showActions = false for clients)
//
// Drop it inside any scrollable area or a DraggableScrollableSheet.

class QrCardWidget extends StatefulWidget {
  final PromoModel promo;
  final bool showActions;

  const QrCardWidget({
    super.key,
    required this.promo,
    this.showActions = true,
  });

  @override
  State<QrCardWidget> createState() => _QrCardWidgetState();
}

class _QrCardWidgetState extends State<QrCardWidget> {
  bool _printing = false;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    await QrPrintHelper.print(context, widget.promo);
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    final promo = widget.promo;
    if (promo.qrCodeValue == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.13),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.only(
                topLeft:  Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (promo.businessName != null)
                        Text(
                          promo.businessName!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        promo.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.5),
                  ),
                  child: Text(
                    '-${promo.discount}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── QR code ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: QrImageView(
                data: promo.qrCodeValue!,
                version: QrVersions.auto,
                size: 200,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.purple,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),

          // ── Promo details ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                if (promo.description.isNotEmpty)
                  Text(
                    promo.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                const SizedBox(height: 14),

                // Promo code badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_offer_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 7),
                      Text(
                        'Code : ${promo.code}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scannez ce QR code avec l\'application PromoCity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────
          if (widget.showActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: _actionBtn(
                      icon: Icons.print_rounded,
                      label: 'Imprimer',
                      gradient: AppColors.primaryGradient,
                      loading: _printing,
                      onTap: _handlePrint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionBtn(
                      icon: Icons.share_rounded,
                      label: 'Partager',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                      ),
                      onTap: () => QrPrintHelper.share(promo),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: loading ? null : gradient,
          color: loading ? AppColors.surface : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color:
                        gradient.colors.first.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              )
            else
              Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: loading ? AppColors.textMuted : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
