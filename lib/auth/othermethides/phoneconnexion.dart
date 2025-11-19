import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class PhoneConnexion extends StatefulWidget {
  const PhoneConnexion({super.key});

  @override
  State<PhoneConnexion> createState() => _PhoneConnexionState();
}

class _PhoneConnexionState extends State<PhoneConnexion> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();

  bool _loading = false;

  final Color _primaryColor = const Color(0xFF8B4513); // Marron
  final Color _backgroundColor = Colors.white;

  // Nettoyage intelligent des numéros
  String cleanPhone(String input) {
    String phone = input.trim().replaceAll(" ", "").toLowerCase();

    // +228 déjà présent
    if (phone.startsWith("+228")) return phone;

    // 09011223 → +2289011223
    if (phone.length == 9 && phone.startsWith("0")) {
      return "+228${phone.substring(1)}";
    }

    // 90112233 → +22890112233
    if (phone.length == 8) {
      return "+228$phone";
    }

    // 22890112233 → +22890112233
    if (phone.startsWith("228") && phone.length == 11) {
      return "+$phone";
    }

    return phone;
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    if (FirebaseAuth.instance.currentUser != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Vous êtes déjà connecté.")));
      return;
    }

    setState(() => _loading = true);

    try {
      final cleaned = cleanPhone(_phoneController.text.trim());

      // Vérifier si un compte existe avec ce numéro
      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("phone", isEqualTo: cleaned)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aucun compte trouvé avec ce numéro."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
        return;
      }

      // ENFIN : on envoie l'OTP avec le NUMÉRO NETTOYÉ
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: cleaned,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Connexion réussie !")));
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Erreur : ${e.message}")));
        },
        codeSent: (verificationId, _) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OTPScreen(
                verificationId: verificationId,
                phone: cleaned,
                primaryColor: _primaryColor,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Connexion",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        iconTheme: IconThemeData(color: _primaryColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Connexion par Numéro",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 40),

                // INPUT PHONE
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: "Numéro de téléphone",
                    labelStyle: TextStyle(color: _primaryColor),
                    hintText: "+22890112233",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(29),
                      borderSide: BorderSide(color: _primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? "Entrez votre numéro" : null,
                ),

                const SizedBox(height: 30),

                // BOUTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: _loading ? null : _sendOTP,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Envoyer le code",
                            style: TextStyle(color: Colors.white, fontSize: 17),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phone;
  final Color primaryColor;

  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.phone,
    required this.primaryColor,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Code OTP incomplet.")));
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Connexion réussie !")));

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur OTP: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Code OTP",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: widget.primaryColor,
          ),
        ),
        iconTheme: IconThemeData(color: widget.primaryColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Un code a été envoyé à :\n${widget.phone}",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(height: 30),

            // INPUT OTP
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: "Code OTP",
                labelStyle: TextStyle(color: widget.primaryColor),
                counterText: "",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(29),
                  borderSide: BorderSide(color: widget.primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.primaryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // BOUTON VALIDER
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: _loading ? null : _verifyOTP,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Valider",
                        style: TextStyle(color: Colors.white, fontSize: 17),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
