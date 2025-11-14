import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../notification_service.dart';

class SendMoney extends StatefulWidget {
  const SendMoney({super.key});

  @override
  State<SendMoney> createState() => _SendMoneyState();
}

class _SendMoneyState extends State<SendMoney> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000; // secondes depuis 1970

  Map<String, dynamic>? recipientData;
  bool _isSending = false;

  Future<void> createTransaction() async {
    if (recipientData == null) return;

    final amount = recipientData!['montant']?.toDouble();
    if (amount == null || amount <= 0) return;

    setState(() => _isSending = true);

    final sender = _auth.currentUser!;
    final senderDocRef = _firestore.collection('users').doc(sender.uid);
    final scaneventsref = _firestore.collection('scanevents');
    final senderSnapshot = await senderDocRef.get();
    final senderBalance = senderSnapshot['balance'] ?? 0;

    if (senderBalance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            "❌ Solde insuffisant : ${senderBalance.toStringAsFixed(0)} FCFA",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      setState(() => _isSending = false);
      return;
    }

    final recipientQuery = await _firestore
        .collection('users')
        .where('idUnique', isEqualTo: recipientData!['idUnique'])
        .limit(1)
        .get();

    if (recipientQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("❌ Destinataire introuvable"),
        ),
      );
      setState(() => _isSending = false);
      return;
    }

    final recipientDocRef = recipientQuery.docs.first.reference;
    final recipientSnapshot = recipientQuery.docs.first.data();
    final recipientBalance = recipientSnapshot['balance'] ?? 0;
    final senderIdUnique = senderSnapshot['idUnique'];

    await _firestore.runTransaction((transaction) async {
      transaction.set(_firestore.collection('transactions').doc(), {
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'from': senderIdUnique,
        'to': recipientData!['idUnique'],
        'status': "terminée",
        'type': "transfert",
      });

      transaction.update(recipientDocRef, {
        'balance': recipientBalance + amount,
      });

      transaction.update(senderDocRef, {
        'balance': senderBalance - amount,
      });

      scaneventsref.add({
        "scanned_user_id" : recipientData!['idUnique'],
        "scanner_user_id" : senderIdUnique,
        "montant" : amount,
        "timestamp" : FieldValue.serverTimestamp()
      });

      NotificationService.showNotification(
        title: "💸 Paiement envoyé",
        body: "Vous avez envoyé ${amount.toStringAsFixed(0)} FCFA à ${recipientData!['name']}",
      );


    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB8860B),
        content: Text(
          "✅ Transfert de ${amount.toStringAsFixed(0)} FCFA envoyé à ${recipientData!['name']}",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );

    setState(() {
      recipientData = null;
      _isSending = false;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3E2723),
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "Envoyer de l'argent",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              "📷 Cliquez sur l'icône ci-dessous pour scanner le QR code du destinataire , ensuite faites lui verifier",
              style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.brown.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),

            // --- Bouton Scan ---
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRScannerPage(
                    onScan: (data) {
                      setState(() => recipientData = data);
                    },
                  ),
                ),
              ),
              child: CircleAvatar(
                radius: 65,
                backgroundColor: const Color(0xFFFFEFD5),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 70,
                  color: Color(0xFFB8860B),
                ),
              ),
            ),
            const SizedBox(height: 35),

            // --- Détails du destinataire ---
            if (recipientData != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Détails du destinataire",
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
                            recipientData!['name'][0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipientData!['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              recipientData!['phone'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Divider(thickness: 0.8),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Montant :",
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(
                          "${recipientData!['montant'] ?? ''} FCFA",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF3E2723),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),


            const SizedBox(height: 40),

            // --- Bouton Envoyer ---
            if (recipientData != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB8860B), Color(0xFF3E2723)],
                  ),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSending ? null : createTransaction,
                  icon: _isSending
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(
                    _isSending ? "Envoi en cours..." : "Envoyer",
                    style: const TextStyle(
                      fontSize: 19,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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


class QRScannerPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onScan;

  const QRScannerPage({super.key, required this.onScan});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isProcessing = false; // 🔥 Empêche double scan

  // -----------------------------
  //   🔥 Fonction principale
  // -----------------------------
  Future<void> _handleScan(String rawData) async {
    if (_isProcessing) return; // Empêche le double tir
    _isProcessing = true;

    try {
      // Décoder les données du QR
      final decoded = jsonDecode(rawData);

      if (!decoded.containsKey("idUnique")) {
        throw "QR code invalide : idUnique manquant";
      }

      final scannedIdUnique = decoded["idUnique"];
      final currentUser = _auth.currentUser!;

      // 🔥 Récupération des infos du scanneur (l’utilisateur connecté)
      final scannerSnapshot =
      await _firestore.collection('users').doc(currentUser.uid).get();

      if (!scannerSnapshot.exists) {
        throw "Impossible de trouver le compte utilisateur.";
      }

      final scannerIdUnique = scannerSnapshot['idUnique'];

      // ------------------------------------------
      //     🔥 Enregistrement du ScanEvent
      // ------------------------------------------
      await _firestore.collection('scanevents').add({
        "scanner_user_id": scannerIdUnique, // Celui qui scanne
        "scanned_user_id": scannedIdUnique, // Celui qui a été scanné
        "timestamp": FieldValue.serverTimestamp(),
      });

      // 🔥 SendMoney reçoit les infos scannées
      widget.onScan(decoded);

      // Pause caméra + fermeture
      controller?.pauseCamera();
      Navigator.pop(context);

    } catch (e) {
      _isProcessing = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("❌ Erreur : $e"),
        ),
      );
    }
  }

  // --------------------------------------------------
  @override
  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) async {
      await _handleScan(scanData.code!);
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3E2723),
        title: const Text(
          "Scanner le QR code",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: const Color(0xFFB8860B),
          borderRadius: 12,
          borderLength: 30,
          borderWidth: 8,
          cutOutSize: size.width * 0.8,
        ),
      ),
    );
  }
}
