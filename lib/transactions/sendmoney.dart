// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
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
  int notifId =
      DateTime.now().millisecondsSinceEpoch ~/ 1000; // secondes depuis 1970
  TextEditingController phoneController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  Map<String, dynamic>? searchedUserData;

  Map<String, dynamic>? recipientData;
  bool _isSending = false;
  String enteredPin = "";

  Future<String> getUserPin() async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();

    final data = userDoc.data()!;
    return data['pin']; // ⚠️ hash, pas pin clair
  }

  @override
  void initState() {
    super.initState();
    getUserPin();
  }

  Future<void> _searchUser() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) return;

    Query query = _firestore.collection('users');

    if (phone.isNotEmpty) query = query.where('phone', isEqualTo: phone);

    final querySnapshot = await query.limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      setState(() => searchedUserData = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("votre ami(e) n'a pas paycash")),
      );
      return;
    }

    setState(() {
      searchedUserData =
          querySnapshot.docs.first.data() as Map<String, dynamic>?;
    });
  }

  Future<void> _sendToSearchedUser() async {
    if (searchedUserData == null) return;
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) return;

    final sender = _auth.currentUser!;
    final senderDocRef = _firestore.collection('users').doc(sender.uid);
    final senderSnapshot = await senderDocRef.get();
    final senderBalance = senderSnapshot['balance'] ?? 0;

    if (senderBalance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Solde insuffisant: ${senderBalance.toStringAsFixed(0)} FCFA",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final recipientQuery = await _firestore
        .collection('users')
        .where('idUnique', isEqualTo: searchedUserData!['idUnique'])
        .limit(1)
        .get();

    if (recipientQuery.docs.isEmpty) return;

    final recipientDocRef = recipientQuery.docs.first.reference;
    final recipientBalance = recipientQuery.docs.first['balance'] ?? 0;
    final senderIdUnique = senderSnapshot['idUnique'];

    await _firestore.runTransaction((transaction) async {
      transaction.set(_firestore.collection('transactions').doc(), {
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'from': senderIdUnique,
        'to': searchedUserData!['idUnique'],
        'status': "terminée",
        'type': "transfert",
      });

      transaction.update(recipientDocRef, {
        'balance': recipientBalance + amount,
      });
      transaction.update(senderDocRef, {'balance': senderBalance - amount});
    });

    NotificationService.showNotification(
      title: "💸 Paiement envoyé",
      body:
          "Vous avez envoyé ${amount.toStringAsFixed(0)} FCFA à ${searchedUserData!['name']}",
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "✅ Transfert de ${amount.toStringAsFixed(0)} FCFA envoyé à ${searchedUserData!['name']}",
        ),
      ),
    );

    setState(() {
      searchedUserData = null;
      amountController.clear();
      phoneController.clear();
    });
  }

  Future<void> createTransaction() async {
    if (recipientData == null) return;

    final amount = recipientData!['montant']?.toDouble();
    if (amount == null || amount <= 0) return;

    setState(() => _isSending = true);

    try {
      // Timeout global : 10 secondes pour toute la transaction
      await _firestore
          .runTransaction((transaction) async {
            final sender = _auth.currentUser!;
            final senderDocRef = _firestore.collection('users').doc(sender.uid);
            final senderSnapshot = await transaction.get(senderDocRef);
            final senderBalance = senderSnapshot['balance'] ?? 0;

            if (senderBalance < amount) {
              throw Exception(
                "❌ Solde insuffisant : ${senderBalance.toStringAsFixed(0)} FCFA",
              );
            }

            final recipientQuery = await _firestore
                .collection('users')
                .where('idUnique', isEqualTo: recipientData!['idUnique'])
                .limit(1)
                .get();

            if (recipientQuery.docs.isEmpty) {
              throw Exception("❌ Destinataire introuvable");
            }

            final recipientDocRef = recipientQuery.docs.first.reference;
            final recipientSnapshot = recipientQuery.docs.first.data();
            final recipientBalance = recipientSnapshot['balance'] ?? 0;
            final senderIdUnique = senderSnapshot['idUnique'];

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
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception("⏱️ Temps dépassé. Réessayez plus tard.");
            },
          );

      // Notification et snackbar après transaction réussie
      NotificationService.showNotification(
        title: "💸 Paiement envoyé",
        body:
            "Vous avez envoyé ${amount.toStringAsFixed(0)} FCFA à ${recipientData!['name']}",
      );

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
    } catch (e) {
      // SnackBar d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            e.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      setState(() => _isSending = false);
    }
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
        scrollDirection: Axis.vertical,
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
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        Color pinColor;
                        if (enteredPin.length < 4) {
                          pinColor = Colors.red;
                        } else if (enteredPin.length < 6) {
                          pinColor = Colors.orange;
                        } else {
                          pinColor = Colors.green;
                        }

                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Entrez votre code PIN de sécurité",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 22,
                                  color: const Color(0xFF4E342E),
                                ),
                              ),
                              const SizedBox(height: 18),

                              /// 🔐 PIN CODE FIELD
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
                                  fieldHeight: 45,
                                  fieldWidth: 43,
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
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Annuler",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),

                            /// ✅ BOUTON VERIFIER
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: enteredPin.length == 6
                                    ? Colors.green
                                    : const Color(0xFF6D4C41),
                              ),
                              onPressed: enteredPin.length == 6
                                  ? () async {
                                      final String pin = await getUserPin();
                                      final bool isValidPin = BCrypt.checkpw(
                                        enteredPin,
                                        pin, // pinHash stocké depuis Firestore
                                      );

                                      if (isValidPin) {
                                        Navigator.pop(context);

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                ),
                                                SizedBox(width: 8),
                                                Text("Code PIN correct"),
                                              ],
                                            ),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => QRScannerPage(
                                              onScan: (data) {
                                                setState(
                                                  () => recipientData = data,
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  Icons.error,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 8),
                                                Text("Code PIN incorrect"),
                                              ],
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );

                                        setState(() => enteredPin = "");
                                        Navigator.pop(context);
                                      }
                                    }
                                  : null,
                              child: const Text(
                                "Vérifier",
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Détails du destinataire",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade700,
                            fontSize: 17,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final uid = FirebaseAuth.instance.currentUser!.uid;
                            final friendId = recipientData?['idUnique'];

                            if (friendId == null) return;

                            try {
                              final friendsRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('friends');

                              // Vérifier si déjà ami
                              final existing = await friendsRef
                                  .where('friend', isEqualTo: friendId)
                                  .get();

                              if (existing.docs.isEmpty) {
                                // 1️⃣ Ajouter à vos amis
                                await friendsRef.add({'friend': friendId});

                                // 2️⃣ Envoyer la demande à l'autre utilisateur
                                final requestRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .where('idUnique', isEqualTo: friendId)
                                    .limit(1)
                                    .get();

                                if ((await requestRef).docs.isNotEmpty) {
                                  final me = _auth.currentUser!;
                                  final senderDocRef = _firestore
                                      .collection('users')
                                      .doc(me.uid);
                                  final senderSnapshot = await senderDocRef
                                      .get();
                                  final senderidunique =
                                      senderSnapshot['idUnique'] ?? 0;
                                  final friendDocId =
                                      (await requestRef).docs.first.id;
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(friendDocId)
                                      .collection('friendrequest')
                                      .add({'request': senderidunique});
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF8B4513),
                                    // marron
                                    content: Text(
                                      "${recipientData!['name']} ajouté(e) et une demande envoyée",
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
                                      "${recipientData!['name']} est déjà dans vos ami(e)s",
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
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                            size: 28,
                          ),
                          tooltip: "Ajouter et envoyer demande",
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
                            recipientData!['name'][0].toUpperCase(),
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
                              recipientData!['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 23,
                              ),
                            ),
                            Text(
                              recipientData!['phone'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Divider(thickness: 0.8),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Montant :",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
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
            const SizedBox(height: 33),
            Row(
              children: [
                Text(
                  "Rechercher un(e) ami(e)",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: Colors.brown.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  cursorColor: const Color(0xFF5E3B1E),
                  decoration: InputDecoration(
                    labelText: "Numéro de téléphone",
                    hintText: "E.g: +22899999999",
                    labelStyle: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
                    prefixIcon: const Icon(
                      Icons.phone,
                      color: Color(0xFF5E3B1E),
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _searchUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E3B1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      "Rechercher",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Si l'utilisateur est trouvé → afficher ses infos et demander le montant
                if (searchedUserData != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.brown.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                              "Nom : ${searchedUserData!['name']}",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Color(0xFF3E2723),
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            // BOUTON AJOUTER AMI
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF3E2723),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  final uid =
                                      FirebaseAuth.instance.currentUser!.uid;
                                  final friendId =
                                      searchedUserData?['idUnique'];

                                  if (friendId == null) return;

                                  try {
                                    // 1️⃣ Ajouter à tes amis si ce n'est pas déjà fait
                                    final friendsRef = FirebaseFirestore
                                        .instance
                                        .collection('users')
                                        .doc(uid)
                                        .collection('friends');

                                    final existing = await friendsRef
                                        .where('friend', isEqualTo: friendId)
                                        .get();

                                    if (existing.docs.isEmpty) {
                                      await friendsRef.add({
                                        'friend': friendId,
                                      });

                                      // 2️⃣ Envoyer une demande côté ami
                                      final friendQuery =
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .where(
                                                'idUnique',
                                                isEqualTo: friendId,
                                              )
                                              .limit(1)
                                              .get();

                                      if (friendQuery.docs.isNotEmpty) {
                                        final sender = _auth.currentUser!;
                                        final senderDocRef = _firestore
                                            .collection('users')
                                            .doc(sender.uid);
                                        final senderSnapshot =
                                            await senderDocRef.get();
                                        final senderuniquedmanid =
                                            senderSnapshot['idUnique'] ?? 0;
                                        final friendDocId =
                                            friendQuery.docs.first.id;
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(friendDocId)
                                            .collection('friendrequest')
                                            .add({
                                              'request': senderuniquedmanid,
                                            });
                                      }

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(
                                            0xFF8B4513,
                                          ), // marron
                                          content: Text(
                                            "${searchedUserData!['name']} ajouté(e) à vos ami(e)s et la demande a été envoyée",
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.orange,
                                          content: Text(
                                            "${searchedUserData!['name']} est déjà dans vos ami(e)s",
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

                        const SizedBox(height: 6),
                        Text(
                          "Numéro : ${searchedUserData!['phone']}",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        Text(
                          "Email : ${searchedUserData!['email']}",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // CHAMP MONTANT
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Montant à envoyer",
                            labelStyle: GoogleFonts.poppins(
                              color: Color(0xFF3E2723),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: const Icon(
                              Icons.monetization_on,
                              color: Colors.brown,
                            ),
                            filled: true,
                            fillColor: Colors.brown.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.brown),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.brown,
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // BOUTON ENVOYER
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) {
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      Color pinColor;
                                      if (enteredPin.length < 4) {
                                        pinColor = Colors.red;
                                      } else if (enteredPin.length < 6) {
                                        pinColor = Colors.orange;
                                      } else {
                                        pinColor = Colors.green;
                                      }

                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "Entrez votre code PIN de sécurité",
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 22,
                                                color: const Color(0xFF4E342E),
                                              ),
                                            ),
                                            const SizedBox(height: 18),

                                            /// 🔐 PIN CODE FIELD
                                            PinCodeTextField(
                                              appContext: context,
                                              length: 6,
                                              obscureText: true,
                                              obscuringCharacter: "●",
                                              keyboardType:
                                                  TextInputType.number,
                                              animationType: AnimationType.fade,
                                              enableActiveFill: true,
                                              pinTheme: PinTheme(
                                                shape: PinCodeFieldShape.box,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                fieldHeight: 45,
                                                fieldWidth: 43,
                                                inactiveFillColor: Colors.white,
                                                selectedFillColor: Colors.white,
                                                activeFillColor: Colors.white,
                                                inactiveColor: pinColor,
                                                selectedColor: const Color(
                                                  0xFF6D4C41,
                                                ),
                                                activeColor: pinColor,
                                              ),
                                              onChanged: (value) {
                                                setState(
                                                  () => enteredPin = value,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              "Annuler",
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),

                                          /// ✅ BOUTON VERIFIER
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  enteredPin.length == 6
                                                  ? Colors.green
                                                  : const Color(0xFF6D4C41),
                                            ),
                                            onPressed: enteredPin.length == 6
                                                ? () async {
                                                    final String pin =
                                                        await getUserPin();
                                                    final bool
                                                    isValidPin = BCrypt.checkpw(
                                                      enteredPin,
                                                      pin, // pinHash stocké depuis Firestore
                                                    );

                                                    if (isValidPin) {
                                                      Navigator.pop(context);

                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .check_circle,
                                                                color: Colors
                                                                    .green,
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                "Code PIN correct",
                                                              ),
                                                            ],
                                                          ),
                                                          duration: Duration(
                                                            seconds: 1,
                                                          ),
                                                        ),
                                                      );
                                                      // Procéder à l'envoi d'argent
                                                      _sendToSearchedUser();
                                                    } else {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.error,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                "Code PIN incorrect",
                                                              ),
                                                            ],
                                                          ),
                                                          duration: Duration(
                                                            seconds: 2,
                                                          ),
                                                        ),
                                                      );

                                                      setState(
                                                        () => enteredPin = "",
                                                      );
                                                      Navigator.pop(context);
                                                    }
                                                  }
                                                : null,
                                            child: const Text(
                                              "Vérifier",
                                              style: TextStyle(
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3E2723),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              "Envoyer",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
      final scannerSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!scannerSnapshot.exists) {
        throw "Impossible de trouver le compte utilisateur.";
      }

      final scannerIdUnique = scannerSnapshot['idUnique'];

      // ------------------------------------------
      //     🔥 Enregistrement du ScanEvent
      // ------------------------------------------
      await _firestore.collection('scanevents').add({
        "scanner_user_id": scannerIdUnique, // Celui qui scanne
        "scanned_user_id": scannedIdUnique,
        "notified_scan": true,
        "notified_payment": false,
        "montant": decoded["montant"],
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
        automaticallyImplyLeading: false,
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
