import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../services/promo_service.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _processing = false;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _done) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    final uid = AuthService.currentUid;
    if (uid == null) {
      _showResult(
        success: false,
        title: 'Non connecté',
        message: 'Vous devez être connecté pour utiliser un QR code.',
      );
      return;
    }

    final result = await PromoService.validateAndUseQr(uid, barcode.rawValue!);

    if (!mounted) return;

    _showResult(
      success: result.isSuccess,
      title: result.isSuccess
          ? 'Promotion utilisée !'
          : _statusTitle(result.status),
      message: result.message,
      promoTitle: result.promo?.title,
      discount: result.promo?.discount,
    );
  }

  String _statusTitle(QrScanStatus status) {
    switch (status) {
      case QrScanStatus.expired:    return 'Promotion expirée';
      case QrScanStatus.alreadyUsed:return 'Déjà utilisé';
      case QrScanStatus.invalid:    return 'QR invalide';
      default:                      return 'Erreur';
    }
  }

  void _showResult({
    required bool success,
    required String title,
    required String message,
    String? promoTitle,
    int? discount,
  }) {
    setState(() => _done = true);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ResultSheet(
        success:    success,
        title:      title,
        message:    message,
        promoTitle: promoTitle,
        discount:   discount,
        onDone:     () => Navigator.pop(context),
        onRetry: success
            ? null
            : () {
                Navigator.pop(context); // close sheet
                setState(() {
                  _done       = false;
                  _processing = false;
                });
                _controller.start();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Camera feed ─────────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ─── Overlay ─────────────────────────────────────────────────────
          _ScanOverlay(),

          // ─── Top bar ─────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Scanner un QR code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // Torch toggle
                  GestureDetector(
                    onTap: () => _controller.toggleTorch(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.flash_on,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Processing indicator ─────────────────────────────────────────
          if (_processing && !_done)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── SCAN OVERLAY ─────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const boxSize = 260.0;
    final offsetY = (size.height - boxSize) / 2 - 40;

    return Stack(
      children: [
        // Dark overlay
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Positioned(
                left: (size.width - boxSize) / 2,
                top:  offsetY,
                child: Container(
                  width: boxSize,
                  height: boxSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Corner brackets
        Positioned(
          left:  (size.width - boxSize) / 2,
          top:   offsetY,
          child: _corners(boxSize),
        ),

        // Hint text
        Positioned(
          bottom: size.height * 0.25,
          left: 0,
          right: 0,
          child: const Center(
            child: Text(
              'Placez le QR code dans le cadre',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _corners(double size) {
    const len = 28.0;
    const thick = 3.0;
    const color = AppColors.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // top-left
          Positioned(top: 0, left: 0,
            child: _corner(len, thick, color, top: true, left: true)),
          // top-right
          Positioned(top: 0, right: 0,
            child: _corner(len, thick, color, top: true, left: false)),
          // bottom-left
          Positioned(bottom: 0, left: 0,
            child: _corner(len, thick, color, top: false, left: true)),
          // bottom-right
          Positioned(bottom: 0, right: 0,
            child: _corner(len, thick, color, top: false, left: false)),
        ],
      ),
    );
  }

  Widget _corner(double len, double thick, Color color,
      {required bool top, required bool left}) {
    return SizedBox(
      width: len,
      height: len,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          thick: thick,
          top: top,
          left: left,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thick;
  final bool top;
  final bool left;

  _CornerPainter(
      {required this.color,
      required this.thick,
      required this.top,
      required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── RESULT BOTTOM SHEET ──────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  final bool success;
  final String title;
  final String message;
  final String? promoTitle;
  final int? discount;
  final VoidCallback onDone;
  final VoidCallback? onRetry;

  const _ResultSheet({
    required this.success,
    required this.title,
    required this.message,
    required this.onDone,
    this.promoTitle,
    this.discount,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: success
                  ? AppColors.primaryGradient
                  : const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFFF6B6B)]),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          // Message
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          // Promo info
          if (success && promoTitle != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '-$discount%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      promoTitle!,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Actions
          if (onRetry != null) ...[
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Réessayer',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
          ],

          GradientButton(
            label: 'Fermer',
            onTap: onDone,
            icon: Icons.check,
          ),
        ],
      ),
    );
  }
}
