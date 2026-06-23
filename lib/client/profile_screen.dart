import 'package:flutter/material.dart';
import '../models/reservation_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_manager.dart';
import '../services/reservation_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_routes.dart';
import '../utils/error_handler.dart';
import '../widgets/client_navbar.dart';
import '../widgets/notification_overlay.dart';
import '../widgets/required_label.dart';
import '../widgets/reservation_countdown.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _expiryNotified  = false;
  bool _autoExpired     = false;
  bool _notifEnabled    = true;

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
  }

  Future<void> _loadNotifPref() async {
    final v = await NotificationManager.isEnabled();
    if (mounted) setState(() => _notifEnabled = v);
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUid ?? '';
    return NotificationWrapper(
      userId: uid,
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<UserModel?>(
        stream: AuthService.watchCurrentUser(),
        builder: (context, snap) {
          final user = snap.data;
          return CustomScrollView(
            slivers: [
              // ─── Gradient Header ──────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: NotificationBell(userId: uid),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.mainGradient,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -50,
                          right: -50,
                          child: _circle(200, Colors.white, 0.08),
                        ),
                        Positioned(
                          bottom: -40,
                          left: -40,
                          child: _circle(140, Colors.white, 0.06),
                        ),
                        SafeArea(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 16),
                                // Avatar
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      user != null && user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  user?.name.isNotEmpty == true
                                      ? user!.name
                                      : 'Utilisateur',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    user?.role.name.toUpperCase() ?? 'CLIENT',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Info + Actions ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Info card
                      _infoCard(user),

                      const SizedBox(height: 16),

                      // Reservations section
                      _reservationsSection(),

                      // Menu items
                      _menuItem(
                        icon: Icons.edit_outlined,
                        label: 'Modifier le profil',
                        onTap: () => _showEditDialog(context, user),
                      ),
                      _menuItem(
                        icon: Icons.favorite_border_rounded,
                        label: 'Mes favoris',
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, AppRoutes.favorites),
                      ),
                      _menuItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Mes conversations',
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, AppRoutes.conversations),
                      ),
                      _notifSettingsCard(),
                      const SizedBox(height: 24),

                      // Sign out
                      GradientButton(
                        label: 'Se déconnecter',
                        onTap: () async {
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                                context, AppRoutes.login, (_) => false);
                          }
                        },
                        icon: Icons.logout_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const ClientNavbar(currentIndex: 4),
    )); // NotificationWrapper
  }

  Widget _reservationsSection() {
    final uid = AuthService.currentUid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<ReservationModel>>(
      stream: ReservationService.watchUserReservations(uid),
      builder: (context, snap) {
        final all    = snap.data ?? [];
        final active = all.where((r) => r.isActive).toList();

        // Mark overdue docs in Firestore once per session
        if (!_autoExpired && snap.data != null) {
          _autoExpired = true;
          ReservationService.autoExpireForUser(uid);
        }

        if (active.isEmpty) return const SizedBox.shrink();

        // Notify about reservations expiring within 2 hours (once per session)
        if (!_expiryNotified) {
          for (final r in active) {
            final hoursLeft = r.expiresAt.difference(DateTime.now()).inHours;
            if (hoursLeft < 2) {
              _expiryNotified = true;
              NotificationManager.reservationExpiringSoon(
                  promoTitle: r.promoTitle);
              break;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes réservations',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...active.map((r) => ReservationCountdownCard(
              key: ValueKey(r.id),
              reservation: r,
              onExpire: () => ReservationService.expire(r.id),
            )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }


  Widget _infoCard(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.mail_outline_rounded,
            'Email',
            user?.email ?? AuthService.currentUser?.email ?? '—',
          ),
          const Divider(height: 20, color: AppColors.border),
          _infoRow(
            Icons.phone_outlined,
            'Téléphone',
            user?.phone?.isNotEmpty == true ? user!.phone! : 'Non renseigné',
          ),
          const Divider(height: 20, color: AppColors.border),
          _infoRow(
            Icons.shield_outlined,
            'Statut',
            user?.status.name.toUpperCase() ?? '—',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuItem(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _notifSettingsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
                Switch.adaptive(
                  value: _notifEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) async {
                    setState(() => _notifEnabled = v);
                    await NotificationManager.setEnabled(v);
                    if (v) await NotificationManager.requestPermission();
                  },
                ),
              ],
            ),
          ),
          if (_notifEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await NotificationManager.showTestNotification();
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Notification de test envoyée dans 5 secondes'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded,
                          color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Tester les notifications',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, UserModel? user) {
    final nameCtrl  = TextEditingController(text: user?.name ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    int tab = 0; // 0=name, 1=phone

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Modifier le profil',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),

                // Tabs
                Row(
                  children: [
                    _editTab('Nom', 0, tab, () => setLocal(() => tab = 0)),
                    const SizedBox(width: 8),
                    _editTab('Téléphone', 1, tab, () => setLocal(() => tab = 1)),
                  ],
                ),
                const SizedBox(height: 16),

                // Field
                RequiredLabel(tab == 0 ? 'Nom' : 'Téléphone'),
                _editField(
                  tab == 0 ? nameCtrl : phoneCtrl,
                  tab == 0 ? 'Votre nom' : '+213...',
                  tab == 0
                      ? TextInputType.name
                      : TextInputType.phone,
                ),
                const SizedBox(height: 20),

                GradientButton(
                  label: 'Enregistrer',
                  icon: Icons.check_rounded,
                  onTap: () async {
                    final uid = AuthService.currentUid;
                    if (uid == null) return;
                    try {
                      if (tab == 0 && nameCtrl.text.trim().isNotEmpty) {
                        await AuthService.updateUserName(
                            uid, nameCtrl.text.trim());
                      } else if (tab == 1 &&
                          phoneCtrl.text.trim().isNotEmpty) {
                        await AuthService.updateUserPhone(
                            uid, phoneCtrl.text.trim());
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        AppErrorHandler.showError(
                            ctx, e, logContext: 'EditProfile');
                      }
                    }
                  },
                ),
              ],
              ), // Column
            ), // SingleChildScrollView
          ),
        ),
      ),
    );
  }

  Widget _editTab(
      String label, int index, int current, VoidCallback onTap) {
    final active = index == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppColors.primaryGradient : null,
          color: active ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _editField(
      TextEditingController ctrl, String hint, TextInputType type) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: AppColors.textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: alpha),
        ),
      );
}

