import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatelessWidget {
  final String businessId;

  const AdminDashboard({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1F),

      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .snapshots(),

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                  child: Text("No Data", style: TextStyle(color: Colors.white)));
            }

            var data = snapshot.data!;
            var stats = data['stats'] ?? {};
            var weekly = data['weekly_views'] ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 🔥 HEADER
                  const Text(
                    "Dashboard 📊",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),

                  Text(
                    "${data['name'] ?? "Business"} · Avril 2026",
                    style: const TextStyle(color: Colors.white54),
                  ),

                  const SizedBox(height: 20),

                  /// 🔥 STATS GRID
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard("VUES",
                          (stats['views'] ?? 0).toString(), "+23%"),
                      StatCard("CLICS",
                          (stats['clicks'] ?? 0).toString(), "+18%"),
                      StatCard("CONVERSIONS",
                          (stats['conversions'] ?? 0).toString(), "+31%"),
                      StatCard("ÉCONOMIES CLIENT",
                          "${stats['savings'] ?? 0} DT", "+15%"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// 🔥 WEEKLY GRAPH
                  const Text(
                    "Vues cette semaine",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1333),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _bar("Lun", weekly['lun'] ?? 0),
                        _bar("Mar", weekly['mar'] ?? 0),
                        _bar("Mer", weekly['mer'] ?? 0),
                        _bar("Jeu", weekly['jeu'] ?? 0),
                        _bar("Ven", weekly['ven'] ?? 0),
                        _bar("Sam", weekly['sam'] ?? 0),
                        _bar("Dim", weekly['dim'] ?? 0),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// 🔥 PROMOS
                  const Text(
                    "Mes promotions actives",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('businesses')
                        .doc(businessId)
                        .collection('promos')
                        .where('active', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return Container();

                      if (snap.data!.docs.isEmpty) {
                        return const Text(
                          "Aucune promotion active",
                          style: TextStyle(color: Colors.white54),
                        );
                      }

                      return Column(
                        children: snap.data!.docs.map((doc) {
                          var p = doc.data() as Map<String, dynamic>;

                          return PromoTile(
                            title: p['title'] ?? "",
                            views: p['views'] ?? 0,
                            used: p['used'] ?? 0,
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 📊 BAR GRAPH ITEM
  Widget _bar(String day, int value) {
    double height = (value.toDouble() / 3).clamp(10, 120);

    return Column(
      children: [
        Container(
          width: 18,
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: const TextStyle(color: Colors.white54, fontSize: 12))
      ],
    );
  }
}
class StatCard extends StatelessWidget {
  final String title, value, percent;

  const StatCard(this.title, this.value, this.percent, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1333),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("↑ $percent",
              style: const TextStyle(color: Colors.green, fontSize: 12))
        ],
      ),
    );
  }
}

class PromoTile extends StatelessWidget {
  final String title;
  final int views, used;

  const PromoTile({
    super.key,
    required this.title,
    required this.views,
    required this.used,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1333),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [

          /// ICON
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_offer, color: Colors.white),
          ),

          const SizedBox(width: 12),

          /// TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("$views vues · $used utilisations",
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),

          /// STATUS
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Actif",
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }
}