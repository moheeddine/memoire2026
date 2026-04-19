import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class PromoDetailScreen extends StatefulWidget {
  final Map promo;

  const PromoDetailScreen({super.key, required this.promo});

  @override
  State<PromoDetailScreen> createState() => _PromoDetailScreenState();
}

class _PromoDetailScreenState extends State<PromoDetailScreen> {
  bool isFav = false;
String promoId = "";

  void toggleFav() {
    setState(() {
      isFav = !isFav;
    });
  }

  void openMap(double lat, double lng) async {
    final Uri url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
@override
void initState() {
  super.initState();
  promoId = widget.promo['id'] ?? "";
  checkIfFavorite();
}

void checkIfFavorite() async {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  final snapshot = await FirebaseFirestore.instance
      .collection('favorites')
      .where('userId', isEqualTo: userId)
      .where('itemId', isEqualTo: promoId)
      .get();

  if (snapshot.docs.isNotEmpty) {
    setState(() {
      isFav = true;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    print("PROMO DATA => ${widget.promo}");

    final title = widget.promo['title'] ?? "";
    final desc = widget.promo['description'] ?? "";
    final discount = widget.promo['discount'] ?? 0;
    final code = widget.promo['code'] ?? "";
    final conditions = widget.promo['conditions'] ?? "";
    final lat = widget.promo['lat'] ?? 0;
    final lng = widget.promo['lng'] ?? 0;
    final distance = widget.promo['distance'] ?? "--";

    return Scaffold(
      backgroundColor: Color(0xFF0B0B1F),

      body: SafeArea(
        child: ListView(
          children: [

            /// 🔥 HEADER
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C47FF), Color(0xFF9333EA)],
                ),
              ),
              child: Stack(
                children: [

                  Positioned(
                    top: 20,
                    left: 20,
                    child: _circleBtn(Icons.arrow_back, () {
                      Navigator.pop(context);
                    }),
                  ),

                  Positioned(
                    top: 20,
                    right: 20,
                    child: _circleBtn(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      toggleFav,
                    ),
                  ),

                  Center(
                    child: Icon(Icons.local_offer,
                        color: Colors.white, size: 60),
                  ),
                ],
              ),
            ),

            /// 🔥 CONTENT
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF0B0B1F),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// DISCOUNT
                  Text(
                    "-$discount%",
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 10),

                  /// TITLE
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 5),

                  /// DISTANCE
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Colors.red, size: 16),
                      SizedBox(width: 5),
                      Text(
                        "$distance km",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),

                  SizedBox(height: 15),

                  /// BADGES
                  Row(
                    children: [
                      _badge("📅 Expire soon"),
                      SizedBox(width: 10),
                      _badge("⭐ 4.8"),
                      SizedBox(width: 10),
                      _badge("⏱ 9h"),
                    ],
                  ),

                  SizedBox(height: 20),

                  /// DESCRIPTION
                  Text(
                    desc,
                    style: TextStyle(color: Colors.white70),
                  ),

                  SizedBox(height: 20),

                  /// CONDITIONS
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Text(
                      conditions,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),

                  SizedBox(height: 25),

                  /// CODE
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(0xFF8B5CF6)),
                    ),
                    child: Column(
                      children: [
                        Text("CODE PROMO",
                            style: TextStyle(color: Colors.white54)),
                        SizedBox(height: 10),
                        Text(
                          code,
                          style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  /// APPLY
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                    onPressed: () {},
                    child: Text("✔ Utiliser ce code promo"),
                  ),

                  SizedBox(height: 15),

                  /// MAP
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      side: BorderSide(color: Color(0xFF8B5CF6)),
                    ),
                    onPressed: () {
                      openMap(lat, lng);
                    },
                    child: Text("🗺 Naviguer",
                        style:
                            TextStyle(color: Color(0xFF8B5CF6))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔥 circle button
Widget _circleBtn(IconData icon, VoidCallback onTap) {
  return CircleAvatar(
    backgroundColor: Colors.white.withOpacity(0.15),
    child: IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onTap,
    ),
  );
}

Widget _badge(String text) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: Text(
      text,
      style: TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

/// 🔥 badge widget
class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 12)),
    );
  }
}