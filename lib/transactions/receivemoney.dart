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
        .where('scanned_user_id', isEqualTo: idUnique)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final data = doc.data();
            senderDocId = doc.id;
            final senderId = data['scanner_user_id'];

            if (senderId != null && senderId != idUnique) {
              // Charger infos de l'envoyeur
              await _loadScannerData(senderId);

              // 🔔 Notification scan QR
              if (data['notified_scan'] == true &&
                  (data['notified_scan_sent'] == null ||
                      data['notified_scan_sent'] == false)) {
                await NotificationService.showNotification(
                  title: "📷 QR Code scanné",
                  body: "${senderName} a scanné votre QR code.",
                );

                // Marquer que la notif de scan a été envoyée
                await scaneventsref.doc(senderDocId).update({
                  'notified_scan_sent': true,
                });
              }

              // 🔔 Notification paiement après transaction
              if (data['notified_payment'] == true &&
                  (data['notified_payment_sent'] == null ||
                      data['notified_payment_sent'] == false)) {
                await NotificationService.showNotification(
                  title: "💰 Paiement reçu",
                  body:
                      "${senderName} a envoyé ${data['montant']?.toStringAsFixed(0) ?? ''} FCFA",
                );

                // Marquer que la notif de paiement a été envoyée
                await scaneventsref.doc(senderDocId).update({
                  'notified_payment_sent': true,
                });
              }
            }
          } else {
            // Reset affichage si plus de scan
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
      final document = await _firestore
          .collection('users')
          .doc(extractInternalId(senderId))
          .get();
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
                          Icon(
                            Icons.qr_code_2,
                            size: 70,
                            color: Color(0xFF8B5E3C),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "QR code non généré",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF5A3E2B),
                            ),
                          ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Détails de l'envoyeur",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade700,
                            fontSize: 17,
                          ),
                        ),

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3E2723),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              final uid =
                                  FirebaseAuth.instance.currentUser!.uid;
                              final friendId = senderIdUnique;

                              if (friendId == null) return;

                              try {
                                // 1️⃣ Ajouter à tes amis si ce n'est pas déjà fait
                                final friendsRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('friends');

                                final existing = await friendsRef
                                    .where('friend', isEqualTo: friendId)
                                    .get();

                                if (existing.docs.isEmpty) {
                                  await friendsRef.add({'friend': friendId});

                                  // 2️⃣ Envoyer une demande côté ami
                                  final friendQuery = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .where('idUnique', isEqualTo: friendId)
                                      .limit(1)
                                      .get();

                                  if (friendQuery.docs.isNotEmpty) {
                                    final sender = _auth.currentUser!;
                                    final senderDocRef = _firestore
                                        .collection('users')
                                        .doc(sender.uid);
                                    final senderSnapshot = await senderDocRef
                                        .get();
                                    final senderuniquedmanid =
                                        senderSnapshot['idUnique'] ?? 0;
                                    final friendDocId =
                                        friendQuery.docs.first.id;
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(friendDocId)
                                        .collection('friendrequest')
                                        .add({'request': senderuniquedmanid});
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(
                                        0xFF8B4513,
                                      ), // marron
                                      content: Text(
                                        "$senderName ajouté(e) à vos ami(e)s et la demande a été envoyée",
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.orange,
                                      content: Text(
                                        "$senderName est déjà dans vos ami(e)s",
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text(
                                      "Erreur: $e",
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
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
