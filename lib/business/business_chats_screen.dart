import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../client/chat_screen.dart';
import 'business_navbar.dart';

class BusinessChatsScreen extends StatelessWidget {
  final String businessId;

  const BusinessChatsScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Messages clients',
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
      body: StreamBuilder<List<ChatModel>>(
        stream: ChatService.watchChatsForBusiness(businessId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snap.hasData || snap.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun message client',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Les messages des clients apparaîtront ici',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.length,
            itemBuilder: (context, i) {
              final chat = snap.data![i];
              return _ChatTile(chat: chat);
            },
          );
        },
      ),
      bottomNavigationBar: BusinessNavbar(
        currentIndex: 3,
        businessId: businessId,
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;

  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              businessId: chat.businessId,
              businessName: chat.businessName,
              existingChatId: chat.id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: chat.hasUnread
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
            width: chat.hasUnread ? 1.5 : 1,
          ),
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
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: chat.hasUnread
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  chat.clientId.isNotEmpty
                      ? chat.clientId[0].toUpperCase()
                      : 'C',
                  style: TextStyle(
                    color: chat.hasUnread
                        ? AppColors.primary
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client ${chat.clientId.substring(0, 6)}...',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: chat.hasUnread
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chat.lastMessage.isNotEmpty
                        ? chat.lastMessage
                        : 'Aucun message',
                    style: TextStyle(
                      color: chat.hasUnread
                          ? AppColors.textBody
                          : AppColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (chat.lastMessageAt != null)
                  Text(
                    DateFormat('HH:mm').format(chat.lastMessageAt!),
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 10),
                  ),
                if (chat.hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
