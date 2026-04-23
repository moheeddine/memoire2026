import 'package:flutter/material.dart';
import '../models/promo_model.dart';
import '../services/promo_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class ManagePromosScreen extends StatefulWidget {
  const ManagePromosScreen({super.key});

  @override
  State<ManagePromosScreen> createState() => _ManagePromosScreenState();
}

class _ManagePromosScreenState extends State<ManagePromosScreen> {
  String _statusFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── Filter chips ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['pending', 'approved', 'rejected'].map((s) {
                final active = _statusFilter == s;
                Color chipColor;
                switch (s) {
                  case 'approved':
                    chipColor = AppColors.success;
                    break;
                  case 'rejected':
                    chipColor = AppColors.error;
                    break;
                  default:
                    chipColor = AppColors.warning;
                }
                return GestureDetector(
                  onTap: () =>
                      setState(() => _statusFilter = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? chipColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? chipColor
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      s.toUpperCase(),
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ─── List ─────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<PromoModel>>(
            stream: PromoService.watchByStatus(_statusFilter),
            builder: (context, snap) {
              if (snap.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary),
                );
              }

              if (!snap.hasData || snap.data!.isEmpty) {
                return Center(
                  child: Text(
                    'Aucune promo "$_statusFilter".',
                    style: const TextStyle(
                        color: AppColors.textMuted),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: snap.data!.length,
                itemBuilder: (context, i) =>
                    _AdminPromoTile(promo: snap.data![i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminPromoTile extends StatelessWidget {
  final PromoModel promo;
  const _AdminPromoTile({required this.promo});

  Future<void> _approve(BuildContext context) async {
    try {
      await PromoService.approve(promo.id);
      await NotificationService.notifyPromoApproved(
          promo.businessId, promo.title);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promo approuvée !'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    try {
      await PromoService.reject(promo.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "${promo.title}" définitivement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PromoService.delete(promo.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = promo.status == PromoStatus.approved;
    final isRejected = promo.status == PromoStatus.rejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  promo.title,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '-${promo.discount}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            promo.businessName ?? promo.businessId,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!isApproved) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approve(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Approuver',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (!isRejected) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Rejeter',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => _delete(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
