import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// IMPORT NAVBAR
import 'business_navbar.dart';

class BusinessProfileScreen extends StatelessWidget {
  final String businessId;

  const BusinessProfileScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1F),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Mon profil"),
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>?;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                /// 👤 AVATAR
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.store, size: 40, color: Colors.white),
                ),

                const SizedBox(height: 15),

                /// NAME
                Text(
                  data?['name'] ?? "Entreprise",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                /// EMAIL
                Text(
                  user?.email ?? "",
                  style: const TextStyle(color: Colors.white54),
                ),

                const SizedBox(height: 30),

                /// INFO
                infoTile("Catégorie", data?['category']),
                infoTile("Téléphone", data?['phone']),
                infoTile("Ville", data?['city']),

                const Spacer(),

                /// 🚪 LOGOUT
                GestureDetector(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();

                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      "/login",
                      (route) => false,
                    );
                  },
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.redAccent],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Text(
                        "Se déconnecter",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),

      /// 🔥 NAVBAR (FIX 🔥🔥🔥)
      bottomNavigationBar: BusinessNavbar(
        currentIndex: 3, // 👈 profile active
        businessId: businessId,
      ),
    );
  }

  Widget infoTile(String title, dynamic value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1333),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white54)),
          ),
          Text(
            value?.toString() ?? "-",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
