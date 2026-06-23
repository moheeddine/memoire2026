import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _roleFilter = 'tous';
  String _search     = '';

  Stream<List<UserModel>> get _stream => _roleFilter == 'tous'
      ? AuthService.watchAllUsers()
      : AuthService.watchUsersByRole(_roleFilter);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── Filters ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              // Search
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _search = v.toLowerCase()),
                  style: const TextStyle(
                      color: AppColors.textDark, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un utilisateur...',
                    hintStyle:
                        TextStyle(color: AppColors.textLight),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 20),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Role chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      ['tous', 'client', 'entreprise', 'admin']
                          .map((r) {
                    final active = _roleFilter == r;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _roleFilter = r),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        margin:
                            const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: active
                              ? AppColors.primaryGradient
                              : null,
                          color: active
                              ? null
                              : Colors.white,
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? Colors.transparent
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          r.toUpperCase(),
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
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ─── List ─────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _stream,
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
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_outline_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucun utilisateur trouvé',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Aucun compte ne correspond\naux critères sélectionnés.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              var users = snap.data!;
              if (_search.isNotEmpty) {
                users = users
                    .where((u) =>
                        u.name.toLowerCase().contains(_search) ||
                        u.email.toLowerCase().contains(_search))
                    .toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: users.length,
                itemBuilder: (context, i) =>
                    _UserCard(user: users[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  const _UserCard({required this.user});

  Color _roleColor() {
    switch (user.role) {
      case UserRole.admin:      return AppColors.pink;
      case UserRole.entreprise: return AppColors.blue;
      default:                  return AppColors.purple;
    }
  }

  Color _statusColor() {
    switch (user.status) {
      case UserStatus.active:    return AppColors.success;
      case UserStatus.pending:   return AppColors.warning;
      case UserStatus.rejected:  return AppColors.error;
      case UserStatus.suspended: return AppColors.error;
      default:                   return AppColors.textLight;
    }
  }

  Future<void> _toggleStatus(BuildContext context) async {
    final newStatus =
        user.status == UserStatus.active ? 'suspended' : 'active';
    try {
      await AuthService.updateUserStatus(user.uid, newStatus);
    } catch (e) {
      AppErrorHandler.log('User.toggleStatus', e);
      if (context.mounted) AppErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rColor   = _roleColor();
    final sColor   = _statusColor();
    final isActive = user.status == UserStatus.active;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty
                    ? user.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: rColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isNotEmpty ? user.name : 'Inconnu',
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _chip(user.role.name.toUpperCase(), rColor),
                    const SizedBox(width: 6),
                    _chip(user.status.name.toUpperCase(), sColor),
                  ],
                ),
              ],
            ),
          ),

          if (user.role != UserRole.admin)
            GestureDetector(
              onTap: () => _toggleStatus(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_rounded,
                  color:
                      isActive ? AppColors.error : AppColors.success,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
