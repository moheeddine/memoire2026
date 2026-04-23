import 'package:flutter/material.dart';
import '../models/payment_model.dart';
import '../models/promo_model.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../services/promo_service.dart';
import '../theme/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  final PromoModel promo;

  const PaymentScreen({super.key, required this.promo});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;
  PaymentModel? _result;

  double get _amount => (widget.promo.discount * 0.5).clamp(1.0, 50.0);

  Future<void> _pay() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;

    setState(() => _processing = true);

    final payment = await PaymentService.processPayment(
      userId: uid,
      promoId: widget.promo.id,
      promoTitle: widget.promo.title,
      amount: _amount,
    );

    if (payment.status == PaymentStatus.success) {
      await PromoService.incrementUsed(widget.promo.id);
    }

    if (mounted) {
      setState(() {
        _result = payment;
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textDark, size: 16),
          ),
        ),
        title: const Text(
          'Paiement',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _result != null
            ? _ResultView(payment: _result!)
            : _PaymentForm(
                promo: widget.promo,
                amount: _amount,
                processing: _processing,
                onPay: _pay,
              ),
      ),
    );
  }
}

// ─── PAYMENT FORM ─────────────────────────────────────────────────────────────

class _PaymentForm extends StatelessWidget {
  final PromoModel promo;
  final double amount;
  final bool processing;
  final VoidCallback onPay;

  const _PaymentForm({
    required this.promo,
    required this.amount,
    required this.processing,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Récapitulatif',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _row('Promo', promo.title),
              _row('Réduction', '-${promo.discount}%'),
              _row('Code', promo.code),
              const Divider(color: AppColors.border, height: 24),
              _row(
                'Total',
                '${amount.toStringAsFixed(2)} DT',
                bold: true,
                valueColor: AppColors.primary,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card form (simulated)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.credit_card_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Carte bancaire (simulée)',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _fakeField('**** **** **** 4242'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _fakeField('12/26')),
                  const SizedBox(width: 10),
                  Expanded(child: _fakeField('***')),
                ],
              ),
            ],
          ),
        ),

        const Spacer(),

        GradientButton(
          label: processing
              ? 'Traitement...'
              : 'Payer ${amount.toStringAsFixed(2)} DT',
          icon: Icons.lock_rounded,
          loading: processing,
          onTap: processing ? null : onPay,
        ),

        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Paiement simulé — aucune transaction réelle',
            style: TextStyle(color: AppColors.textLight, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textDark,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fakeField(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        hint,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
    );
  }
}

// ─── RESULT VIEW ──────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final PaymentModel payment;

  const _ResultView({required this.payment});

  @override
  Widget build(BuildContext context) {
    final success = payment.status == PaymentStatus.success;
    final color   = success ? AppColors.success : AppColors.error;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            success ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 52,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          success ? 'Paiement réussi !' : 'Paiement échoué',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          success
              ? 'Votre code promo est activé. Bonne économie !'
              : 'Une erreur est survenue. Veuillez réessayer.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 40),
        GradientButton(
          label: 'Retour',
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
          gradient: success
              ? const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)])
              : null,
        ),
      ],
    );
  }
}
