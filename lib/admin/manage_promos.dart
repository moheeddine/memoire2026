import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/promo_model.dart';
import '../services/promo_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';

class ManagePromosScreen extends StatefulWidget {
  const ManagePromosScreen({super.key});

  @override
  State<ManagePromosScreen> createState() => _ManagePromosScreenState();
}

class _ManagePromosScreenState extends State<ManagePromosScreen> {
  String _statusFilter = 'pending';

  static const _filters = ['pending', 'approved', 'rejected'];
  static const _filterLabels = {
    'pending':  'En attente',
    'approved': 'Approuvées',
    'rejected': 'Rejetées',
  };
  static const _filterColors = {
    'pending':  AppColors.warning,
    'approved': AppColors.success,
    'rejected': AppColors.error,
  };
  static const _filterIcons = {
    'pending':  Icons.hourglass_top_rounded,
    'approved': Icons.check_circle_rounded,
    'rejected': Icons.cancel_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter chips ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final active = _statusFilter == f;
                final color  = _filterColors[f]!;
                return GestureDetector(
                  onTap: () => setState(() => _statusFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? color : AppColors.border),
                      boxShadow: active
                          ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_filterIcons[f]!, color: active ? Colors.white : color, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          _filterLabels[f]!,
                          style: TextStyle(
                            color: active ? Colors.white : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Promo list ────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<PromoModel>>(
            stream: PromoService.watchByStatus(_statusFilter),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary));
              }

              final all = snap.data ?? [];
              final promos = _statusFilter == 'approved'
                  ? all.where((p) => !p.isExpired && p.isActive).toList()
                  : all;

              if (promos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _filterColors[_statusFilter]!.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _filterIcons[_statusFilter]!,
                            color: _filterColors[_statusFilter]!,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune promo « ${_filterLabels[_statusFilter]} »',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: promos.length,
                itemBuilder: (context, i) => _PromoCard(promo: promos[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── PROMO CARD ───────────────────────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  final PromoModel promo;
  const _PromoCard({required this.promo});

  Color get _statusColor {
    switch (promo.status) {
      case PromoStatus.approved: return AppColors.success;
      case PromoStatus.rejected: return AppColors.error;
      default:                   return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (promo.status) {
      case PromoStatus.approved: return 'Approuvée';
      case PromoStatus.rejected: return 'Rejetée';
      default:                   return 'En attente';
    }
  }

  Future<void> _setStatus(BuildContext context, PromoStatus status) async {
    try {
      await PromoService.updateStatus(promo.id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(
              status == PromoStatus.approved
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(status == PromoStatus.approved ? 'Promotion approuvée' : 'Promotion rejetée'),
          ]),
          backgroundColor: status == PromoStatus.approved ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      AppErrorHandler.log('ManagePromos.setStatus', e);
      if (context.mounted) AppErrorHandler.showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette promotion ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          '« ${promo.title} » sera supprimée définitivement.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await PromoService.delete(promo.id);
    } catch (e) {
      AppErrorHandler.log('ManagePromos.delete', e);
      if (context.mounted) AppErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = promo.imageUrls.isNotEmpty;
    final sColor   = _statusColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: sColor.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Promo image ────────────────────────────────────────────────────
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: Image.network(
                promo.imageUrls.first,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  decoration: const BoxDecoration(gradient: AppColors.softGradient),
                  child: const Center(
                    child: Icon(Icons.image_not_supported_rounded,
                        color: AppColors.textLight, size: 32),
                  ),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: const BoxDecoration(gradient: AppColors.softGradient),
                child: const Center(
                  child: Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 32),
                ),
              ),
            ),

          // ── Card body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + discount badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        promo.title,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '-${promo.discount}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                // Business name
                if ((promo.businessName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.store_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        promo.businessName!,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],

                const SizedBox(height: 10),

                // Status badge + flash badge + date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_statusLabel,
                          style: TextStyle(color: sColor, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    if (promo.isFlashDeal) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, color: AppColors.orange, size: 11),
                            SizedBox(width: 2),
                            Text('Flash', style: TextStyle(color: AppColors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (promo.createdAt != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yy').format(promo.createdAt!),
                            style: const TextStyle(color: AppColors.textLight, fontSize: 11),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    if (promo.status != PromoStatus.approved) ...[
                      Expanded(
                        child: _ActionBtn(
                          label: 'Approuver',
                          icon: Icons.check_rounded,
                          color: AppColors.success,
                          onTap: () => _setStatus(context, PromoStatus.approved),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (promo.status != PromoStatus.rejected) ...[
                      Expanded(
                        child: _ActionBtn(
                          label: 'Rejeter',
                          icon: Icons.close_rounded,
                          color: AppColors.warning,
                          outline: true,
                          onTap: () => _setStatus(context, PromoStatus.rejected),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () => _delete(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ACTION BUTTON ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String      label;
  final IconData    icon;
  final Color       color;
  final VoidCallback onTap;
  final bool        outline;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(10),
          border: outline ? Border.all(color: color.withValues(alpha: 0.6)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: outline ? color : Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: outline ? color : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
