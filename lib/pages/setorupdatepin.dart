import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class SetOrUpdatePinPage extends StatefulWidget {
  final bool pinExists;

  const SetOrUpdatePinPage({super.key, required this.pinExists});

  @override
  State<SetOrUpdatePinPage> createState() => _SetOrUpdatePinPageState();
}

class _SetOrUpdatePinPageState extends State<SetOrUpdatePinPage> {
  String pin = "";
  String confirmPin = "";
  bool obscurePin = true;
  bool obscureConfirm = true;

  Color get pinColor {
    if (pin.length < 4) return Colors.red;
    if (pin.length < 6) return Colors.orange;
    return Colors.green;
  }

  bool get isValid => pin.length == 6 && pin == confirmPin;

  void _savePin() async {
    // 🔐 HASH DU PIN
    final pinHash = BCrypt.hashpw(pin, BCrypt.gensalt());

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('users').doc(uid).update({
        'pin': pinHash,
        'pinSet': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.pinExists
                ? "Le code PIN a été mis à jour avec succès."
                : "Le code PIN a été créé avec succès.",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sauvegarde du PIN : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6D4C41),
        title: Text(
          widget.pinExists ? "Modifier le code PIN" : "Créer un code PIN",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 30,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.pinExists
                    ? "Pour votre sécurité, définissez un nouveau code PIN."
                    : "Créez un code PIN pour sécuriser vos transactions.",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4E342E),
                ),
              ),
              const SizedBox(height: 30),

              // 🔢 PIN
              // 🔢 PIN
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
                  fieldHeight: 48,
                  fieldWidth: 44,
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

              const SizedBox(height: 20),

              Text(
                "Confirmez votre code PIN",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4E342E),
                ),
              ),

              const SizedBox(height: 23),

              // 🔁 CONFIRMATION
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
                  fieldHeight: 48,
                  fieldWidth: 44,
                  inactiveFillColor: Colors.white,
                  selectedFillColor: Colors.white,
                  activeFillColor: Colors.white,
                  inactiveColor: confirmPin.isEmpty
                      ? Colors.grey
                      : (confirmPin == pin ? Colors.green : Colors.red),
                  selectedColor: const Color(0xFF6D4C41),
                  activeColor: confirmPin.isEmpty
                      ? Colors.grey
                      : (confirmPin == pin ? Colors.green : Colors.red),
                ),
                onChanged: (value) {
                  setState(() => confirmPin = value);
                },
              ),

              const SizedBox(height: 24),

              Text(
                pin.length < 4
                    ? "PIN trop court"
                    : pin.length < 6
                    ? "Continuez jusqu'à 6 chiffres"
                    : pin == confirmPin
                    ? "PIN valide"
                    : "Les PIN ne correspondent pas",
                style: TextStyle(
                  color: isValid ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 32),
              // ✅ BOUTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid
                        ? const Color(0xFF6D4C41)
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isValid ? _savePin : null,
                  child: Text(
                    widget.pinExists ? "Mettre à jour le PIN" : "Créer le PIN",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
