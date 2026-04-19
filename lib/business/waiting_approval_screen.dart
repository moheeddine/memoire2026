import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../business/dashboard_screen.dart';

class WaitingApprovalScreen extends StatelessWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1F),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final status = data['status'];

          /// 🔥 إذا تولي active → ندخلو dashboard
          if (status == "active") {
            Future.microtask(() {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ Votre compte a été accepté !"),
                ),
              );

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DashboardScreen(businessId: uid),
                ),
              );
            });
          }

          /// 🔥 UI attente
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(25),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C47FF), Color(0xFF9333EA)],
                      ),
                    ),
                    child: const Icon(
                      Icons.hourglass_top,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Merci pour votre inscription 🙏",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Votre compte est en attente de validation par l’administrateur.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),

                  const SizedBox(height: 30),

                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pop(context);
                    },
                    child: const Text("Se déconnecter"),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}