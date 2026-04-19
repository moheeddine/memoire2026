import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class AddPromoScreen extends StatefulWidget {
  @override
  State<AddPromoScreen> createState() => _AddPromoScreenState();
}

class _AddPromoScreenState extends State<AddPromoScreen> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final discountController = TextEditingController();
  final codeController = TextEditingController();
  final conditionsController = TextEditingController();

  DateTime? selectedDate;
  bool isLoading = false;

  /// 🔥 ADD PROMO FUNCTION
  Future<void> addPromo() async {
    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      if (titleController.text.isEmpty ||
          descController.text.isEmpty ||
          discountController.text.isEmpty) {
        throw Exception("Champs obligatoires");
      }

      /// 🔥 نجيب بيانات entreprise
      final businessDoc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(uid)
          .get();

      if (!businessDoc.exists) {
        throw Exception("Entreprise non trouvée");
      }

      final data = businessDoc.data();

      /// 🔥 SAVE PROMO
      await FirebaseFirestore.instance.collection('promos').add({
        "title": titleController.text.trim(),
        "description": descController.text.trim(),
        "discount": int.parse(discountController.text.trim()),
        "code": codeController.text.trim(),

        "conditions": conditionsController.text.trim(),

        "expirationDate": selectedDate,

        "businessId": uid,
        "businessName": data?['name'] ?? "",

        /// 🔥 ناخذ category + location من business
        "category": data?['category'],
        "lat": data?['lat'],
        "lng": data?['lng'],

        "status": "approved",
        "views": 0,
        "clicks": 0,
        "used": 0,

        "createdAt": FieldValue.serverTimestamp(),
      });
      await NotificationService.sendNotificationToUsers(
        "🔥 Nouvelle promotion !",
        "Découvrez maintenant",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "🎉 Promotion ajoutée avec succès !",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context); // ترجع للصفحة السابقة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text("🎉 Promotion ajoutée avec succès !"),
        ),
      );

      Navigator.pop(context);

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0B0B1F),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("Nouvelle promotion"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            /// TITLE
            input("Ex: Pizza Large -40%", titleController),

            SizedBox(height: 20),

            /// DESCRIPTION
            label("DESCRIPTION"),
            input("Décrivez votre offre...", descController, maxLines: 3),

            SizedBox(height: 20),

            /// REDUCTION + CODE
            Row(
              children: [
                Expanded(
                  child: input(
                    "Ex: 40",
                    discountController,
                    labelText: "RÉDUCTION (%)",
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: input(
                    "PIZZA40",
                    codeController,
                    labelText: "CODE PROMO",
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            /// DATE
            label("DATE D'EXPIRATION"),
            datePicker(),

            SizedBox(height: 20),

            /// IMAGE (UI فقط تو)
            label("IMAGES"),
            imageBox(),

            SizedBox(height: 20),

            /// CONDITIONS
            label("CONDITIONS"),
            input(
              "Conditions d'utilisation...",
              conditionsController,
              maxLines: 3,
            ),

            SizedBox(height: 30),

            GestureDetector(
              onTap: isLoading ? null : addPromo,
              child: button(
                isLoading ? "Chargement..." : "Publier la promotion",
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// UI

  Widget label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }

  Widget input(
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    String? labelText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Color(0xFF1A1333),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget datePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );

        if (date != null) {
          setState(() => selectedDate = date);
        }
      },
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Color(0xFF1A1333),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          selectedDate == null
              ? "jj / mm / aaaa"
              : DateFormat('dd/MM/yyyy').format(selectedDate!),
          style: TextStyle(
            color: selectedDate == null ? Colors.white38 : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget imageBox() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(
          "📷 Ajouter des photos",
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  Widget button(String text) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF9333EA)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
