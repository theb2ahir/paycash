import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../notification_service.dart';

class ReceiveMoney extends StatefulWidget {
  const ReceiveMoney({super.key});

  @override
  State<ReceiveMoney> createState() => _ReceiveMoneyState();
}

class _ReceiveMoneyState extends State<ReceiveMoney> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String name = '';
  String email = '';
  String phone = '';
  String idUnique = '';

  String senderName = '';
  String senderPhone = '';
  String senderIdUnique = '';
  String senderDocId = '';

  double? montant;
  bool _qrGenerated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String extractInternalId(String senderid) {
    final parts = senderid.split('_');
    return parts.length >= 2 ? parts[parts.length - 2] : senderid;
  }

  // 🔄 Charge l’utilisateur connecté
  Future<void> _loadUserData() async {
    try {
      final uid = _auth.currentUser!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          name = data['name'];
          email = data['email'];
          phone = data['phone'];
          idUnique = data['idUnique'];
          _isLoading = false;
        });

        // Une fois l'utilisateur chargé → lancer le listener en temps réel
        _listenToScanInfos();
      }
    } catch (e) {
      debugPrint("Erreur chargement utilisateur: $e");
      setState(() => _isLoading = false);
    }
  }

  // 👂 Listener en temps réel sur scanevents
  void _listenToScanInfos() {
    final scaneventsref = _firestore.collection('scanevents');

    scaneventsref
        .where('scanned_user_id', isEqualTo: idUnique )
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        senderDocId = snapshot.docs.first.id;
        final senderId = data['scanner_user_id'];

        if (senderId != null && senderId != idUnique) {
          await _loadScannerData(senderId);
          await NotificationService.showNotification(
            title: "💰 Paiement reçu",
            body: "${senderName} vous a envoyé ${data['montant']  ?? 'un montant'} FCFA.",
          );
        }
      } else {
        // Si plus de scan → reset l'affichage
        setState(() {
          senderName = '';
          senderPhone = '';
          senderIdUnique = '';
          senderDocId = '';
        });
      }
    });
  }

  // 📩 Charge les informations de l’envoyeur
  Future<void> _loadScannerData(String senderId) async {
    try {
      final document = await _firestore.collection('users').doc(extractInternalId(senderId)).get();
      if (document.exists) {
        final data = document.data()!;
        setState(() {
          senderName = data["name"];
          senderPhone = data["phone"];
          senderIdUnique = data["idUnique"];
        });
      }
    } catch (err) {
      print(err);
    }
  }

  // 🔢 Génère un QR avec montant
  void _generateQr() async {
    final controller = TextEditingController();
    final montantString = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F0E6),
        title: const Text("Montant à recevoir"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: "Entrez le montant",
            prefixIcon: Icon(Icons.monetization_on_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5E3C),
            ),
            child: const Text("Valider", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (montantString != null && montantString.isNotEmpty) {
      setState(() {
        montant = double.tryParse(montantString);
        _qrGenerated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5E3C)),
        ),
      );
    }

    final qrData = jsonEncode({
      "name": name,
      "email": email,
      "phone": phone,
      "idUnique": idUnique,
      "montant": montant ?? 0,
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: const Color(0xFF8B5E3C),
        title: const Text(
          "Recevoir de l'argent",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 23,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              "Générez votre QR code pour recevoir un paiement.\nL’envoyeur pourra le scanner directement.",
              style: GoogleFonts.poppins(
                fontSize: 17,
                color: const Color(0xFF5A3E2B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 35),

            // QR
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 260,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0E6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF8B5E3C), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _qrGenerated
                    ? QrImageView(
                  data: qrData,
                  size: 220,
                  backgroundColor: Colors.white,
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.qr_code_2,
                        size: 70, color: Color(0xFF8B5E3C)),
                    SizedBox(height: 10),
                    Text("QR code non généré",
                        style: TextStyle(
                            fontSize: 16, color: Color(0xFF5A3E2B))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 👤 Bloc envoyeur en temps réel
            if (senderName.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.brown,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Détails de l'envoyeur",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFFB8860B),
                          child: Text(
                            senderName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              senderName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              senderPhone,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    ElevatedButton(
                      onPressed: () async {
                        if (senderDocId.isNotEmpty) {
                          await _firestore
                              .collection('scanevents')
                              .doc(senderDocId)
                              .delete();

                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text(
                        "Quitter la page",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Bouton QR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _generateQr,
                icon: const Icon(Icons.qr_code, color: Colors.white),
                label: Text(
                  _qrGenerated ? "Régénérer QR code" : "Générer QR code",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5E3C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            if (_qrGenerated && montant != null)
              Padding(
                padding: const EdgeInsets.only(top: 15.0),
                child: Text(
                  "Montant : ${montant!.toStringAsFixed(0)} FCFA",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B5E3C),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
