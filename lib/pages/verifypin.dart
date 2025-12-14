import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:bcrypt/bcrypt.dart';

class VerifyPinPage extends StatefulWidget {
  final VoidCallback onSuccess;

  const VerifyPinPage({super.key, required this.onSuccess});

  @override
  State<VerifyPinPage> createState() => _VerifyPinPageState();
}

class _VerifyPinPageState extends State<VerifyPinPage> {
  String enteredPin = "";
  bool isLoading = false;
  int attempts = 0;
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final firestore = FirebaseFirestore.instance;
  Future<String> getUserPin() async {
    final userDoc = await firestore.collection('users').doc(uid).get();

    final data = userDoc.data()!;
    return data['pin']; // ⚠️ hash, pas pin clair
  }

  @override
  Widget build(BuildContext context) {
    Color pinColor;
    if (enteredPin.length < 4) {
      pinColor = Colors.red;
    } else if (enteredPin.length < 6) {
      pinColor = Colors.orange;
    } else {
      pinColor = Colors.green;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D4C41),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          "Sécurité PayCash",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Entrez votre code PIN de sécurité",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4E342E),
              ),
            ),
            const SizedBox(height: 24),

            /// 🔐 PIN FIELD
            PinCodeTextField(
              appContext: context,
              length: 6,
              obscureText: true,
              obscuringCharacter: "●",
              keyboardType: TextInputType.number,
              animationType: AnimationType.fade,
              enableActiveFill: true,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 50,
                fieldWidth: 45,
                inactiveFillColor: Colors.white,
                selectedFillColor: Colors.white,
                activeFillColor: Colors.white,
                inactiveColor: pinColor,
                selectedColor: const Color(0xFF6D4C41),
                activeColor: pinColor,
              ),
              onChanged: (value) {
                setState(() => enteredPin = value);
              },
            ),

            const SizedBox(height: 12),
            Text(
              enteredPin.length < 4
                  ? "PIN trop court"
                  : enteredPin.length < 6
                  ? "Vérification en cours"
                  : "PIN prêt",
              style: TextStyle(color: pinColor, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 32),

            /// ✅ BOUTON VÉRIFIER
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: enteredPin.length == 6
                      ? Colors.green
                      : const Color(0xFF6D4C41),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: enteredPin.length == 6 && !isLoading
                    ? () async {
                        setState(() => isLoading = true);
                        final pinHash = await getUserPin();
                        final bool isValidPin = BCrypt.checkpw(
                          enteredPin,
                          pinHash,
                        );

                        await Future.delayed(const Duration(milliseconds: 300));

                        if (!mounted) return;

                        if (isValidPin) {
                          widget.onSuccess();
                        } else {
                          attempts++;
                          setState(() {
                            enteredPin = "";
                            isLoading = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Code PIN incorrect"),
                              backgroundColor: Colors.red,
                            ),
                          );

                          if (attempts >= 3) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Trop de tentatives. Réessayez plus tard.",
                                ),
                              ),
                            );
                          }
                        }
                      }
                    : null,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Vérifier",
                        style: TextStyle(color: Colors.black),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
