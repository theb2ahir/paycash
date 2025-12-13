import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pages/acceuil.dart';
import 'connection.dart';

class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionState();
}

class _InscriptionState extends State<Inscription> {
  bool _obscurePassword = true;

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  void signup() async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        passwordCtrl.text.isEmpty) {
      return;
    }

    try {
      if (!emailCtrl.text.contains('@gmail.com')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Email invalide , vérifiez votre adresse",
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      UserCredential result = await auth.createUserWithEmailAndPassword(
        email: emailCtrl.text,
        password: passwordCtrl.text,
      );

      String idUnique =
          '${nameCtrl.text}_pay_${phoneCtrl.text}_cash_${result.user!.uid}_id';

      await firestore.collection('users').doc(result.user!.uid).set({
        'name': nameCtrl.text,
        'email': emailCtrl.text,
        'phone': phoneCtrl.text,
        'status': "active",
        'idUnique': idUnique,
        'balance': 0,
        'createdAt': DateTime.now(),
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF5D4037),
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.lightGreenAccent),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Inscription réussie',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Acceuil()),
          (Route<dynamic> route) => false,
        );
      });
    } catch (e) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF5D4037);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: brown),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),

                Text(
                  "Bienvenue sur PayCash",
                  style: GoogleFonts.poppins(
                    fontSize: 42,
                    color: const Color(0xFF5E3B1E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 35),

                // ⭐ Champ Nom
                _field(
                  controller: nameCtrl,
                  label: "Nom complet",
                  hintText: "E.g: jean gustave",
                  icon: Icons.person,
                  color: brown,
                ),
                const SizedBox(height: 20),

                // ⭐ Champ Email
                _field(
                  controller: emailCtrl,
                  label: "Email",
                  hintText: "E.g: johngustave@gmail.com",
                  icon: Icons.email_outlined,
                  color: brown,
                ),
                const SizedBox(height: 20),

                // ⭐ Champ Téléphone
                _field(
                  controller: phoneCtrl,
                  label: "Téléphone",
                  hintText: "E.g: +22892349698",
                  icon: Icons.phone_android,
                  color: brown,
                ),
                const SizedBox(height: 20),

                // ⭐ Mot de Passe
                TextField(
                  controller: passwordCtrl,
                  obscureText: _obscurePassword,
                  cursorColor: brown,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline, color: brown),
                    labelText: "Mot de passe",
                    labelStyle: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: Color(0xFFF7EFEA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: brown),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: brown, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: brown,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      "* 9 caractères maximum",
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 35),

                // ⭐ BOUTON INSCRIPTION
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: signup,
                    child: Text(
                      "M'inscrire",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // ⭐ Déjà un compte ?
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Vous avez déjà un compte ? ",
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => Connection()),
                        );
                      },
                      child: Text(
                        "Connectez-vous",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFD9B76F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📌 Widget réutilisable pour champs
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      cursorColor: color,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: color),
        hintText: hintText,
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: const Color(0xFFF7EFEA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }
}
