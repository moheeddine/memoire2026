import 'dart:async';
import 'package:flutter/material.dart';
import '../models/reservation_model.dart';
import '../theme/app_theme.dart';

// ─── COUNTDOWN TEXT ────────────────────────────────────────────────────────────
//
// Lightweight widget that owns a single 1-second Timer and renders ONLY the
// remaining-time string.  Embedding this inside a large widget tree keeps
// rebuilds isolated: only this widget and its Text descendant repaint each tick.

class ReservationCountdownText extends StatefulWidget {
  final DateTime expiresAt;
  final TextStyle? style;

  const ReservationCountdownText({
    super.key,
    required this.expiresAt,
    this.style,
  });

  @override
  State<ReservationCountdownText> createState() =>
      _ReservationCountdownTextState();
}

class _ReservationCountdownTextState extends State<ReservationCountdownText> {
  late final Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  void _refresh() {
    final rem = widget.expiresAt.difference(DateTime.now());
    if (mounted) {
      setState(() => _remaining = rem.isNegative ? Duration.zero : rem);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  bool get _isExpired => _remaining == Duration.zero;
  bool get _isUrgent  => !_isExpired && _remaining.inHours < 2;

  String get _label {
    if (_isExpired) return 'Expirée';
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  Color get _defaultColor {
    if (_isExpired) return AppColors.textMuted;
    return _isUrgent ? AppColors.error : AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    return Text(
      _label,
      style: base.copyWith(
        color: widget.style?.color ?? _defaultColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ─── COUNTDOWN CARD ────────────────────────────────────────────────────────────
//
// Full card for the "Mes réservations" list in the profile screen.
// Reusable: drop it anywhere that needs to show a single reservation tile.
//
//  ┌─────────────────────────────────────────────────────┐
//  │  [icon]  Titre de la promo               [badge]   │
//  │          ⏱ Expire dans 23h 14m 08s               │
//  └─────────────────────────────────────────────────────┘

class ReservationCountdownCard extends StatefulWidget {
  final ReservationModel reservation;
  /// Called exactly once when the live countdown crosses zero.
  /// Use this to trigger a Firestore expire write from the parent.
  final VoidCallback?    onExpire;

  const ReservationCountdownCard({
    super.key,
    required this.reservation,
    this.onExpire,
  });

  @override
  State<ReservationCountdownCard> createState() =>
      _ReservationCountdownCardState();
}

class _ReservationCountdownCardState extends State<ReservationCountdownCard> {
  late final Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  void _refresh() {
    final rem  = widget.reservation.expiresAt.difference(DateTime.now());
    final next = rem.isNegative ? Duration.zero : rem;
    if (mounted) {
      final didExpire = _remaining > Duration.zero && next == Duration.zero;
      setState(() => _remaining = next);
      if (didExpire) widget.onExpire?.call();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  bool get _isExpired => _remaining == Duration.zero;
  bool get _isUrgent  => !_isExpired && _remaining.inHours < 2;

  String get _timeLabel {
    if (_isExpired) return 'Expirée';
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    if (h > 0) {
      return 'Expire dans ${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) return 'Expire dans ${m}m ${s.toString().padLeft(2, '0')}s';
    return 'Expire dans ${s}s';
  }

  // Border and timer icon/text share the same semantic color.
  Color get _timerColor {
    if (_isExpired) return AppColors.textMuted;
    return _isUrgent ? AppColors.error : AppColors.success;
  }

  Color get _statusColor {
    switch (widget.reservation.status) {
      case ReservationStatus.confirmed: return AppColors.success;
      default:                          return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (widget.reservation.status) {
      case ReservationStatus.confirmed: return 'Confirmée';
      default:                          return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _timerColor.withValues(alpha: 0.35),
          width: _isUrgent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Leading icon — turns red when urgent
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: _isUrgent
                  ? const LinearGradient(
                      colors: [AppColors.error, Color(0xFFDC2626)],
                    )
                  : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isUrgent ? Icons.timer_outlined : Icons.bookmark_added_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Title + live countdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reservation.promoTitle,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: _timerColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _timeLabel,
                        style: TextStyle(
                          color: _timerColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                color: _statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
