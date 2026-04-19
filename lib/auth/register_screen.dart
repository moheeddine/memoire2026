import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  bool isClient = true;
  LatLng? selectedLocation;
  bool isLoading = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final commerceController = TextEditingController();
  final matriculeController = TextEditingController();

  String? selectedCategory;
  int focusedIndex = -1;
  bool obscure = true;

  final primary = Color(0xFF6366F1);

  List<String> categoriesList = [
    "café",
    "resto",
    "vetement",
    "reparation",
    "publinet",
    "librairie",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          /// BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF020617),
                  Color(0xFF0B1120),
                ],
              ),
            ),
          ),

          Positioned(top: -120, left: -100, child: glow(400)),
          Positioned(bottom: -150, right: -120, child: glow(500)),

          /// CARD
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  width: 380,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [

                      Text("Créer un compte",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),

                      SizedBox(height: 6),

                      Text("Rejoignez la plateforme",
                          style: TextStyle(color: Colors.white38)),

                      SizedBox(height: 25),

                      Row(
                        children: [
                          toggleBtn("Client", true),
                          SizedBox(width: 10),
                          toggleBtn("Entreprise", false),
                        ],
                      ),

                      SizedBox(height: 25),

                      field(0, nameController, "Nom complet",
                          Icons.person_outline),
                      SizedBox(height: 15),

                      field(1, emailController, "Email",
                          Icons.mail_outline),
                      SizedBox(height: 15),

                      field(2, passwordController, "Mot de passe",
                          Icons.lock_outline,
                          isPassword: true),

                      if (!isClient) ...[
                        SizedBox(height: 15),

                        field(3, commerceController,
                            "Nom du commerce",
                            Icons.store),

                        SizedBox(height: 15),

                        field(4, matriculeController,
                            "Matricule fiscal",
                            Icons.badge),

                        SizedBox(height: 20),

                        Text("Catégorie",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),

                        SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          children: categoriesList.map((cat) {
                            bool selected = selectedCategory == cat;

                            return GestureDetector(
                              onTap: () {
                                setState(() => selectedCategory = cat);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? primary
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white70),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        SizedBox(height: 20),

                        GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MapPickerScreen()),
                            );

                            if (result != null) {
                              setState(() => selectedLocation = result);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              selectedLocation == null
                                  ? "Choisir localisation"
                                  : "Lat: ${selectedLocation!.latitude.toStringAsFixed(4)}, "
                                    "Lng: ${selectedLocation!.longitude.toStringAsFixed(4)}",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: 30),

                      GestureDetector(
                        onTap: isLoading ? null : registerUser,
                        child: Container(
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF7C3AED)
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              isLoading
                                  ? "Chargement..."
                                  : "Créer mon compte",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Déjà inscrit ? ",
                              style: TextStyle(color: Colors.white54)),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text("Se connecter",
                                style: TextStyle(
                                    color: Color(0xFF818CF8),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// REGISTER
  Future<void> registerUser() async {
    setState(() => isLoading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "role": isClient ? "client" : "entreprise",
        "createdAt": FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);

    } catch (e) {
      print(e);
    }

    setState(() => isLoading = false);
  }

  /// FIELD
  Widget field(int index, TextEditingController controller,
      String hint, IconData icon,
      {bool isPassword = false}) {

    bool isFocused = focusedIndex == index;

    return Focus(
      onFocusChange: (value) {
        setState(() => focusedIndex = value ? index : -1);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFocused
                ? Color(0xFF6366F1)
                : Colors.transparent,
          ),
        ),
        child: TextField(
          controller: controller,
          obscureText: isPassword ? obscure : false,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            icon: Icon(icon, color: Colors.white70),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() => obscure = !obscure);
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// TOGGLE
  Widget toggleBtn(String text, bool client) {
    bool selected = isClient == client;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isClient = client),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white10,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(text,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  /// GLOW
  Widget glow(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color(0xFF6366F1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// 🗺️ MAP PICKER (FIXED)
////////////////////////////////////////////////////////

class MapPickerScreen extends StatefulWidget {
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {

  LatLng position = LatLng(35.0382, 9.4849);

  @override
  void initState() {
    super.initState();
    getLocation();
  }

  void getLocation() async {
    LocationPermission permission =
        await Geolocator.requestPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {

      final pos = await Geolocator.getCurrentPosition();

      setState(() {
        position = LatLng(pos.latitude, pos.longitude);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Choisir position"),
        backgroundColor: Color(0xFF6366F1),
      ),

      body: Stack(
        children: [

          FlutterMap(
            options: MapOptions(
              initialCenter: position,
              initialZoom: 15,
              onPositionChanged: (pos, _) {
                if (pos.center != null) {
                  position = pos.center!;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
            ],
          ),

          Center(
            child: Icon(Icons.location_pin,
                color: Colors.red, size: 45),
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.pop(context, position);
              },
              child: Text("Confirmer"),
            ),
          )
        ],
      ),
    );
  }
}