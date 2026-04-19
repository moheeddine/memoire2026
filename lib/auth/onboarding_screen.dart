import 'package:flutter/material.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController controller = PageController();
  int index = 0;

  final data = [
    {
      "title": "Économisez à chaque sortie",
      "desc":
          "Utilisez vos codes promo directement depuis l'application et naviguez vers le commerce en un clic.",
      "icon": Icons.monetization_on
    },
    {
      "title": "IA qui apprend vos préférences",
      "desc":
          "Notre intelligence artificielle analyse vos habitudes pour vous suggérer les offres les plus pertinentes.",
      "icon": Icons.auto_awesome
    },
    {
      "title": "Promos proches",
      "desc":
          "Découvrez les meilleures offres autour de vous en temps réel.",
      "icon": Icons.location_on
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B0B1F), Color(0xFF14143C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  onPageChanged: (i) => setState(() => index = i),
                  itemCount: data.length,
                  itemBuilder: (_, i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ICON CIRCLE (Glow effect)
                          Container(
                            padding: EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF6C47FF).withOpacity(0.4),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            child: Icon(
                              data[i]["icon"] as IconData,
                              size: 50,
                              color: Colors.amber,
                            ),
                          ),

                          SizedBox(height: 40),

                          // TITLE
                          Text(
                            data[i]["title"] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 15),

                          // DESC
                          Text(
                            data[i]["desc"] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // DOTS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(data.length, (i) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: index == i ? 25 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == i
                          ? Color(0xFF8B5CF6)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              ),

              SizedBox(height: 30),

              // BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: GestureDetector(
                  onTap: () {
                    if (index == data.length - 1) {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LoginScreen()));
                    } else {
                      controller.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    }
                  },
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C47FF), Color(0xFF9333EA)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF6C47FF).withOpacity(0.6),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "Continuer →",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 15),

              // SKIP
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()));
                },
                child: Text(
                  "Passer",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}