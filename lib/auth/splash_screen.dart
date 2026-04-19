import 'dart:async';
import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> scaleAnim;

@override
void initState() {
  super.initState();

  _controller =
      AnimationController(vsync: this, duration: Duration(milliseconds: 1200));

  scaleAnim = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  _controller.forward();

  /// 🔥 بدل Timer
  checkUser();
}
Future<void> checkUser() async {
  await Future.delayed(Duration(seconds: 3)); // نفس timing

  final user = FirebaseAuth.instance.currentUser;

  /// ❌ موش connecté
  if (user == null) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OnboardingScreen()),
    );
    return;
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = doc.data()?['role'];

    if (role == "client") {
      Navigator.pushReplacementNamed(context, "/home");
    } else if (role == "entreprise") {
      Navigator.pushReplacementNamed(context, "/business_dashboard");
    } else if (role == "admin") {
      Navigator.pushReplacementNamed(context, "/admin_dashboard");
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnboardingScreen()),
      );
    }

  } catch (e) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OnboardingScreen()),
    );
  }
}
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF7C3AED), // purple
              Color(0xFF6C47FF),
              Color(0xFF3B82F6) // blue
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Spacer(),

              // ICON + SCALE ANIMATION
              ScaleTransition(
                scale: scaleAnim,
                child: Container(
                  padding: EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.location_city,
                    color: Colors.white,
                    size: 55,
                  ),
                ),
              ),

              SizedBox(height: 25),

              // TITLE
              FadeTransition(
                opacity: _controller,
                child: Text(
                  "CityOne",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),

              SizedBox(height: 10),

              // SUBTITLE
              FadeTransition(
                opacity: _controller,
                child: Text(
                  "Découvrez les promos autour de vous",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),

              SizedBox(height: 30),

              // DOTS (like your design)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),

              Spacer(),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  
}
