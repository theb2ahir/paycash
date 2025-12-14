// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  bool loading = false;

  Future resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF5D4037),
          content: Text(
            "Veuillez entrer votre adresse e-mail",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF5D4037),
          content: Text(
            "Lien de réinitialisation envoyé !",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color(0xFF5D4037),
          content: Text(
            e.message ?? "Une erreur est survenue",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF5D4037);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: brown),
        title: Text(
          "Réinitialisation",
          style: GoogleFonts.roboto(
            color: brown,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(18.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Entrez votre adresse e-mail et nous vous enverrons un lien pour réinitialiser votre mot de passe.",
              style: GoogleFonts.roboto(
                fontSize: 17,
                height: 1.4,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 30),

            // ⭐ Champ E-mail Redesign
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              cursorColor: brown,
              style: const TextStyle(color: Colors.black),

              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined, color: brown),
                labelText: "Votre e-mail",
                labelStyle: const TextStyle(color: Colors.black),

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
              ),
            ),

            const SizedBox(height: 35),

            // ⭐ Bouton d'envoi
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Envoyer",
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
