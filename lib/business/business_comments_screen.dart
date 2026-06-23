import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/comment_model.dart';
import '../models/promo_model.dart';
import '../services/business_service.dart';
import '../services/comment_service.dart';
import '../theme/app_theme.dart';
import '../client/promo_detail_screen.dart';

// ─── ÉCRAN GESTION DES COMMENTAIRES (ENTREPRISE) ─────────────────────────────
// Accessible depuis le dashboard. Affiche tous les commentaires des promos
// de l'entreprise, avec actions répondre / modifier réponse / supprimer réponse.

class BusinessCommentsScreen extends StatefulWidget {
  final String businessId;

  const BusinessCommentsScreen({super.key, required this.businessId});

  @override
  State<BusinessCommentsScreen> createState() => _BusinessCommentsScreenState();
}

class _BusinessCommentsScreenState extends State<BusinessCommentsScreen> {
  StreamSubscription<List<CommentModel>>? _sub;
  List<CommentModel> _comments = [];
  bool _loaded = false;

  String _businessName = '';

  @override
  void initState() {
    super.initState();
    _sub = CommentService.watchByBusiness(widget.businessId).listen((list) {
      if (mounted) setState(() { _comments = list; _loaded = true; });
    });
    _loadBusinessName();
  }

  Future<void> _loadBusinessName() async {
    final biz = await BusinessService.getBusinessData(widget.businessId);
    if (mounted && biz != null) setState(() => _businessName = biz.name);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Commentaires clients',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        iconTheme: const IconThemeData(color: AppColors.textDark),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : _comments.isEmpty
              ? _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CommentManagerCard(
                    comment:      _comments[i],
                    businessId:   widget.businessId,
                    businessName: _businessName,
                  ),
                ),
    );
  }
}

// ─── CARD MANAGER ─────────────────────────────────────────────────────────────

class _CommentManagerCard extends StatefulWidget {
  final CommentModel comment;
  final String businessId;
  final String businessName;

  const _CommentManagerCard({
    required this.comment,
    required this.businessId,
    required this.businessName,
  });

  @override
  State<_CommentManagerCard> createState() => _CommentManagerCardState();
}

class _CommentManagerCardState extends State<_CommentManagerCard> {
  bool _showInput   = false;
  bool _editingReply = false;
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_editingReply) {
        await CommentService.updateReply(
            commentId: widget.comment.id, newText: text);
      } else {
        await CommentService.setReply(
          commentId:   widget.comment.id,
          clientId:    widget.comment.userId,
          companyId:   widget.businessId,
          companyName: widget.businessName,
          text:        text,
          promoId:     widget.comment.promoId,
          promoTitle:  widget.comment.comment.length > 30
              ? '${widget.comment.comment.substring(0, 30)}…'
              : widget.comment.comment,
        );
      }
      _ctrl.clear();
      if (mounted) {
        setState(() {
          _showInput    = false;
          _editingReply = false;
          _sending      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteReply() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la réponse ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await CommentService.removeReply(widget.comment.id);
    }
  }

  void _openPromo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PromoDetailScreen(
          promo: PromoModel(
            id:         widget.comment.promoId,
            title:      'Promotion',
            description: '',
            discount:   0,
            code:       '',
            conditions: '',
            businessId: widget.comment.businessId,
            status:     PromoStatus.approved,
          ),
          scrollToCommentId: widget.comment.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Promo tag ───────────────────────────────────────────────
          GestureDetector(
            onTap: _openPromo,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                gradient: AppColors.softGradient,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                const Icon(Icons.local_offer_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sur la promotion : ${c.promoId}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.open_in_new_rounded,
                    color: AppColors.primary, size: 13),
              ]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Client comment ─────────────────────────────────────
                Row(children: [
                  _InitialAvatar(name: c.userName, radius: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.userName,
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text(_relDate(c.createdAt),
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 10)),
                      ],
                    ),
                  ),
                  _Stars(rating: c.rating),
                ]),
                const SizedBox(height: 8),
                Text(c.comment,
                    style: const TextStyle(
                        color: AppColors.textBody,
                        fontSize: 13,
                        height: 1.5)),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // ── Reply section ──────────────────────────────────────
                if (c.hasReply && !_showInput)
                  _ReplyDisplay(
                    reply:     c.reply!,
                    onEdit: () {
                      _ctrl.text = c.reply!.text;
                      setState(() {
                        _editingReply = true;
                        _showInput    = true;
                      });
                    },
                    onDelete: _deleteReply,
                  )
                else if (!_showInput)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showInput = true),
                    icon: const Icon(Icons.reply_rounded, size: 16),
                    label: const Text('Répondre à ce commentaire'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero),
                  ),

                if (_showInput) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          autofocus: true,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(
                              color: AppColors.textDark, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: _editingReply
                                ? 'Modifier la réponse…'
                                : 'Votre réponse…',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SendBtn(
                          loading: _sending,
                          onTap: _sending ? null : _submit),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() {
                      _showInput    = false;
                      _editingReply = false;
                      _ctrl.clear();
                    }),
                    child: const Text('Annuler',
                        style: TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── REPLY DISPLAY ───────────────────────────────────────────────────────────

class _ReplyDisplay extends StatelessWidget {
  final CommentReply reply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReplyDisplay(
      {required this.reply, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.store_rounded,
                color: AppColors.primary, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(reply.companyName,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            Text(_relDate(reply.createdAt),
                style: const TextStyle(
                    color: AppColors.textLight, fontSize: 10)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit')   onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Modifier', style: TextStyle(fontSize: 13)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 15, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Supprimer',
                        style: TextStyle(color: AppColors.error, fontSize: 13)),
                  ]),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textLight, size: 18),
              padding: EdgeInsets.zero,
              iconSize: 18,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(reply.text,
              style: const TextStyle(
                  color: AppColors.textBody, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

// ─── MICRO WIDGETS ────────────────────────────────────────────────────────────

class _InitialAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const _InitialAvatar({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient, shape: BoxShape.circle),
      child: Center(
        child: Text(initials.isNotEmpty ? initials : '?',
            style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: filled ? AppColors.warning : AppColors.border,
          size: 13,
        );
      }),
    );
  }
}

class _SendBtn extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _SendBtn({required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.softGradient,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Aucun commentaire pour le moment',
              style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Les avis clients apparaîtront ici.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── DATE HELPER ─────────────────────────────────────────────────────────────

String _relDate(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return 'À l\'instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours   < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays    < 7)  return 'Il y a ${diff.inDays} j';
  return DateFormat('d MMM yyyy', 'fr_FR').format(dt);
}
