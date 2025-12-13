import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'facture.dart';

class PaymentSuccessPage extends StatelessWidget {
  final String title;
  final double amount;
  final String operator;
  final String reference;
  final String paymentUrl;

  const PaymentSuccessPage({
    super.key,
    required this.title,
    required this.amount,
    required this.operator,
    required this.reference,
    required this.paymentUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF8B5E3C),
        title: Text(
          "Paiement confirmé",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 100),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "$amount FCFA via $operator",
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                "Référence : $reference",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FacturePage(
                        url: paymentUrl,
                        token: reference,
                        amount: amount,
                        operator: operator,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5E3C),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Voir la facture",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Retour à l'accueil",
                  style: TextStyle(fontSize: 18, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
