// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:paycash/auth/forgotpassword/forgortpassword.dart';
import 'package:paycash/pages/verifypin.dart';

import '../pages/acceuil.dart';
import 'inscription.dart';
import 'othermethodes/phoneconnexion.dart';

class Connection extends StatefulWidget {
  const Connection({super.key});

  @override
  State<Connection> createState() => _ConnectionState();
}

class _ConnectionState extends State<Connection> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool isLoading = false;
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _upsertUserDocIfNeeded(User? user) async {
    if (user == null) return;

    final uid = user.uid;
    final email = user.email;
    final displayName = user.displayName;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final doc = await userRef.get();

    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Aucun profil trouvé. Veuillez vous inscrire.",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // Mise à jour (sans écraser les données existantes)
      await userRef.update({
        "email": email,
        "name": displayName ?? doc.data()!["name"],
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyPinPage(
            onSuccess: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => Acceuil()),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final googleCred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        googleCred,
      );

      // Met à jour Firestore
      await _upsertUserDocIfNeeded(userCred.user);
    } catch (e) {
      showSnack("Erreur Google Sign-In: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void login(BuildContext context) async {
    setState(() => isLoading = true);

    if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      setState(() => isLoading = false);
      showSnack("Veuillez remplir tous les champs");
      return;
    }

    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    try {
      // Connexion Email + Password
      UserCredential emailUser = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Mettre à jour Firestore si tu veux
      await _upsertUserDocIfNeeded(emailUser.user);

      if (!mounted) return;
      setState(() => isLoading = false);
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);

      if (e.code == 'wrong-password') {
        showSnack(
          "Mot de passe incorrect. Utilisez 'Mot de passe oublié' si nécessaire.",
        );
        return;
      }
      if (e.code == 'user-not-found') {
        // Peut être que l'utilisateur s'est inscrit avec Google ou téléphone
        showSnack(
          "Aucun compte trouvé avec cet email. Connectez-vous avec Google ou téléphone, ou inscrivez-vous.",
        );
        return;
      }

      showSnack("Erreur: ${e.message}");
    } catch (e) {
      setState(() => isLoading = false);
      showSnack("Erreur: $e");
    }
  }

  void showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF5E3B1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.greenAccent : Colors.redAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // TOP BAR
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),

      // BODY
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5E3B1E)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // HEADER
                      Text(
                        "Connexion PayCash",
                        style: GoogleFonts.poppins(
                          fontSize: 40,
                          color: const Color(0xFF5E3B1E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 35),

                      // EMAIL FIELD
                      TextField(
                        controller: emailCtrl,
                        cursorColor: const Color(0xFF5E3B1E),
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF5E3B1E),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFD9B76F),
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.email,
                            color: Color(0xFF5E3B1E),
                          ),
                        ),
                        style: const TextStyle(color: Colors.black),
                      ),

                      const SizedBox(height: 25),

                      // PASSWORD FIELD
                      TextField(
                        controller: passwordCtrl,
                        obscureText: _obscurePassword,
                        cursorColor: const Color(0xFF5E3B1E),
                        decoration: InputDecoration(
                          labelText: "Mot de passe",
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF5E3B1E),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFD9B76F),
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF5E3B1E),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF5E3B1E),
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            final email = emailCtrl.text.trim();

                            if (email.isEmpty) {
                              showSnack("Veuillez entrer votre email.");
                              return;
                            }

                            FirebaseAuth.instance
                                .sendPasswordResetEmail(email: email)
                                .then((_) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Email envoyé"),
                                      content: const Text(
                                        "Un lien de réinitialisation a été envoyé dans votre boîte mail.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text("OK"),
                                        ),
                                      ],
                                    ),
                                  );
                                });
                          },
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Mot de passe oublié ?",
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF854616),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // LOGIN BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () => login(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5E3B1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            "Se connecter",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),
                      const Divider(color: Color(0xFF5E3B1E), thickness: 1.1),
                      const SizedBox(height: 20),
                      Text(
                        "Ou connectez-vous avec",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF5E3B1E),
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Google
                            GestureDetector(
                              onTap: _loading ? null : _signInWithGoogle,
                              child: Container(
                                width: 120,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: _loading
                                          ? CircularProgressIndicator(
                                              color: Color(0xFFDB4437),
                                            )
                                          : FaIcon(
                                              FontAwesomeIcons.google,
                                              color: Color(0xFFDB4437),
                                              // rouge Google officiel
                                              size: 40,
                                            ),
                                      onPressed: _loading
                                          ? null
                                          : _signInWithGoogle,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      "Google",
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Téléphone
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhoneConnexion(),
                                  ),
                                );
                              },
                              child: Container(
                                width: 120,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.phone,
                                        color: Color(0xFF34A853),
                                        // vert téléphone style Google
                                        size: 40,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PhoneConnexion(),
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      "Téléphone",
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Sign Up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Connection(),
                                ),
                              );
                            },
                            child: Text(
                              "Nouveau sur PayCash ? ",
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Inscription(),
                                ),
                              );
                            },
                            child: Text(
                              "Inscrivez-vous",
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFD9B76F),
                                fontWeight: FontWeight.w600,
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
}
