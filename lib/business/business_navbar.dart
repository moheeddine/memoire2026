import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard_screen.dart';
import 'add_promo_screen.dart';
import 'manage_promos_screen.dart';
import 'business_profile_screen.dart';

class BusinessNavbar extends StatefulWidget {
  final int currentIndex;
  final String businessId;

  const BusinessNavbar({
    super.key,
    required this.currentIndex,
    required this.businessId,
  });

  @override
  State<BusinessNavbar> createState() => _BusinessNavbarState();
}

class _BusinessNavbarState extends State<BusinessNavbar> {
  late int currentIndex;

  final icons = [
    Icons.dashboard,
    Icons.add_circle,
    Icons.settings,
    Icons.person,
  ];

  final labels = ["Dashboard", "Add", "Manage", "Profile"];

  @override
  void initState() {
    currentIndex = widget.currentIndex;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 🌫️ BLUR
          child: Container(
            height: 75,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05), // glass
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              children: [
                /// 🔥 INDICATOR
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: (width - 30) / 4 * currentIndex,
                  top: 8,
                  child: Container(
                    width: (width - 30) / 4,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C47FF), Color(0xFF9333EA)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),

                /// 🔥 ITEMS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(icons.length, (index) {
                    bool active = currentIndex == index;

                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          setState(() {
                            currentIndex = index;
                          });

                          navigate(index);
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            /// ICON + TEXT
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icons[index],
                                  color: active ? Colors.white : Colors.white54,
                                ),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: active ? 1 : 0,
                                  child: Text(
                                    labels[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            /// 🔥 BADGE (manage only)
                            if (index == 2)
                              Positioned(
                                top: 8,
                                right: 25,
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('promos')
                                      .where(
                                        'businessId',
                                        isEqualTo: widget.businessId,
                                      )
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return SizedBox();

                                    int count = snapshot.data!.docs.length;

                                    if (count == 0) return SizedBox();

                                    return Container(
                                      padding: EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        count.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔥 NAVIGATION
  void navigate(int index) {
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

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ManagePromosScreen(businessId: widget.businessId),
        ),
      );
    }

    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessProfileScreen(businessId: widget.businessId),
        ),
      );
    }
  }
}
