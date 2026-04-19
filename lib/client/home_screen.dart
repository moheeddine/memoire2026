import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'promo_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_screen.dart';

// ─── COLORS ────────────────────────────────────────────────────────────────
const kPrimary       = Color(0xFF7C3AED); // purple-600
const kPrimaryLight  = Color(0xFFEDE9FE); // purple-100
const kPrimaryFaint  = Color(0xFFF5F0FF); // page bg
const kAccentOrange  = Color(0xFFEA580C);
const kTextDark      = Color(0xFF1E1B4B);
const kTextMuted     = Color(0xFF6B7280);
const kBorder        = Color(0xFFEDE9FE);
const kWhite         = Colors.white;
// ───────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

Map<String, String> favorites = {};

class _HomeScreenState extends State<HomeScreen> {
  int selectedCategory = 0;
  Map? selectedPromo;

  List<String> categories = ["Tous"];
  String searchQuery = "";
  int currentIndex = 0;

  LatLng center = LatLng(35.0382, 9.4849);

  List<Marker> firestoreMarkers = [];
  List<Map<String, dynamic>> aiList = [];

  @override
  void initState() {
    super.initState();
    loadAI();
    loadFavorites();
    loadCategories();
    getLocation();
    loadEntreprises();
  }

  void loadAI() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('promos')
        .where('status', isEqualTo: 'approved')
        .get();

    List<Map<String, dynamic>> temp = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['lat'] == null || data['lng'] == null) continue;

      double dist = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        data['lat'],
        data['lng'],
      );

      data['distance'] = dist;
      temp.add(data);
    }

    temp.sort((a, b) => a['distance'].compareTo(b['distance']));

    setState(() {
      aiList = temp.take(4).toList();
    });
  }

  void getLocation() async {
    final permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition();
      setState(() => center = LatLng(pos.latitude, pos.longitude));
      loadAI();
      loadEntreprises();
    }
  }

  void loadCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'entreprise')
        .where('status', isEqualTo: 'active')
        .get();

    Set<String> cats = {"Tous"};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['cat'] != null) cats.add(data['cat']);
    }

    setState(() => categories = cats.toList()..sort());
  }

  void loadEntreprises() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'entreprise')
        .where('status', isEqualTo: 'active')
        .get();

    List<Marker> markers = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['lat'] == null || data['lng'] == null) continue;
      if (selectedCategory != 0 &&
          data['cat'] != categories[selectedCategory]) continue;
      if (searchQuery.isNotEmpty &&
          !(data['commerceName'] ?? "")
              .toLowerCase()
              .contains(searchQuery.toLowerCase())) continue;

      LatLng point = LatLng(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      );

      double distance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        point.latitude,
        point.longitude,
      );

      markers.add(
        Marker(
          point: point,
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedPromo = {
                  "name": data['commerceName'],
                  "desc": data['cat'],
                  "lat": point.latitude,
                  "lng": point.longitude,
                  "distance": (distance / 1000).toStringAsFixed(2),
                };
              });
            },
            child: _AnimatedMarker(icon: getIconByCategory(data['cat'])),
          ),
        ),
      );
    }

    setState(() => firestoreMarkers = markers);
  }

  void openMap(double lat, double lng) async {
    final Uri url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not open map';
    }
  }

  void toggleFavorite(String itemId, String type) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final favRef = FirebaseFirestore.instance.collection('favorites');

    if (favorites.containsKey(itemId)) {
      final snapshot = await favRef
          .where('userId', isEqualTo: userId)
          .where('itemId', isEqualTo: itemId)
          .get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      setState(() => favorites.remove(itemId));
    } else {
      await favRef.add({"userId": userId, "itemId": itemId, "type": type});
      setState(() => favorites[itemId] = type);
    }
  }

  void loadFavorites() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .get();

    setState(() {
      favorites = {for (var doc in snapshot.docs) doc['itemId']: doc['type']};
    });
  }

  IconData getIconByCategory(String? cat) {
    switch (cat) {
      case "café":      return Icons.coffee;
      case "resto":     return Icons.restaurant;
      case "vetement":  return Icons.checkroom;
      case "reparation":return Icons.build;
      case "publinet":  return Icons.computer;
      case "librairie": return Icons.menu_book;
      default:          return Icons.store;
    }
  }

  // ─── NAV ITEM ─────────────────────────────────────────────────────────────
  Widget navItem(IconData icon, String label, int index, BuildContext context) {
    bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => currentIndex = index);
        if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileScreen()),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isActive ? kPrimaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isActive ? kPrimary : kTextMuted,
              size: 22,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? kPrimary : kTextMuted,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryFaint,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          children: [
            SizedBox(height: 16),

            // ── HEADER ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bonjour, Yasmine 👋",
                      style: TextStyle(
                        color: kTextDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 13, color: kPrimary),
                        SizedBox(width: 3),
                        Text(
                          "Tunis · 14 promos près de vous",
                          style: TextStyle(color: kPrimary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                // Notification bell
                Stack(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: kWhite,
                        shape: BoxShape.circle,
                        border: Border.all(color: kBorder),
                      ),
                      child: Icon(Icons.notifications_outlined,
                          color: kPrimary, size: 20),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: kWhite, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 20),

            // ── MAP ─────────────────────────────────────────────────────────
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GestureDetector(
                  onTap: () => setState(() => selectedPromo = null),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}",
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: center,
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: kWhite, width: 2.5),
                                  ),
                                  child: Icon(Icons.my_location,
                                      color: kWhite, size: 16),
                                ),
                              ),
                              ...firestoreMarkers,
                            ],
                          ),
                        ],
                      ),

                      // POPUP
                      if (selectedPromo != null)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: kBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimary.withOpacity(0.10),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedPromo!["name"],
                                  style: TextStyle(
                                    color: kTextDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  selectedPromo!["desc"],
                                  style: TextStyle(
                                      color: kTextMuted, fontSize: 12),
                                ),
                                SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 12, color: kPrimary),
                                    SizedBox(width: 3),
                                    Text(
                                      "${selectedPromo!["distance"]} km",
                                      style: TextStyle(
                                          color: kPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => openMap(
                                          selectedPromo!["lat"],
                                          selectedPromo!["lng"],
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kPrimary,
                                          foregroundColor: kWhite,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                        child: Text("Aller",
                                            style:
                                                TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.red.shade100),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => toggleFavorite(
                                          selectedPromo!["name"],
                                          "entreprise",
                                        ),
                                        icon: Icon(
                                          favorites.containsKey(
                                                  selectedPromo!["name"])
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
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

            SizedBox(height: 18),

            // ── SEARCH ──────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: kBorder),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.06),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: TextField(
                onChanged: (val) {
                  searchQuery = val;
                  loadEntreprises();
                },
                style: TextStyle(color: kTextDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Rechercher une promo, un commerce...",
                  hintStyle: TextStyle(color: Color(0xFFC4B5FD), fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, color: kPrimary, size: 20),
                  suffixIcon: Container(
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.add, color: kPrimary, size: 18),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            SizedBox(height: 16),

            // ── CATEGORIES ──────────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  bool selected = selectedCategory == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedCategory = i);
                      loadEntreprises();
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? kPrimary : kWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? kPrimary : kBorder,
                        ),
                      ),
                      child: Text(
                        _catEmoji(categories[i]) + " " + categories[i],
                        style: TextStyle(
                          color: selected ? kWhite : kPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 18),

            // ── AI RECOMMENDATIONS ──────────────────────────────────────────
            if (aiList.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("✨", style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          "IA RECOMMANDE POUR VOUS",
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: aiList.length,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.05,
                      ),
                      itemBuilder: (_, i) {
                        final e = aiList[i];
                        return Container(
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFAF5FF),
                                Color(0xFFEDE9FE)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Color(0xFFE9D5FF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: kWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kBorder),
                                ),
                                child: Icon(
                                  getIconByCategory(e['category']),
                                  color: kPrimary,
                                  size: 20,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                e['description'] ?? "Promo",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: kTextDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "-${e['discount'] ?? 0}%",
                                style: TextStyle(
                                    color: kAccentOrange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "📍 ${(e['distance'] / 1000).toStringAsFixed(1)} km",
                                style: TextStyle(
                                    color: kPrimary, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],

            // ── PROMOS LIST ─────────────────────────────────────────────────
            Text(
              "Promos à proximité",
              style: TextStyle(
                color: kTextDark,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),

            SizedBox(height: 12),

            buildPromosList(),

            SizedBox(height: 20),
          ],
        ),
      ),

      // ── BOTTOM NAV ────────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        height: 75,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            navItem(Icons.home_rounded,     "Accueil",  0, context),
            navItem(Icons.favorite_rounded, "Favoris",  1, context),
            navItem(Icons.smart_toy_rounded,"IA",       2, context),
            navItem(Icons.notifications_rounded, "Alertes", 3, context),
            navItem(Icons.person_rounded,   "Profil",   4, context),
          ],
        ),
      ),
    );
  }

  // ─── PROMOS LIST ──────────────────────────────────────────────────────────
  Widget buildPromosList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('promos')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();

        final promos = snapshot.data!.docs;

        return Column(
          children: promos.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final p = {
              ...data,
              "distance": data['distance'] ?? "1.2",
              "lat": data['lat'] ?? 35.0,
              "lng": data['lng'] ?? 9.0,
            };

            final Color bannerColor = _categoryColor(p['category']);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PromoDetailScreen(promo: p),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: kWhite,
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── BANNER ─────────────────────────────────────────────
                    Container(
                      height: 115,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(22)),
                        color: bannerColor,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              _catEmojiLarge(p['category']),
                              style: TextStyle(fontSize: 38),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "-${p['discount']}%",
                                style: TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── BODY ───────────────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                p['title'] ?? "",
                                style: TextStyle(
                                  color: kTextDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 12, color: kPrimary),
                                  SizedBox(width: 2),
                                  Text(
                                    "${p['distance'] is num ? (p['distance'] / 1000).toStringAsFixed(1) : p['distance']} km",
                                    style: TextStyle(
                                        color: kPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Text(
                            p['description'] ?? "",
                            style: TextStyle(
                                color: kTextMuted, fontSize: 13),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              _Tag(
                                  label: p['category'] ?? "",
                                  bg: kPrimaryLight,
                                  fg: kPrimary),
                              SizedBox(width: 8),
                              _Tag(
                                label: "Expire bientôt",
                                bg: Color(0xFFFEFCE8),
                                fg: Color(0xFFCA8A04),
                                borderColor: Color(0xFFFDE68A),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  String _catEmoji(String cat) {
    switch (cat.toLowerCase()) {
      case "tous":       return "🏷️";
      case "food":       return "🍔";
      case "café":       return "☕";
      case "resto":      return "🍽️";
      case "mode":
      case "vetement":   return "👗";
      case "beauté":     return "💄";
      case "reparation": return "🔧";
      case "publinet":   return "💻";
      case "librairie":  return "📚";
      default:           return "🏷️";
    }
  }

  String _catEmojiLarge(String? cat) {
    switch ((cat ?? "").toLowerCase()) {
      case "food":
      case "resto":   return "🍕";
      case "café":    return "☕";
      case "mode":
      case "vetement":return "👗";
      case "beauté":  return "💄";
      default:        return "🛍️";
    }
  }

  Color _categoryColor(String? cat) {
    switch ((cat ?? "").toLowerCase()) {
      case "food":
      case "resto":    return Color(0xFFFFF7ED); // orange-50
      case "café":     return Color(0xFFFFF8E1); // amber-50
      case "mode":
      case "vetement": return kPrimaryLight;
      case "beauté":   return Color(0xFFFDF2F8); // pink-50
      default:         return Color(0xFFF0F9FF); // blue-50
    }
  }
}

// ─── TAG WIDGET ───────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final Color? borderColor;

  const _Tag({
    required this.label,
    required this.bg,
    required this.fg,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? bg),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: fg, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── ANIMATED MARKER ──────────────────────────────────────────────────────
class _AnimatedMarker extends StatefulWidget {
  final IconData icon;
  const _AnimatedMarker({required this.icon});

  @override
  State<_AnimatedMarker> createState() => _AnimatedMarkerState();
}

class _AnimatedMarkerState extends State<_AnimatedMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        return Transform.scale(
          scale: 1 + controller.value * 0.25,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimary,
                  border: Border.all(color: kWhite, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(
                          0.35 + controller.value * 0.25),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: kWhite, size: 18),
              ),
              // Pin tail
              Container(
                width: 0,
                height: 0,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        width: 5, color: Colors.transparent),
                    right: BorderSide(
                        width: 5, color: Colors.transparent),
                    top: BorderSide(width: 7, color: kPrimary),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
