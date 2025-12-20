// ignore_for_file: use_build_context_synchronously

import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../pages/acceuil.dart';
import 'connection.dart';

class Inscription extends StatefulWidget {
  const Inscription({super.key});

  @override
  State<Inscription> createState() => _InscriptionState();
}

class _InscriptionState extends State<Inscription> {
  bool _obscure = true;
  String pin = "";

  final emailCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  void _choosePinCode() {
    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Veuillez remplir tous les champs",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Sécurité PayCash",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6D4C41),
              fontSize: 30,
            ),
          ),
          content: Text(
            "Définir mon code PIN ??",
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        Color pinColor;
                        if (pin.length < 4) {
                          pinColor = Colors.red;
                        } else if (pin.length < 6) {
                          pinColor = Colors.orange;
                        } else {
                          pinColor = Colors.green;
                        }

                        return AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            "Choix du code PIN",
                            style: GoogleFonts.poppins(
                              color: Color(0xFF6D4C41),
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Choisissez un code PIN pour protéger votre compte , gardez-le jalousement",
                                style: GoogleFonts.poppins(color: Colors.black),
                              ),
                              const SizedBox(height: 16),
                              // 🔹 Champ PIN avec 8 cases
                              PinCodeTextField(
                                appContext: context,
                                length: 6,
                                obscureText: true,
                                obscuringCharacter: "●",
                                keyboardType: TextInputType.number,
                                enableActiveFill: true,
                                pinTheme: PinTheme(
                                  shape: PinCodeFieldShape.box,
                                  borderRadius: BorderRadius.circular(12),
                                  fieldHeight: 45,
                                  fieldWidth: 43,
                                  inactiveFillColor: Colors.white,
                                  selectedFillColor: Colors.white,
                                  activeFillColor: Colors.white,
                                  inactiveColor: pinColor,
                                  selectedColor: const Color(0xFF6D4C41),
                                  activeColor: pinColor,
                                ),
                                onChanged: (value) {
                                  setState(() => pin = value);
                                },
                              ),

                              const SizedBox(height: 10),
                              Text(
                                pin.length < 4
                                    ? "PIN trop court"
                                    : pin.length < 6
                                    ? "Robustesse moyenne"
                                    : "PIN valide",
                                style: TextStyle(
                                  color: pinColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Annuler",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: pin.length == 6
                                    ? Colors.green
                                    : const Color(0xFF6D4C41),
                              ),
                              onPressed: pin.length == 6
                                  ? () {
                                      signup(); // ⚠️ hash le PIN AVANT stockage
                                      Navigator.pop(context);
                                    }
                                  : null,
                              child: const Text(
                                "Continuer",
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: const Text("Oui, Tout de suite"),
            ),
            TextButton(
              onPressed: () {
                signupWithoutPin();
              },
              child: const Text("Non, Plus tard"),
            ),
          ],
        );
      },
    );
  }

  void signup() async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        passwordCtrl.text.isEmpty) {
      return;
    }
    if (!phoneCtrl.text.startsWith("+228")) {
      phoneCtrl.text = "+228$phoneCtrl.text";
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

      String pinHash = BCrypt.hashpw(pin, BCrypt.gensalt());

      await firestore.collection('users').doc(result.user!.uid).set({
        'name': nameCtrl.text,
        'email': emailCtrl.text,
        'phone': phoneCtrl.text,
        'pin': pinHash,
        'pinSet': true,
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

  void signupWithoutPin() async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        passwordCtrl.text.isEmpty) {
      return;
    }

    if (!phoneCtrl.text.startsWith("+228")) {
      phoneCtrl.text = "+228$phoneCtrl.text";
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
        'pin': "",
        'pinSet': false,
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                  keyboardType: TextInputType.name,
                  label: "Nom complet",
                  hintText: "E.g: jean gustave",
                  icon: Icons.person,
                  color: brown,
                ),
                const SizedBox(height: 20),

                // ⭐ Champ Email
                _field(
                  keyboardType: TextInputType.emailAddress,
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
                  keyboardType: TextInputType.phone,
                  label: "Téléphone",
                  hintText: "votre numéro de téléphone",
                  icon: Icons.phone_android,
                  color: brown,
                ),
                const SizedBox(height: 20),
                TextField(
                  obscureText: _obscure,
                  controller: passwordCtrl,
                  cursorColor: Colors.black,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock, color: brown),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: brown,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    ),
                    hintText: "",
                    labelText: "Mot de passe",
                    labelStyle: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7EFEA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: brown),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: brown, width: 2),
                    ),
                  ),
                ),

                // ⭐ Champ Mot de passe
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
                    onPressed: _choosePinCode,
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
    required keyboardType,
  }) {
    return TextField(
      controller: controller,
      cursorColor: color,
      keyboardType: keyboardType,
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
