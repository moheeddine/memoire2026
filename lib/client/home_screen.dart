import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../utils/app_routes.dart';
import '../models/promo_model.dart';
import '../services/auth_service.dart';
import '../services/promo_service.dart';
import '../services/business_service.dart';
import '../services/category_service.dart';
import '../services/favorite_service.dart';
import '../services/rating_service.dart';
import '../services/recommendation_service.dart';
import '../services/notification_manager.dart';
import '../services/reservation_service.dart';
import '../models/reservation_model.dart';
import '../utils/promo_expiration_checker.dart';
import '../widgets/client_navbar.dart';
import '../widgets/notification_overlay.dart';
import '../widgets/star_rating_widget.dart';
import 'promo_detail_screen.dart';

// ─── TOP-LEVEL HELPERS ────────────────────────────────────────────────────────

IconData _catIcon(String? cat) {
  switch (cat) {
    case 'café':       return Icons.coffee_rounded;
    case 'resto':      return Icons.restaurant_rounded;
    case 'vetement':   return Icons.checkroom_rounded;
    case 'reparation': return Icons.build_rounded;
    case 'publinet':   return Icons.computer_rounded;
    case 'librairie':  return Icons.menu_book_rounded;
    default:           return Icons.store_rounded;
  }
}

String _catEmoji(String cat) {
  switch (cat.toLowerCase()) {
    case 'tous':       return '🏷️';
    case 'café':       return '☕';
    case 'resto':      return '🍽️';
    case 'vetement':   return '👗';
    case 'reparation': return '🔧';
    case 'publinet':   return '💻';
    case 'librairie':  return '📚';
    default:           return '🏷️';
  }
}

// ─── HOME SCREEN ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int    _selectedCat    = 0;
  String _searchQuery    = '';
  Map?   _selectedMarker;

  List<String>      _categories      = ['Tous'];
  List<PromoModel>  _recommendations = [];
  List<PromoModel>  _popularPromos   = [];
  Set<String>       _favBusinessIds  = {};
  List<Marker>      _markers         = [];
  String            _userName        = '';
  String?           _uid;
  bool              _nearbyNotified  = false;
  Timer?            _searchDebounce;

  LatLng _center = const LatLng(35.0382, 9.4849);

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCategories();
    _getLocation();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await AuthService.getCurrentUserData();
    if (mounted && u != null) {
      setState(() {
        _userName = u.name.split(' ').first;
        _uid      = u.uid;
      });
    }
    _loadFavs();
  }

  Future<void> _loadFavs() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    final ids = await FavoriteService.getFavoriteBusinessIds(uid);
    if (mounted) setState(() => _favBusinessIds = ids);
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.getNames();
    // Fall back to business-derived categories if admin hasn't set any
    if (cats.isEmpty) {
      final fallback = await BusinessService.getCategories();
      if (mounted) setState(() => _categories = ['Tous', ...fallback]);
    } else {
      if (mounted) setState(() => _categories = ['Tous', ...cats]);
    }
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _center = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
    // Auto-expire stale promos before loading the feed (debounced, max once/15 min)
    PromoService.autoExpirePromos();
    await _loadRecommendations();
    await _loadMarkers();
  }

  Future<void> _loadRecommendations() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    try {
      final results = await Future.wait([
        RecommendationService.getRecommendations(
          userId: uid,
          userLat: _center.latitude,
          userLng: _center.longitude,
        ),
        RecommendationService.getPopularNearby(
          userLat: _center.latitude,
          userLng: _center.longitude,
        ),
      ]);
      final recs    = results[0];
      final popular = results[1];
      if (mounted) {
        setState(() {
          _recommendations = recs;
          _popularPromos   = popular;
        });
      }

      // Flash deal notifications
      for (final p in recs) {
        if (p.isFlashActive && p.flashEndTime != null) {
          final rem = p.flashEndTime!.difference(DateTime.now());
          if (!rem.isNegative) {
            if (rem.inHours < 1) {
              final mins = rem.inMinutes;
              final label = mins > 0 ? '${mins}min' : 'quelques secondes';
              await NotificationManager.flashDealEndingSoon(
                promoTitle: p.title,
                timeLeft: label,
              );
              break;
            } else if (rem.inMinutes > 30) {
              NotificationManager.scheduleFlashDealAlert(
                promoId:     p.id,
                promoTitle:  p.title,
                flashEndTime: p.flashEndTime!,
              );
            }
          }
        }
      }

      // Nearby promo notification (once per session)
      if (!_nearbyNotified) {
        for (final p in [...recs, ..._popularPromos]) {
          final dist = p.distanceMeters;
          if (dist != null && dist < 1000 && p.businessName != null) {
            _nearbyNotified = true;
            final distLabel = dist < 100
                ? '${dist.toInt()}m'
                : '${(dist / 1000).toStringAsFixed(1)} km';
            NotificationManager.nearbyPromo(
              promoTitle:    p.title,
              businessName:  p.businessName!,
              distanceLabel: distLabel,
              promoId:       p.id,
            );
            break;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMarkers() async {
    try {
      final businesses = await BusinessService.getActiveBusinesses();
      final markers = <Marker>[];
      for (final b in businesses) {
        if (_selectedCat != 0 && b.category != _categories[_selectedCat]) {
          continue;
        }
        if (_searchQuery.isNotEmpty &&
            !b.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }
        final pt = LatLng(b.lat, b.lng);
        final dist = Geolocator.distanceBetween(
            _center.latitude, _center.longitude, pt.latitude, pt.longitude);
        markers.add(Marker(
          point: pt,
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: () => setState(() => _selectedMarker = {
              'id': b.uid, 'name': b.name, 'desc': b.category,
              'lat': pt.latitude, 'lng': pt.longitude,
              'distance': (dist / 1000).toStringAsFixed(2),
            }),
            child: _AnimatedMarker(icon: _catIcon(b.category)),
          ),
        ));
      }
      if (mounted) setState(() => _markers = markers);
    } catch (_) {}
  }

  Future<void> _toggleFav(String businessId) async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    await FavoriteService.toggleBusinessFavorite(uid, businessId);
    final ids = await FavoriteService.getFavoriteBusinessIds(uid);
    if (mounted) setState(() => _favBusinessIds = ids);
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap avec NotificationWrapper pour les popups temps réel
    return NotificationWrapper(
      userId: _uid ?? '',
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1 ── Gradient header (welcome + search bar) ─────────────────
            _HomeHeader(
              userName: _userName,
              uid:      _uid,
              onSearchChanged: (v) {
                _searchQuery = v;
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                  if (mounted) _loadMarkers();
                });
              },
            ),

            const SizedBox(height: 16),

            // 2 ── Category chips ─────────────────────────────────────────
            _CategoryFilterBar(
              categories: _categories,
              selectedIndex: _selectedCat,
              onSelect: (i) {
                setState(() => _selectedCat = i);
                _loadMarkers();
              },
            ),

            const SizedBox(height: 20),

            // 3 ── Flash Deals ─────────────────────────────────────────────
            const _FlashDealsSection(),

            // 3b ─ Dernière Chance (< 24h remaining) ──────────────────────
            const _DerniereChanceSection(),

            // 4 ── AI Recommendations ──────────────────────────────────────
            if (_recommendations.isNotEmpty) ...[
              _RecommendationCarousel(recommendations: _recommendations),
              const SizedBox(height: 20),
            ],

            // 5 ── Popular nearby ──────────────────────────────────────────
            if (_popularPromos.isNotEmpty) ...[
              _PopularCarousel(popularPromos: _popularPromos),
              const SizedBox(height: 20),
            ],

            // 6 ── Active reservation banner ───────────────────────────────
            const _ActiveReservationsBanner(),

            // 7 ── Promos feed ─────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Promos à proximité',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.location_on_rounded,
                      size: 12, color: AppColors.accent),
                  SizedBox(width: 3),
                  Text(
                    'Par distance',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            _PromosList(center: _center),

            const SizedBox(height: 24),

            // 8 ── Interactive map (last — discoverable, not blocking) ──────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          'Carte des commerces',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.map_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Interactif',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMarker = null),
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: _center,
                                initialZoom: 14,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.example.memoire2026',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _center,
                                      width: 36,
                                      height: 36,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: AppColors.primaryGradient,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.my_location,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                    ..._markers,
                                  ],
                                ),
                              ],
                            ),
                            if (_selectedMarker != null)
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: _MapPopup(
                                  marker: _selectedMarker!,
                                  isFav: _favBusinessIds
                                      .contains(_selectedMarker!['id']),
                                  onMap: () => _openMap(
                                    _selectedMarker!['lat'],
                                    _selectedMarker!['lng'],
                                  ),
                                  onFav: () => _toggleFav(
                                      _selectedMarker!['id'] as String),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: const ClientNavbar(currentIndex: 0),
      ), // Scaffold
    ); // NotificationWrapper
  }
}

// ─── MAP POPUP ────────────────────────────────────────────────────────────────

class _MapPopup extends StatelessWidget {
  final Map          marker;
  final bool         isFav;
  final VoidCallback onMap;
  final VoidCallback onFav;

  const _MapPopup({
    required this.marker,
    required this.isFav,
    required this.onMap,
    required this.onFav,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  marker['name'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${marker['distance']} km · ${marker['desc']}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFav,
            child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onMap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Aller',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SHARED SECTION HEADER ────────────────────────────────────────────────────
// Single consistent pattern for all home-screen sections.

class _HomeSectionHeader extends StatelessWidget {
  final String  emoji;
  final String  title;
  final String? subtitle;

  const _HomeSectionHeader({
    required this.emoji,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji  $title',
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── PROMOS FEED LIST ─────────────────────────────────────────────────────────

enum _SortOption { nearest, highestDiscount, newest, expiringSoon }

class _PromosList extends StatefulWidget {
  final LatLng center;
  const _PromosList({required this.center});

  @override
  State<_PromosList> createState() => _PromosListState();
}

class _PromosListState extends State<_PromosList> {
  _SortOption _sort = _SortOption.nearest;

  static const _sortLabels = {
    _SortOption.nearest:       ('📍', 'Proches'),
    _SortOption.highestDiscount: ('🔥', 'Réduction'),
    _SortOption.newest:        ('🆕', 'Récentes'),
    _SortOption.expiringSoon:  ('⏳', 'Expire bientôt'),
  };

  List<PromoModel> _applySort(List<PromoModel> promos) {
    final list = List<PromoModel>.of(promos);
    switch (_sort) {
      case _SortOption.nearest:
        list.sort((a, b) {
          if (a.lat == null || a.lng == null) return 1;
          if (b.lat == null || b.lng == null) return -1;
          final dA = Geolocator.distanceBetween(widget.center.latitude,
              widget.center.longitude, a.lat!, a.lng!);
          final dB = Geolocator.distanceBetween(widget.center.latitude,
              widget.center.longitude, b.lat!, b.lng!);
          return dA.compareTo(dB);
        });
      case _SortOption.highestDiscount:
        list.sort((a, b) =>
            b.effectiveDiscountPct.compareTo(a.effectiveDiscountPct));
      case _SortOption.newest:
        list.sort((a, b) {
          final da = a.createdAt ?? DateTime(2000);
          final db = b.createdAt ?? DateTime(2000);
          return db.compareTo(da);
        });
      case _SortOption.expiringSoon:
        list.sort((a, b) {
          if (a.expirationDate == null) return 1;
          if (b.expirationDate == null) return -1;
          return a.expirationDate!.compareTo(b.expirationDate!);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PromoModel>>(
      stream: PromoService.watchApproved(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(3, (_) => const AppSkeletonCard()),
            ),
          );
        }

        final raw = (snap.data ?? [])
            .where((p) => p.isEffectivelyActive)
            .toList();

        if (raw.isEmpty) {
          return const AppEmptyState(
            icon:       Icons.local_offer_outlined,
            message:    'Aucune promo disponible\npour le moment',
            fullScreen: true,
          );
        }

        final promos = _applySort(raw);

        return Column(children: [
          // ── Sort bar ──────────────────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _SortOption.values.map((opt) {
                final active = opt == _sort;
                final (emoji, label) = _sortLabels[opt]!;
                return GestureDetector(
                  onTap: () => setState(() => _sort = opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 0),
                    decoration: BoxDecoration(
                      gradient: active
                          ? AppColors.primaryGradient : null,
                      color: active ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? Colors.transparent : AppColors.border,
                      ),
                      boxShadow: active
                          ? [BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.25),
                              blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(label,
                          style: TextStyle(
                            color:      active ? Colors.white : AppColors.textMuted,
                            fontSize:   12,
                            fontWeight: active
                                ? FontWeight.w700 : FontWeight.w500,
                          )),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // ── Cards ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: promos
                  .map((p) => _PromoFeedCard(
                        promo:  p,
                        center: widget.center,
                      ))
                  .toList(),
            ),
          ),
        ]);
      },
    );
  }
}

// ─── INSTAGRAM-STYLE PROMO CARD ───────────────────────────────────────────────

class _PromoFeedCard extends StatefulWidget {
  final PromoModel promo;
  final LatLng     center;
  const _PromoFeedCard({required this.promo, required this.center});

  @override
  State<_PromoFeedCard> createState() => _PromoFeedCardState();
}

class _PromoFeedCardState extends State<_PromoFeedCard> {
  double? _rating;

  @override
  void initState() {
    super.initState();
    RatingService.getAverageRating(widget.promo.businessId)
        .then((r) { if (mounted) setState(() => _rating = r); });
  }

  double? _distKm() {
    if (widget.promo.lat == null || widget.promo.lng == null) return null;
    return Geolocator.distanceBetween(
            widget.center.latitude, widget.center.longitude,
            widget.promo.lat!, widget.promo.lng!) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    final promo  = widget.promo;
    final distKm = _distKm();

    final isInactive = !promo.isEffectivelyActive;

    return AppPressable(
      scale: 0.985,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PromoDetailScreen(promo: promo)),
      ),
      child: Stack(
        children: [
          Container(
        margin: const EdgeInsets.only(bottom: 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Business header ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        promo.businessName?.isNotEmpty == true
                            ? promo.businessName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promo.businessName ?? 'Commerce',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (promo.category != null)
                          Text(
                            promo.category!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (distKm != null) ...[
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 2),
                    Text(
                      '${distKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Image / Banner ──────────────────────────────────────────
            Stack(
              children: [
                promo.imageUrls.isNotEmpty
                    ? Image.network(
                        promo.imageUrls.first,
                        height: 210,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _fallbackBanner(),
                        errorBuilder: (_, __, ___) => _fallbackBanner(),
                      )
                    : _fallbackBanner(),
                // Gradient overlay for cinematic depth + badge contrast
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.45, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                ),
                // Discount badge (colour scales with discount size)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _DiscountBadge(pct: promo.effectiveDiscountPct),
                ),
                // Flash deal badge
                if (promo.isFlashActive)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🔥', style: TextStyle(fontSize: 11)),
                          SizedBox(width: 4),
                          Text(
                            'Flash Deal',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (promo.isExpired)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Expirée',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else if (promo.isExpiringSoon)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: promo.isEmergencyExpiring
                            ? AppColors.error
                            : promo.isCriticallyExpiring
                                ? const Color(0xFFF97316)
                                : const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (promo.isEmergencyExpiring
                                    ? AppColors.error
                                    : const Color(0xFFF97316))
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        promo.urgencyCountdown,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Info ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo.title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (promo.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      promo.description,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // ── Pricing row ──────────────────────────────────────
                  const SizedBox(height: 10),
                  _PricingRow(promo: promo),

                  // ── Social proof — reservation count ─────────────────
                  if (promo.currentReservations > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_rounded,
                            size: 13, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          '${promo.currentReservations} réservation${promo.currentReservations > 1 ? "s" : ""}',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Flash countdown (only when active)
                  if (promo.isFlashActive) ...[
                    _FlashCountdown(endTime: promo.flashEndTime!),
                    const SizedBox(height: 10),
                  ],

                  // Expiration countdown + remaining spots badges
                  Builder(builder: (_) {
                    final countdown =
                        PromoExpirationChecker.expirationCountdown(promo);
                    final spotsLabel =
                        PromoExpirationChecker.remainingSpotsLabel(promo);
                    if (countdown == null && spotsLabel == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (countdown != null)
                            _infoBadge(
                              '⏳ $countdown',
                              countdown == 'Expirée'
                                  ? AppColors.error
                                  : const Color(0xFFF97316),
                            ),
                          if (spotsLabel != null)
                            _infoBadge(
                              spotsLabel,
                              spotsLabel == 'Complet'
                                  ? AppColors.error
                                  : PromoExpirationChecker.isAlmostFull(promo)
                                      ? AppColors.primary
                                      : AppColors.info,
                            ),
                        ],
                      ),
                    );
                  }),

                  // Rating + Share + CTA — all wrapped to prevent overflow
                  Row(
                    children: [
                      // Rating — Flexible so it shrinks if space is tight
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StarRatingWidget(
                                rating: _rating ?? 0.0, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _rating != null && _rating! > 0
                                    ? _rating!.toStringAsFixed(1)
                                    : 'Non noté',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Share button
                      GestureDetector(
                        onTap: () => _sharePromo(promo),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.share_rounded,
                              color: AppColors.primary, size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // CTA button — fixed width, never expands
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Voir l'offre",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
          // Grey overlay for inactive promos
          if (isInactive)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Non disponible',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _sharePromo(PromoModel p) {
    final business = p.businessName ?? 'un commerce';
    final pct = p.effectiveDiscountPct.toStringAsFixed(0);
    final pricing = p.hasPricingData
        ? '💰 ${p.newPrice!.toStringAsFixed(0)} DT au lieu de '
          '${p.oldPrice!.toStringAsFixed(0)} DT (-$pct%)\n\n'
        : '🏷️ $pct% de réduction\n\n';
    final text = '🔥 ${p.title} — $pct% de réduction chez $business !\n\n'
        '${p.description.isNotEmpty ? '${p.description}\n\n' : ''}'
        '$pricing'
        '${p.code.isNotEmpty ? '🏷️ Code promo : ${p.code}\n\n' : ''}'
        'Découvrez cette offre sur PromoCity !';
    Share.share(text, subject: p.title);
  }

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _fallbackBanner() {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.softGradient),
      child: Center(
        child: Icon(
          _catIcon(widget.promo.category),
          size: 70,
          color: const Color(0x66EC4899),
        ),
      ),
    );
  }
}

// ─── DISCOUNT BADGE ──────────────────────────────────────────────────────────
// Colour and size scale with the discount magnitude.

class _DiscountBadge extends StatelessWidget {
  final double pct;
  const _DiscountBadge({required this.pct});

  LinearGradient get _gradient {
    if (pct >= 60) {
      return const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      );
    }
    if (pct >= 40) {
      return const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      );
    }
    if (pct >= 20) {
      return const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFEA580C)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      );
    }
    return AppColors.primaryGradient;
  }

  double get _fontSize => pct >= 50 ? 16 : 14;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_gradient.colors.first).withValues(alpha: 0.50),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '-${pct.toStringAsFixed(0)}%',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: _fontSize,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ─── PRICING ROW ─────────────────────────────────────────────────────────────
// Shows old price (strikethrough) + new price + savings chip.

class _PricingRow extends StatelessWidget {
  final PromoModel promo;
  const _PricingRow({required this.promo});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##', 'fr_FR');

    if (!promo.hasPricingData) {
      // Legacy promo — show discount chip only
      return Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '-${promo.discount}% de réduction',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12, fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ]);
    }

    final saved = promo.effectiveSavedAmount;
    final discColor = promo.effectiveDiscountPct >= 40
        ? const Color(0xFFEA580C) : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Old price (strikethrough)
            Text(
              '${fmt.format(promo.oldPrice!)} DT',
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.error,
                decorationThickness: 1.8,
              ),
            ),
            const SizedBox(width: 8),
            // New price (prominent)
            Text(
              '${fmt.format(promo.newPrice!)} DT',
              style: TextStyle(
                color: discColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
        if (saved != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.30)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.savings_rounded,
                  color: AppColors.success, size: 13),
              const SizedBox(width: 5),
              Text(
                'Économie ${fmt.format(saved)} DT',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 11, fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

// ─── GRADIENT HEADER ─────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final String userName;
  final String? uid;
  final ValueChanged<String> onSearchChanged;

  const _HomeHeader({
    required this.userName,
    required this.onSearchChanged,
    this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour${userName.isNotEmpty ? ', $userName' : ''} 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.8)),
                        const SizedBox(width: 3),
                        Text(
                          'Promos près de vous',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Cloche notifications client ─────────────────────────
              if (uid != null) ...[
                NotificationBell(userId: uid!),
                const SizedBox(width: 10),
              ],

              // ── Avatar profil ───────────────────────────────────────
              AppPressable(
                haptic: false,
                onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      userName.isNotEmpty
                          ? userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(color: AppColors.textDark, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Rechercher une promo, un commerce...',
                hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.primary, size: 20),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CATEGORY FILTER BAR ─────────────────────────────────────────────────────

class _CategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final int          selectedIndex;
  final ValueChanged<int> onSelect;

  const _CategoryFilterBar({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final sel = selectedIndex == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                gradient: sel ? AppColors.primaryGradient : null,
                color: sel ? null : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: sel ? Colors.transparent : AppColors.border,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Text(
                '${_catEmoji(categories[i])} ${categories[i]}',
                style: TextStyle(
                  color: sel ? Colors.white : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── AI RECOMMENDATION CAROUSEL ──────────────────────────────────────────────

class _RecommendationCarousel extends StatelessWidget {
  final List<PromoModel> recommendations;
  const _RecommendationCarousel({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HomeSectionHeader(
          emoji: '✨',
          title: 'Recommandations IA',
          subtitle: 'Sélectionnées pour vous',
        ),
        Builder(builder: (ctx) {
          final cardW = (MediaQuery.sizeOf(ctx).width * 0.40).clamp(130.0, 190.0);
          final imgH  = cardW * 0.60;
          return SizedBox(
            height: cardW * 1.20,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommendations.length,
              itemBuilder: (ctx2, i) {
                final p = recommendations[i];
                final hasImg = p.imageUrls.isNotEmpty;
                return AppPressable(
                  onTap: () => Navigator.push(
                    ctx2,
                    MaterialPageRoute(
                        builder: (_) => PromoDetailScreen(promo: p)),
                  ),
                  child: Container(
                    width: cardW,
                    margin: const EdgeInsets.only(right: 12),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      gradient: hasImg ? null : AppColors.softGradient,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasImg)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft:  Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            child: Image.network(
                              p.imageUrls.first,
                              width: cardW,
                              height: imgH,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _RecoIconTile(
                                  icon: _catIcon(p.category),
                                  width: cardW,
                                  height: imgH),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_catIcon(p.category),
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        if (!hasImg) const Spacer(),
                        Padding(
                          padding: EdgeInsets.fromLTRB(12, hasImg ? 8 : 0, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '-${p.discount}%',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '📍 ${p.distanceLabel}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.primary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

// ─── POPULAR NEARBY CAROUSEL ─────────────────────────────────────────────────

class _PopularCarousel extends StatelessWidget {
  final List<PromoModel> popularPromos;
  const _PopularCarousel({required this.popularPromos});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HomeSectionHeader(
          emoji: '🔥',
          title: 'Populaire près de vous',
          subtitle: 'Les plus réservées du moment',
        ),
        Builder(builder: (ctx) {
          final cardW = (MediaQuery.sizeOf(ctx).width * 0.50).clamp(170.0, 240.0);
          return SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: popularPromos.length,
              itemBuilder: (ctx2, i) {
                final p = popularPromos[i];
                return AppPressable(
                  onTap: () => Navigator.push(
                    ctx2,
                    MaterialPageRoute(
                        builder: (_) => PromoDetailScreen(promo: p)),
                  ),
                  child: Container(
                    width: cardW,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: _orange.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: _orange.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: p.imageUrls.isNotEmpty
                              ? Image.network(
                                  p.imageUrls.first,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _PopularIconTile(
                                          icon: _catIcon(p.category)),
                                )
                              : _PopularIconTile(
                                  icon: _catIcon(p.category)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '-${p.discount}%',
                                    style: const TextStyle(
                                      color: _orange,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '📍 ${p.distanceLabel}',
                                      style: const TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${p.views} vues · ${p.used} utilisations',
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 10),
                              ),
                              Builder(builder: (_) {
                                final spotsLabel =
                                    PromoExpirationChecker.remainingSpotsLabel(p);
                                if (spotsLabel == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    spotsLabel,
                                    style: TextStyle(
                                      color: spotsLabel == 'Complet'
                                          ? AppColors.error
                                          : PromoExpirationChecker.isAlmostFull(p)
                                              ? AppColors.purple
                                              : AppColors.info,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

// ─── CARD ICON TILES (fallbacks for image thumbnails) ────────────────────────

class _RecoIconTile extends StatelessWidget {
  final IconData icon;
  final double   width;
  final double   height;
  const _RecoIconTile({
    required this.icon,
    this.width  = double.infinity,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: AppColors.softGradient,
        ),
        child: Icon(icon, color: AppColors.primary, size: 32),
      );
}

class _PopularIconTile extends StatelessWidget {
  final IconData icon;
  const _PopularIconTile({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 50,
        height: 50,
        color: const Color(0xFFFFF3E0),
        child: Icon(icon, color: const Color(0xFFFF6B00), size: 22),
      );
}

// ─── FLASH COUNTDOWN ──────────────────────────────────────────────────────────

// ─── FLASH DEALS SECTION ─────────────────────────────────────────────────────

class _FlashDealsSection extends StatelessWidget {
  const _FlashDealsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PromoModel>>(
      stream: PromoService.watchFlashDeals(),
      builder: (context, snap) {
        final deals = snap.data ?? [];
        if (deals.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HomeSectionHeader(
              emoji: '⚡',
              title: 'Flash Deals',
              subtitle: 'Offres limitées dans le temps',
            ),
            SizedBox(
              height: 116,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: deals.length,
                itemBuilder: (ctx, i) {
                  final p = deals[i];
                  return AppPressable(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => PromoDetailScreen(promo: p)),
                    ),
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              const Color(0xFFF97316).withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316)
                                .withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                '-${p.discount}%',
                                style: const TextStyle(
                                  color: Color(0xFFF97316),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              const Text('🔥',
                                  style: TextStyle(fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.title,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p.businessName != null) ...[
                            Text(
                              p.businessName!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (p.flashEndTime != null) ...[
                            const SizedBox(height: 6),
                            _FlashCountdown(endTime: p.flashEndTime!),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

// ─── FLASH COUNTDOWN ──────────────────────────────────────────────────────────

class _FlashCountdown extends StatefulWidget {
  final DateTime endTime;
  const _FlashCountdown({required this.endTime});

  @override
  State<_FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<_FlashCountdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final rem = widget.endTime.difference(DateTime.now());
    if (mounted) setState(() => _remaining = rem.isNegative ? Duration.zero : rem);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⏱️', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            'Se termine dans ${_fmt(_remaining)}',
            style: const TextStyle(
              color: Color(0xFFFF6B00),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RESERVATION COUNTDOWN TEXT ───────────────────────────────────────────────

class _ReservationCountdownText extends StatefulWidget {
  final ReservationModel soonest;
  const _ReservationCountdownText({required this.soonest});

  @override
  State<_ReservationCountdownText> createState() =>
      _ReservationCountdownTextState();
}

class _ReservationCountdownTextState
    extends State<_ReservationCountdownText> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.isNegative || d == Duration.zero) return 'Expirée';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.soonest.expiresAt.difference(_now);
    return Row(
      children: [
        const Icon(Icons.access_time_rounded, color: Colors.white70, size: 12),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '⏳ ${_format(remaining)} — ${widget.soonest.promoTitle}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── DERNIÈRE CHANCE SECTION ─────────────────────────────────────────────────
// Promos with < 24h remaining. Sorted by urgency (most critical first).

class _DerniereChanceSection extends StatelessWidget {
  const _DerniereChanceSection();

  static const _kOrange = Color(0xFFF97316);
  static const _kRed    = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PromoModel>>(
      stream: PromoService.watchApproved(),
      builder: (context, snap) {
        final promos = (snap.data ?? [])
            .where((p) => p.isExpiringSoon)
            .toList()
          ..sort((a, b) {
            final ha = a.hoursUntilExpiry ?? 24;
            final hb = b.hoursUntilExpiry ?? 24;
            return ha.compareTo(hb);
          });

        if (promos.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HomeSectionHeader(
              emoji: '🚨',
              title: 'Dernière Chance',
              subtitle: 'Expire dans moins de 24h',
            ),
            SizedBox(
              height: 128,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: promos.length,
                itemBuilder: (ctx, i) {
                  final p = promos[i];
                  final isEmergency = p.isEmergencyExpiring;
                  final isCritical  = p.isCriticallyExpiring;
                  final cardColor   = isEmergency
                      ? const Color(0xFFFEF2F2)
                      : isCritical
                          ? const Color(0xFFFFF7ED)
                          : const Color(0xFFFFFBEB);
                  final accentColor = isEmergency ? _kRed : _kOrange;

                  return AppPressable(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => PromoDetailScreen(promo: p)),
                    ),
                    child: Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.40)),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.urgencyCountdown,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '-${p.effectiveDiscountPct.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.title,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p.businessName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.businessName!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

// ─── ANIMATED MARKER ──────────────────────────────────────────────────────────

class _AnimatedMarker extends StatefulWidget {
  final IconData icon;
  const _AnimatedMarker({required this.icon});

  @override
  State<_AnimatedMarker> createState() => _AnimatedMarkerState();
}

class _AnimatedMarkerState extends State<_AnimatedMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 2),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ACTIVE RESERVATIONS BANNER ───────────────────────────────────────────────

class _ActiveReservationsBanner extends StatefulWidget {
  const _ActiveReservationsBanner();

  @override
  State<_ActiveReservationsBanner> createState() =>
      _ActiveReservationsBannerState();
}

class _ActiveReservationsBannerState
    extends State<_ActiveReservationsBanner> {
  bool _autoExpired = false;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<ReservationModel>>(
      stream: ReservationService.watchUserReservations(uid),
      builder: (context, snap) {
        // Batch-expire stale docs on first snapshot
        if (!_autoExpired && snap.data != null) {
          _autoExpired = true;
          ReservationService.autoExpireForUser(uid);
        }

        final active = (snap.data ?? []).where((r) => r.isActive).toList();
        if (active.isEmpty) return const SizedBox.shrink();

        active.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
        final soonest   = active.first;
        final remaining = soonest.expiresAt.difference(DateTime.now());
        final isUrgent  = remaining.inHours < 2 && !remaining.isNegative;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isUrgent
                    ? const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      )
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isUrgent ? AppColors.error : AppColors.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isUrgent
                          ? Icons.timer_outlined
                          : Icons.bookmark_added_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.length == 1
                              ? '1 réservation active'
                              : '${active.length} réservations actives',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _ReservationCountdownText(soonest: soonest),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
