import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../services/business_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';

class ManageCompaniesScreen extends StatefulWidget {
  const ManageCompaniesScreen({super.key});

  @override
  State<ManageCompaniesScreen> createState() => _ManageCompaniesScreenState();
}

class _ManageCompaniesScreenState extends State<ManageCompaniesScreen> {
  String _filter = 'tous';
  String _search = '';

  static const _filters      = ['tous', 'pending', 'active', 'rejected'];
  static const _filterLabels = {
    'tous':     'Toutes',
    'pending':  'En attente',
    'active':   'Approuvées',
    'rejected': 'Rejetées',
  };
  static const _filterColors = {
    'tous':     AppColors.primary,
    'pending':  AppColors.warning,
    'active':   AppColors.success,
    'rejected': AppColors.error,
  };

  Stream<List<BusinessModel>> get _stream {
    if (_filter == 'tous') return BusinessService.watchAll();
    return BusinessService.watchByStatus(_filter);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            // ── Search bar ─────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Rechercher une entreprise…',
                  hintStyle: TextStyle(color: AppColors.textLight),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.primary, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Filter chips ───────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final active = _filter == f;
                  final color  = _filterColors[f]!;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? color : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active ? color : AppColors.border),
                        boxShadow: active
                            ? [BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )]
                            : [],
                      ),
                      child: Text(
                        _filterLabels[f]!,
                        style: TextStyle(
                          color: active ? Colors.white : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: StreamBuilder<List<BusinessModel>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary));
              }

              var businesses = snap.data ?? [];
              if (_search.isNotEmpty) {
                businesses = businesses
                    .where((b) =>
                        b.name.toLowerCase().contains(_search) ||
                        b.email.toLowerCase().contains(_search) ||
                        b.category.toLowerCase().contains(_search))
                    .toList();
              }

              if (businesses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.store_rounded,
                              color: AppColors.primary, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'tous'
                              ? 'Aucune entreprise'
                              : 'Aucune entreprise ${_filterLabels[_filter]}',
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
                itemCount: businesses.length,
                itemBuilder: (context, i) =>
                    _CompanyCard(business: businesses[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── COMPANY CARD ─────────────────────────────────────────────────────────────

class _CompanyCard extends StatelessWidget {
  final BusinessModel business;
  const _CompanyCard({required this.business});

  Color get _statusColor {
    switch (business.status) {
      case BusinessStatus.active:   return AppColors.success;
      case BusinessStatus.rejected: return AppColors.error;
      case BusinessStatus.pending:  return AppColors.warning;
      default:                      return AppColors.textLight;
    }
  }

  String get _statusLabel {
    switch (business.status) {
      case BusinessStatus.active:   return 'Approuvé';
      case BusinessStatus.rejected: return 'Rejeté';
      case BusinessStatus.pending:  return 'En attente';
      default:                      return 'Inconnu';
    }
  }

  Future<void> _approve(BuildContext context) async {
    try {
      await BusinessService.approve(business.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${business.name} approuvé !'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      AppErrorHandler.log('Companies.approve', e);
      if (context.mounted) AppErrorHandler.showError(context, e);
    }
  }

  Future<void> _reject(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter cette entreprise ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Rejeter « ${business.name} » ?',
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BusinessService.reject(business.uid);
    } catch (e) {
      AppErrorHandler.log('Companies.reject', e);
      if (context.mounted) AppErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sColor    = _statusColor;
    final isPending = business.status == BusinessStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: sColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(business.category,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(
                        color: sColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (business.email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.email_outlined,
                  size: 12, color: AppColors.textLight),
              const SizedBox(width: 4),
              Flexible(
                child: Text(business.email,
                    style:
                        const TextStyle(color: AppColors.textLight, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ],
          if (business.matricule.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.badge_outlined,
                  size: 12, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(business.matricule,
                  style:
                      const TextStyle(color: AppColors.textLight, fontSize: 12)),
            ]),
          ],
          if (business.ownerName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.person_outline_rounded,
                  size: 12, color: AppColors.textLight),
              const SizedBox(width: 4),
              Flexible(
                child: Text(business.ownerName,
                    style:
                        const TextStyle(color: AppColors.textLight, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(context),
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text('Approuver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(context),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
