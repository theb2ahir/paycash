import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paycash/auth/forgotpassword/forgortpassword.dart';

import '../pages/acceuil.dart';
import 'inscription.dart';

class Connection extends StatefulWidget {
  const Connection({super.key});

  @override
  State<Connection> createState() => _ConnectionState();
}

class _ConnectionState extends State<Connection> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  void login(BuildContext context) async {
    setState(() => isLoading = true);

    if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      setState(() => isLoading = false);
      showSnack("Veuillez remplir tous les champs");
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      showSnack("Connexion réussie", success: true);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Acceuil()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showSnack("Email ou mot de passe incorrect.");
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
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white),
              ),
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
        title: Text(
          "Connexion",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5E3B1E),
          ),
        ),
      ),

      // BODY
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5E3B1E)))
          : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30,),
                    // HEADER
                    Text(
                      "Heureux de te revoir",
                      style: GoogleFonts.poppins(
                        fontSize: 38,
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
                        labelStyle: const TextStyle(color: Color(0xFF5E3B1E)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF5E3B1E)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFD9B76F),
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(Icons.email, color: Color(0xFF5E3B1E)),
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
                        labelStyle: const TextStyle(color: Color(0xFF5E3B1E)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF5E3B1E)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFD9B76F),
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFF5E3B1E)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF5E3B1E),
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
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
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("OK"),
                                  ),
                                ],
                              ),
                            );
                          });
                        },
                        child: TextButton(onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                          );
                        }, child: Text(
                          "Mot de passe oublié ?",
                          style: TextStyle(
                            color: Color(0xFF5E3B1E),
                            decoration: TextDecoration.underline,
                          ),
                        ),)
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
                        child: const Text(
                          "Se connecter",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            
                    const SizedBox(height: 25),
            
                    // Sign Up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(onPressed: (){
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const Connection()),
                          );
                        }, child: Text(
                          "Nouveau sur PayCash ? ",
                          style: TextStyle(color: Colors.black, fontSize: 15),
                        ),),
            
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Inscription()),
                            );
                          },
                          child: const Text(
                            "Inscrivez-vous",
                            style: TextStyle(
                              color: Color(0xFFD9B76F),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
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
