import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import '../theme/app_theme.dart';
import 'star_rating_widget.dart';

// ─── PUBLIC WIDGET ────────────────────────────────────────────────────────────

class CommentSection extends StatefulWidget {
  final String promoId;
  final String businessId;
  final String promoTitle;

  /// Si renseigné, le widget scrolle automatiquement sur ce commentaire
  /// et le met en surbrillance après construction.
  final String? scrollToCommentId;

  const CommentSection({
    super.key,
    required this.promoId,
    required this.businessId,
    required this.promoTitle,
    this.scrollToCommentId,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  // ── Stream commentaires ────────────────────────────────────────────────────
  StreamSubscription<List<CommentModel>>? _sub;
  List<CommentModel> _comments = [];
  bool _loaded = false;

  // ── Formulaire ajout ───────────────────────────────────────────────────────
  final _addCtrl = TextEditingController();
  double _addStars = 0;
  bool _posting = false;

  // ── Contexte utilisateur ───────────────────────────────────────────────────
  String? _uid;
  String _userName = '';
  String? _userPhoto;
  bool _isBusiness = false;
  bool _isAdmin = false;
  bool _userReady = false;

  // ── Stats dérivées ─────────────────────────────────────────────────────────
  int    get _count => _comments.length;
  double get _avg   => _count == 0
      ? 0.0
      : _comments.fold<double>(0, (s, c) => s + c.rating) / _count;
  bool   get _userHasComment =>
      _uid != null && _comments.any((c) => c.userId == _uid);

  // ── GlobalKeys pour scroll-to ──────────────────────────────────────────────
  final Map<String, GlobalKey> _commentKeys = {};

  @override
  void initState() {
    super.initState();
    _sub = CommentService.watchComments(widget.promoId).listen((list) {
      if (mounted) setState(() { _comments = list; _loaded = true; });

      // Après le premier chargement, scroller si demandé
      if (widget.scrollToCommentId != null && !_scrolled) {
        _scrolled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget());
      }
    });
    _loadUser();
  }

  // ─── SCROLL TARGET ───────────────────────────────────────────────────────

  bool _scrolled = false;

  void _scrollToTarget() {
    final key = _commentKeys[widget.scrollToCommentId];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _addCtrl.dispose();
    super.dispose();
  }

  // ─── LOAD USER ────────────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    _uid      = AuthService.currentUid;
    _userPhoto = AuthService.currentUser?.photoURL;
    final data = await AuthService.getCurrentUserData();
    if (mounted) {
      setState(() {
        _userName   = data?.name ?? '';
        _isBusiness = data?.role == UserRole.entreprise &&
            _uid == widget.businessId;
        _isAdmin    = data?.role == UserRole.admin;
        _userReady  = true;
      });
    }
  }

  // ─── POST COMMENT ─────────────────────────────────────────────────────────

  Future<void> _post() async {
    final text = _addCtrl.text.trim();
    if (_addStars == 0) { _snack('Sélectionnez une note.', error: true); return; }
    if (text.length < 10) { _snack('Commentaire trop court (min 10 car.).', error: true); return; }
    if (_uid == null) return;
    setState(() => _posting = true);
    try {
      await CommentService.addComment(
        promoId:    widget.promoId,
        businessId: widget.businessId,
        promoTitle: widget.promoTitle,
        userId:     _uid!,
        userName:   _userName.isNotEmpty ? _userName : 'Utilisateur',
        userPhoto:  _userPhoto,
        comment:    text,
        rating:     _addStars,
      );
      _addCtrl.clear();
      if (mounted) setState(() { _addStars = 0; _posting = false; });
    } catch (_) {
      if (mounted) setState(() => _posting = false);
      _snack('Erreur lors de l\'envoi.', error: true);
    }
  }

  // ─── DELETE COMMENT ───────────────────────────────────────────────────────

  Future<void> _deleteComment(String commentId) async {
    if (!await _confirm('Supprimer ce commentaire définitivement ?')) return;
    try {
      await CommentService.deleteComment(commentId);
    } catch (_) {
      _snack('Erreur lors de la suppression.', error: true);
    }
  }

  // ─── EDIT COMMENT MODAL ───────────────────────────────────────────────────

  void _openEditModal(CommentModel c) {
    final ctrl = TextEditingController(text: c.comment);
    double stars = c.rating;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Handle(),
                const SizedBox(height: 20),
                const Text('Modifier le commentaire',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                StarRatingWidget(
                    rating: stars, size: 34,
                    onRate: (s) => set(() => stars = s)),
                const SizedBox(height: 14),
                _TextField(controller: ctrl, hint: 'Votre commentaire…'),
                const SizedBox(height: 20),
                _GradBtn(
                  label: saving ? 'Enregistrement…' : 'Enregistrer',
                  loading: saving,
                  onTap: () async {
                    final txt = ctrl.text.trim();
                    if (stars == 0 || txt.length < 10) {
                      _snack('Note ou texte invalide.', error: true);
                      return;
                    }
                    set(() => saving = true);
                    try {
                      await CommentService.updateComment(c.id, txt, stars);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (_) {
                      if (ctx.mounted) set(() => saving = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(ctrl.dispose);
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  Future<bool> _confirm(String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmation'),
          content: Text(msg),
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
      ) ?? false;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header stats ──────────────────────────────────────────────────
        _StatsHeader(avg: _avg, count: _count, loaded: _loaded),

        const SizedBox(height: 16),

        // ── Formulaire (caché si user a déjà commenté ou est entreprise) ──
        if (_userReady && _uid != null && !_userHasComment && !_isBusiness) ...[
          _AddForm(
            ctrl:     _addCtrl,
            stars:    _addStars,
            onStars:  (s) => setState(() => _addStars = s),
            onSubmit: _post,
            posting:  _posting,
            userPhoto: _userPhoto,
            userName:  _userName,
          ),
          const SizedBox(height: 16),
        ],

        // ── Liste ─────────────────────────────────────────────────────────
        if (!_loaded)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ),
          )
        else if (_comments.isEmpty)
          const _EmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final c = _comments[i];
              final key = _commentKeys.putIfAbsent(c.id, () => GlobalKey());
              return _CommentCard(
                key:          key,
                comment:      c,
                isOwner:      _uid == c.userId,
                isAdmin:      _isAdmin,
                isBusiness:   _isBusiness,
                businessId:   widget.businessId,
                businessName: _userName,
                promoId:      widget.promoId,
                promoTitle:   widget.promoTitle,
                highlighted:  widget.scrollToCommentId == c.id,
                onEdit:       () => _openEditModal(c),
                onDelete:     () => _deleteComment(c.id),
                snack:        _snack,
              );
            },
          ),
      ],
    );
  }
}

// ─── STATS HEADER ─────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final double avg;
  final int count;
  final bool loaded;

  const _StatsHeader(
      {required this.avg, required this.count, required this.loaded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(tint: AppColors.purple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rate_review_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Avis & Commentaires',
                style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ]),
          if (loaded && count > 0) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  child: Text(
                    avg.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        height: 1),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 7),
                  child: Text(' / 5',
                      style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StarRatingWidget(rating: avg, size: 20),
                    const SizedBox(height: 4),
                    Text('$count avis',
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.warning, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: avg / 5,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.warning),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(avg.toStringAsFixed(1),
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ] else if (loaded) ...[
            const SizedBox(height: 10),
            const Text('Soyez le premier à donner votre avis !',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ─── ADD COMMENT FORM ─────────────────────────────────────────────────────────

class _AddForm extends StatelessWidget {
  final TextEditingController ctrl;
  final double stars;
  final ValueChanged<double> onStars;
  final VoidCallback onSubmit;
  final bool posting;
  final String? userPhoto;
  final String userName;

  const _AddForm({
    required this.ctrl,
    required this.stars,
    required this.onStars,
    required this.onSubmit,
    required this.posting,
    required this.userPhoto,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _Avatar(name: userName, photoUrl: userPhoto, radius: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isNotEmpty ? userName : 'Utilisateur',
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const Text('Ajouter votre avis',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            const Text('Note : ',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            StarRatingWidget(rating: stars, size: 30, onRate: onStars),
            if (stars > 0) ...[
              const SizedBox(width: 8),
              Text(_label(stars),
                  style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ]),
          const SizedBox(height: 12),
          _TextField(controller: ctrl, hint: 'Partagez votre expérience…'),
          const SizedBox(height: 14),
          _GradBtn(
              label: 'Publier l\'avis',
              loading: posting,
              onTap: posting ? null : onSubmit),
        ],
      ),
    );
  }

  String _label(double s) {
    if (s <= 1) return 'Très mauvais';
    if (s <= 2) return 'Mauvais';
    if (s <= 3) return 'Correct';
    if (s <= 4) return 'Bien';
    return 'Excellent !';
  }
}

// ─── COMMENT CARD ─────────────────────────────────────────────────────────────

class _CommentCard extends StatefulWidget {
  final CommentModel comment;
  final bool isOwner;
  final bool isAdmin;
  final bool isBusiness;
  final String businessId;
  final String businessName;
  final String promoId;
  final String promoTitle;
  final bool highlighted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String, {bool error}) snack;

  const _CommentCard({
    super.key,
    required this.comment,
    required this.isOwner,
    required this.isAdmin,
    required this.isBusiness,
    required this.businessId,
    required this.businessName,
    required this.promoId,
    required this.promoTitle,
    required this.highlighted,
    required this.onEdit,
    required this.onDelete,
    required this.snack,
  });

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard>
    with SingleTickerProviderStateMixin {
  // ── Highlight animation ────────────────────────────────────────────────────
  late final AnimationController _hCtrl;
  late final Animation<Color?> _hAnim;

  // ── Reply input ────────────────────────────────────────────────────────────
  bool _showReplyInput = false;
  bool _editingReply   = false;
  final _replyCtrl = TextEditingController();
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _hCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _hAnim = ColorTween(
      begin: const Color(0xFFFFF8C5), // jaune doux
      end: Colors.white,
    ).animate(CurvedAnimation(parent: _hCtrl, curve: Curves.easeOut));

    if (widget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hCtrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  // ─── ACTIONS REPLY ────────────────────────────────────────────────────────

  Future<void> _submitReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    try {
      if (_editingReply && widget.comment.hasReply) {
        await CommentService.updateReply(
            commentId: widget.comment.id, newText: text);
      } else {
        await CommentService.setReply(
          commentId:   widget.comment.id,
          clientId:    widget.comment.userId,
          companyId:   widget.businessId,
          companyName: widget.businessName,
          text:        text,
          promoId:     widget.promoId,
          promoTitle:  widget.promoTitle,
        );
      }
      _replyCtrl.clear();
      if (mounted) {
        setState(() {
          _showReplyInput = false;
          _editingReply   = false;
          _sendingReply   = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sendingReply = false);
      widget.snack('Erreur lors de la réponse.', error: true);
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

  void _startEditReply() {
    _replyCtrl.text = widget.comment.reply!.text;
    setState(() {
      _editingReply   = true;
      _showReplyInput = true;
    });
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;

    return AnimatedBuilder(
      animation: _hAnim,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _hAnim.value ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.highlighted && _hCtrl.isAnimating
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.border,
          ),
          boxShadow: AppColors.cardShadow(),
        ),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author row ─────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: c.userName, photoUrl: c.userPhoto, radius: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(c.userName,
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (c.isEdited)
                        const Text(' · modifié',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 10)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      StarRatingWidget(rating: c.rating, size: 13),
                      const SizedBox(width: 8),
                      Text(_relativeDate(c.createdAt),
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
              if (widget.isOwner || widget.isAdmin)
                _ActionMenu(
                  canEdit:  widget.isOwner,
                  onEdit:   widget.onEdit,
                  onDelete: widget.onDelete,
                ),
            ],
          ),

          // ── Comment text ───────────────────────────────────────────────
          const SizedBox(height: 10),
          Text(c.comment,
              style: const TextStyle(
                  color: AppColors.textBody, fontSize: 14, height: 1.55)),

          // ── Embedded reply ─────────────────────────────────────────────
          if (c.hasReply) ...[
            const SizedBox(height: 12),
            _EmbeddedReply(
              reply:       c.reply!,
              canManage:   widget.isBusiness || widget.isAdmin,
              onEdit:      _startEditReply,
              onDelete:    _deleteReply,
            ),
          ],

          // ── Reply input ────────────────────────────────────────────────
          if (_showReplyInput) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _replyCtrl,
                      minLines: 1,
                      maxLines: 4,
                      autofocus: true,
                      style: const TextStyle(
                          color: AppColors.textDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _editingReply
                            ? 'Modifier la réponse…'
                            : 'Votre réponse…',
                        hintStyle: const TextStyle(
                            color: AppColors.textLight, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SendBtn(
                    loading: _sendingReply, onTap: _sendingReply ? null : _submitReply),
              ],
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() {
                _showReplyInput = false;
                _editingReply   = false;
                _replyCtrl.clear();
              }),
              child: const Text('Annuler',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            ),
          ],

          // ── Reply button (visible pour l'entreprise propriétaire) ──────
          if (widget.isBusiness && !_showReplyInput && !c.hasReply) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showReplyInput = true),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reply_rounded,
                      color: AppColors.primary, size: 16),
                  SizedBox(width: 4),
                  Text('Répondre',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── EMBEDDED REPLY TILE ──────────────────────────────────────────────────────

class _EmbeddedReply extends StatelessWidget {
  final CommentReply reply;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmbeddedReply({
    required this.reply,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.store_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reply.companyName,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Row(children: [
                      Text(_relativeDate(reply.createdAt),
                          style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 10)),
                      if (reply.isEdited)
                        const Text(' · modifié',
                            style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 10)),
                    ]),
                  ],
                ),
              ),
              if (canManage)
                _ActionMenu(
                  canEdit:  canManage,
                  onEdit:   onEdit,
                  onDelete: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reply.text,
              style: const TextStyle(
                  color: AppColors.textBody,
                  fontSize: 13,
                  height: 1.45)),
        ],
      ),
    );
  }
}

// ─── PRIVATE HELPERS ──────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;

  const _Avatar({required this.name, required this.radius, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: AppColors.primaryLight,
        onBackgroundImageError: (_, __) {},
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
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

class _ActionMenu extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionMenu(
      {required this.canEdit, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit')   onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        if (canEdit)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Modifier',
                  style: TextStyle(color: AppColors.textDark, fontSize: 13)),
            ]),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
            SizedBox(width: 8),
            Text('Supprimer',
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ]),
        ),
      ],
      icon: const Icon(Icons.more_vert_rounded,
          color: AppColors.textLight, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _TextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        maxLength: 500,
        style: const TextStyle(color: AppColors.textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          counterStyle:
              const TextStyle(color: AppColors.textLight, fontSize: 11),
        ),
      ),
    );
  }
}

class _GradBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _GradBtn({required this.label, required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.primaryShadow,
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
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
        width: 42, height: 42,
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

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.softGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('Aucun avis pour l\'instant',
                style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Soyez le premier à partager votre expérience !',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── DATE HELPER ─────────────────────────────────────────────────────────────

String _relativeDate(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return 'À l\'instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours   < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays    < 7)  return 'Il y a ${diff.inDays} j';
  return DateFormat('d MMM yyyy', 'fr_FR').format(dt);
}
