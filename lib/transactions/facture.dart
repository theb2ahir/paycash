// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paycash/pages/acceuil.dart';
import 'package:paycash/pages/homepage.dart';
import 'package:screenshot/screenshot.dart';

class FacturePage extends StatefulWidget {
  final String token;
  final double amount;
  final String operator;

  const FacturePage({
    super.key,
    required this.token,
    required this.amount,
    required this.operator,
  });

  @override
  State<FacturePage> createState() => _FacturePageState();
}

class _FacturePageState extends State<FacturePage> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  String username = "";
  String userphone = "";
  String useremail = "";
  String userIdUnique = "";
  Uint8List? _capturedImage;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  Future<Map<String, String>> _getUserInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    setState(() {
      username = doc['name'] ?? "";
      userphone = doc['phone'] ?? "";
      useremail = doc['email'] ?? "";
      userIdUnique = doc['idUnique'] ?? "";
    });

    return {
      'name': username,
      'phone': userphone,
      'email': useremail,
      'idUnique': userIdUnique,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EE), // blanc cassé
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Facture",
          style: GoogleFonts.poppins(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  "*Sauvegardez la reference de paiement",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// TITRE
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 50,
                              color: Colors.brown[700],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "FACTURE DE PAIEMENT PAYCASH",
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown[800],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                      _infoRow("Nom d'utilisateur", username),

                      _infoRow("Numéro de téléphone", userphone),

                      _infoRow("Email", useremail),

                      // afficher 10 premiers caractères de l'ID unique dans _infoRow
                      _infoRow(
                        "ID utilisateur",
                        userIdUnique.length > 10
                            ? "${userIdUnique.substring(0, 19)}..."
                            : userIdUnique,
                      ),

                      /// LIGNE INFO
                      _infoRow("Opérateur", widget.operator),

                      const Divider(height: 35),

                      /// TOKEN
                      Text(
                        "Référence de paiement",
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.brown[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          widget.token,
                          style: GoogleFonts.robotoMono(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 10, 60, 36),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),
                      Text(
                        "Statut",
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.brown[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          "Transaction réussie",
                          style: GoogleFonts.robotoMono(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 10, 60, 36),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      /// MONTANT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Montant",
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${widget.amount.toStringAsFixed(0)} FCFA",
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown[800],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 35),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                /// BOUTON
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => Acceuil()),
                              );
                            },
                            child: Text(
                              "Terminer",
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              //copier le token dans le clipboard
                              await Clipboard.setData(
                                ClipboardData(text: widget.token),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Référence de paiement copiée dans le presse-papier",
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              "sauvegarder",
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.roboto(color: Colors.black54)),
          Text(value, style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
