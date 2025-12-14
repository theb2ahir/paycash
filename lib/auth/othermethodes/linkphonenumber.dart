// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LinkPhonePage extends StatefulWidget {
  const LinkPhonePage({super.key});

  @override
  State<LinkPhonePage> createState() => _LinkPhonePageState();
}

class _LinkPhonePageState extends State<LinkPhonePage> {
  final TextEditingController phoneCtrl = TextEditingController();
  bool loading = false;

  final Color brown = const Color(0xFF8B4513);
  final Color white = Colors.white;

  String cleanPhone(String input) {
    String phone = input.trim().replaceAll(" ", "").toLowerCase();

    if (!phone.startsWith("+228")) {
      if (phone.length == 8) phone = "+228$phone";
      if (phone.startsWith("228") && phone.length == 11) {
        phone = "+$phone";
      }
    }
    return phone;
  }

  Future<void> sendOTP() async {
    final rawPhone = phoneCtrl.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Entrez votre numéro")));
      return;
    }

    final phone = cleanPhone(rawPhone);

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.currentUser!.linkWithCredential(
            credential,
          );

          await FirebaseFirestore.instance
              .collection("users")
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .update({"phone": phone});

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Numéro lié avec succès !")),
          );
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Erreur : ${e.message}")));
        },
        codeSent: (verificationId, token) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LinkPhoneOTP(phone: phone, verificationId: verificationId),
            ),
          );
        },
        codeAutoRetrievalTimeout: (id) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        backgroundColor: white,
        elevation: 0,
        iconTheme: IconThemeData(color: brown),
        title: Text(
          "Lier mon numéro",
          style: GoogleFonts.poppins(color: brown, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Numéro de téléphone",
              style: GoogleFonts.poppins(fontSize: 18, color: brown),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "+228XXXXXXXX",
                hintStyle: TextStyle(color: brown.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: brown, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              style: TextStyle(color: brown),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brown,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: loading ? null : sendOTP,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Recevoir OTP",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkPhoneOTP extends StatefulWidget {
  final String phone;
  final String verificationId;

  const LinkPhoneOTP({
    super.key,
    required this.phone,
    required this.verificationId,
  });

  @override
  State<LinkPhoneOTP> createState() => _LinkPhoneOTPState();
}

class _LinkPhoneOTPState extends State<LinkPhoneOTP> {
  final TextEditingController otpCtrl = TextEditingController();
  bool loading = false;

  final Color brown = const Color(0xFF8B4513);
  final Color white = Colors.white;

  Future<void> verify() async {
    final code = otpCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);

      await FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({"phone": widget.phone});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Numéro lié avec succès !")));

      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur OTP : $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        backgroundColor: white,
        elevation: 0,
        iconTheme: IconThemeData(color: brown),
        title: Text(
          "Code OTP",
          style: GoogleFonts.poppins(color: brown, fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Entrez le code envoyé à ${widget.phone}",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: brown),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Code OTP",
                labelStyle: TextStyle(color: brown),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: brown, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              style: TextStyle(color: brown),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brown,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: loading ? null : verify,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Valider",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
