import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/promo_model.dart';
import '../services/auth_service.dart';
import '../services/promo_service.dart';
import '../services/business_service.dart';
import '../services/favorite_service.dart';
import '../services/recommendation_service.dart';
import '../widgets/client_navbar.dart';
import 'promo_detail_screen.dart';

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
  Set<String>       _favBusinessIds  = {};
  List<Marker>      _markers         = [];
  String            _userName        = '';

  LatLng _center = const LatLng(35.0382, 9.4849);

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCategories();
    _getLocation();
  }

  Future<void> _loadUser() async {
    final u = await AuthService.getCurrentUserData();
    if (mounted && u != null) {
      setState(() => _userName = u.name.split(' ').first);
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
    final cats = await BusinessService.getCategories();
    if (mounted) setState(() => _categories = ['Tous', ...cats]);
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
    await _loadRecommendations();
    await _loadMarkers();
  }

  Future<void> _loadRecommendations() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    try {
      final recs = await RecommendationService.getRecommendations(
        userId: uid, userLat: _center.latitude, userLng: _center.longitude,
      );
      if (mounted) setState(() => _recommendations = recs);
    } catch (_) {}
  }

  Future<void> _loadMarkers() async {
    try {
      final businesses = await BusinessService.getActiveBusinesses();
      final markers = <Marker>[];
      for (final b in businesses) {
        if (_selectedCat != 0 && b.category != _categories[_selectedCat]) continue;
        if (_searchQuery.isNotEmpty &&
            !b.name.toLowerCase().contains(_searchQuery.toLowerCase())) continue;
        final pt = LatLng(b.lat, b.lng);
        final dist = Geolocator.distanceBetween(
          _center.latitude, _center.longitude, pt.latitude, pt.longitude);
        markers.add(Marker(
          point: pt, width: 56, height: 56,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Gradient header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                gradient: AppColors.mainGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour, $_userName 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
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
                      // Notification icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Search bar
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
                      onChanged: (v) {
                        _searchQuery = v;
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (mounted) _loadMarkers();
                        });
                      },
                      style: const TextStyle(
                          color: AppColors.textDark, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une promo, un commerce...',
                        hintStyle:
                            TextStyle(color: AppColors.textLight, fontSize: 13),
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
            ),

            const SizedBox(height: 16),

            // ── Category chips ───────────────────────────────────────────
            SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final sel = _selectedCat == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCat = i);
                      _loadMarkers();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
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
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        '${_catEmoji(_categories[i])} ${_categories[i]}',
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
            ),

            const SizedBox(height: 16),

            // ── Map ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
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
                              userAgentPackageName: 'com.example.memoire2026',
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
                                        )
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
                              onFav: () =>
                                  _toggleFav(_selectedMarker!['id'] as String),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── AI Recommendations ───────────────────────────────────────
            if (_recommendations.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Text('✨', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Text(
                            'IA POUR VOUS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recommendations.length,
                  itemBuilder: (_, i) {
                    final p = _recommendations[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PromoDetailScreen(promo: p)),
                      ),
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: AppColors.softGradient,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_catIcon(p.category),
                                  color: Colors.white, size: 20),
                            ),
                            const Spacer(),
                            Text(
                              p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
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
                              style: const TextStyle(
                                  color: AppColors.primary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Promos list ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Promos à proximité',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Voir tout',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _PromosList(center: _center),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const ClientNavbar(currentIndex: 0),
    );
  }
}

// ─── MAP POPUP ────────────────────────────────────────────────────────────────

class _MapPopup extends StatelessWidget {
  final Map marker;
  final bool isFav;
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

// ─── PROMOS LIST ──────────────────────────────────────────────────────────────

class _PromosList extends StatelessWidget {
  final LatLng center;
  const _PromosList({required this.center});

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PromoModel>>(
      stream: PromoService.watchApproved(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final promos = snap.data ?? [];
        if (promos.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.local_offer_outlined,
                      size: 48, color: AppColors.textLight),
                  SizedBox(height: 12),
                  Text('Aucune promo disponible',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: promos.map((promo) {
              final distKm = (promo.lat != null && promo.lng != null)
                  ? Geolocator.distanceBetween(
                          center.latitude, center.longitude,
                          promo.lat!, promo.lng!) /
                      1000
                  : 0.0;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PromoDetailScreen(promo: promo)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner
                      Container(
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: AppColors.softGradient,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                _catIcon(promo.category),
                                size: 48,
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '-${promo.discount}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            if (promo.isExpired)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    '⏰ Expire bientôt',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Info
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    promo.title,
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (promo.lat != null) ...[
                                  const Icon(Icons.location_on,
                                      size: 13, color: AppColors.accent),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${distKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              promo.description,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (promo.businessName != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.store_outlined,
                                      size: 13, color: AppColors.textLight),
                                  const SizedBox(width: 4),
                                  Text(
                                    promo.businessName!,
                                    style: const TextStyle(
                                        color: AppColors.textLight,
                                        fontSize: 12),
                                  ),
                                  if (promo.category != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        promo.category!,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
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
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
