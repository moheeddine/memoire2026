import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_navbar.dart';

// IMPORT PAGES
import 'dashboard_screen.dart';
import 'add_promo_screen.dart';

class ManagePromosScreen extends StatefulWidget {
  final String businessId;

  const ManagePromosScreen({super.key, required this.businessId});

  @override
  State<ManagePromosScreen> createState() => _ManagePromosScreenState();
}

class _ManagePromosScreenState extends State<ManagePromosScreen> {
  int currentIndex = 2; // manage active

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1F),

      /// 🔥 APPBAR
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Mes promotions"),
      ),

      /// 🔥 BODY
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('promos')
            .where('businessId', isEqualTo: widget.businessId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Aucune promotion",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return promoCard(context, doc.id, data);
            }).toList(),
          );
        },
      ),

      /// 🔥 NAVBAR
      bottomNavigationBar: BusinessNavbar(
        currentIndex: 2,
        businessId: widget.businessId,
      ),
    );
  }

  /// 🔥 NAV ITEM
  Widget navItem(IconData icon, String label, int index) {
    bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          currentIndex = index;
        });

        /// NAVIGATION
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardScreen(businessId: widget.businessId),
            ),
          );
        }

        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddPromoScreen()),
          );
        }
      },
      child: Row(
        children: [
          Icon(icon, color: isActive ? Colors.white : Colors.white54),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 PROMO CARD
  Widget promoCard(BuildContext context, String id, Map<String, dynamic> data) {
    String title = data['title'] ?? "";
    int discount = data['discount'] ?? 0;
    String status = data['status'] ?? "active";
    int views = data['views'] ?? 0;
    int used = data['used'] ?? 0;

    Color color = status == "active" ? Colors.green : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1333),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TITLE
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "-$discount%",
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "$views vues · $used utilisations",
            style: const TextStyle(color: Colors.white54),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// STATUS
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status, style: TextStyle(color: color)),
              ),

              /// ACTIONS
              Row(
                children: [
                  /// ▶️ ACTIVE
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('promos')
                          .doc(id)
                          .update({"status": "active"});
                    },
                  ),

                  /// ⛔ TERMINER
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.grey),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('promos')
                          .doc(id)
                          .update({"status": "ended"});
                    },
                  ),

                  /// 🗑 DELETE
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('promos')
                          .doc(id)
                          .delete();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Promo supprimée")),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
