import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// IMPORT
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int currentIndex = 4; // 👈 profile active

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Color(0xFF0B0B1F),

      /// BODY
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              /// HEADER
              Row(
                children: [
                  Icon(Icons.person, color: Colors.purple),
                  SizedBox(width: 10),
                  Text(
                    "Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30),

              /// AVATAR
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.purple,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),

              SizedBox(height: 15),

              /// EMAIL
              Text(
                user?.email ?? "No Email",
                style: TextStyle(color: Colors.white),
              ),

              SizedBox(height: 30),

              /// MENU
              profileItem(Icons.favorite, "Mes favoris"),
              profileItem(Icons.local_offer, "Mes promos"),
              profileItem(Icons.settings, "Paramètres"),

              Spacer(),

              /// LOGOUT
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, "/login");
                },
                child: Text("Se déconnecter"),
              ),
            ],
          ),
        ),
      ),

      /// 🔥 NAVBAR
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Color(0xFF0F0F2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            navItem(Icons.home, 0),
            navItem(Icons.favorite, 1),
            navItem(Icons.smart_toy, 2),
            navItem(Icons.notifications, 3),
            navItem(Icons.person, 4),
          ],
        ),
      ),
    );
  }

  /// 🔥 NAV ITEM
  Widget navItem(IconData icon, int index) {
    bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        }

        setState(() {
          currentIndex = index;
        });
      },
      child: Icon(icon, color: isActive ? Colors.purple : Colors.white54),
    );
  }

  /// UI ITEM
  Widget profileItem(IconData icon, String title) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFF1A1333),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: 10),
          Text(title, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
