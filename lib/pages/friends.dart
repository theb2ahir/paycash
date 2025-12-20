// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:paycash/transactions/facture.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../notification_service.dart';
import 'chat.dart';
import 'friendrequest.dart';

class Friends extends StatefulWidget {
  const Friends({super.key});

  @override
  State<Friends> createState() => _FriendsState();
}

class _FriendsState extends State<Friends> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  final String backendUrl = "http://192.168.1.64:3000";

  String username = "";
  String enteredPin = "";
  String pindeclaglob = "";

  Future<void> fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data()!;

    setState(() {
      pindeclaglob = data['pin'] ?? "";
    });
  }

  _verifyPin(name, friendIdUnique) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double dialogWidth = screenWidth > 500
                ? 420
                : screenWidth * 0.9;

            return StatefulBuilder(
              builder: (context, setStateDialog) {
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
                  contentPadding: const EdgeInsets.all(20),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: dialogWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Entrez votre code PIN de sécurité",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: screenWidth < 360 ? 18 : 22,
                              color: const Color(0xFF4E342E),
                            ),
                          ),
                          const SizedBox(height: 18),

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
                              fieldHeight: screenWidth < 360 ? 42 : 48,
                              fieldWidth: screenWidth < 360 ? 38 : 45,
                              inactiveFillColor: Colors.white,
                              selectedFillColor: Colors.white,
                              activeFillColor: Colors.white,
                              inactiveColor: pinColor,
                              selectedColor: const Color(0xFF6D4C41),
                              activeColor: pinColor,
                            ),
                            onChanged: (value) {
                              setStateDialog(() => enteredPin = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Annuler",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: enteredPin.length == 6
                            ? Colors.green
                            : const Color(0xFF6D4C41),
                        minimumSize: const Size(110, 45),
                      ),
                      onPressed: enteredPin.length == 6
                          ? () {
                              final bool isValidPin = BCrypt.checkpw(
                                enteredPin,
                                pindeclaglob,
                              );

                              if (isValidPin) {
                                final snack = ScaffoldMessenger.of(context)
                                    .showSnackBar(
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
                                snack.closed.then((_) {
                                  Navigator.pop(context);
                                  _sendMoney(name, friendIdUnique);
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.error, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text("Code PIN incorrect"),
                                      ],
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );

                                setStateDialog(() => enteredPin = "");
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
    );
  }

  _sendMoney(name, friendIdUnique) async {
    final TextEditingController amountCtrl = TextEditingController();

    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Envoyer de l'argent à $name",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Montant",
            prefixText: "FCFA ",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Envoyer"),
          ),
        ],
      ),
    );

    if (send != true || amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Montant ou téléphone invalide"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Montant invalide"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showLoading(context, text: "Envoi du paiement...");

    try {
      final senderRef = firestore.collection('users').doc(uid);
      final senderSnap = await senderRef.get();
      final senderBalance = (senderSnap.data()?['balance'] ?? 0).toDouble();

      if (senderBalance < amount) {
        Navigator.pop(context); // ⛔ fermer loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Solde insuffisant"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final senderId = extractInternalId(senderSnap.data()?['idUnique'] ?? '');
      final friendId = extractInternalId(friendIdUnique);

      final response = await http.post(
        Uri.parse("$backendUrl/paycashTRANSFERT/transfer"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromUserId': senderId,
          'toUserId': friendId,
          'amount': amount,
        }),
      );

      final data = jsonDecode(response.body);

      Navigator.pop(context); // ✅ fermer loading

      if (response.statusCode == 200 && data['status'] == 'success') {
        await firestore.collection("transactions").add({
          'amount': amount,
          'createdAt': FieldValue.serverTimestamp(),
          'from': senderId,
          'to': friendId,
          'status': "terminée",
          'type': "transfert",
        });

        NotificationService.showNotification(
          title: "💸 Paiement envoyé",
          body: "Vous avez envoyé ${amount.toStringAsFixed(0)} FCFA à $name",
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FacturePage(
              token: data['token'],
              amount: amount,
              operator: "$name _ $username",
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // sécurité
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<String> getUserPin() async {
    final userDoc = await firestore.collection('users').doc(uid).get();

    final data = userDoc.data()!;
    return data['pin']; // ⚠️ hash, pas pin clair
  }

  String extractInternalId(String friendIdUnique) {
    final parts = friendIdUnique.split('_');
    return parts.length >= 2 ? parts[parts.length - 2] : friendIdUnique;
  }

  void showLoading(BuildContext context, {String text = "Traitement..."}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> getFriendData(String idUnique) async {
    if (idUnique.isEmpty) return {};
    try {
      final query = await firestore
          .collection('users')
          .where('idUnique', isEqualTo: idUnique)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<String> getUserNameById() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        setState(() {
          username = doc['name'] ?? "Inconnu(e)";
        });
        return username;
      } else {
        return "Inconnu(e)";
      }
    } catch (e) {
      return "Inconnu(e)";
    }
  }

  @override
  void initState() {
    super.initState();
    getUserNameById();
    fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Ma liste d'ami(e)s",
          style: GoogleFonts.poppins(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Color(0xFF8B4513),
              size: 28,
            ),
            tooltip: "Demandes d'ami(e)s",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendRequestsPage()),
              );
            },
          ),
        ],
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('users')
              .doc(uid)
              .collection("friends")
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allfriends = snapshot.data!.docs;

            if (allfriends.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 80,
                      color: Colors.brown,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Aucun(e) ami(e) pour le moment",
                      style: GoogleFonts.poppins(
                        color: Colors.brown[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: allfriends.length,
              itemBuilder: (context, index) {
                final friendDoc =
                    allfriends[index].data() as Map<String, dynamic>;
                final friendIdUnique =
                    friendDoc["friend"]; // idUnique stocké dans friend

                return FutureBuilder<Map<String, dynamic>>(
                  future: getFriendData(friendIdUnique),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ListTile(title: Text("Chargement..."));
                    }

                    final friendData = snapshot.data!;
                    final name = friendData['name'] ?? "Inconnu(e)";
                    final phone = friendData['phone'] ?? "N/A";

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF8B4513), // marron
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.poppins(
                            color: Colors.brown[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          phone,
                          style: GoogleFonts.poppins(
                            color: Colors.brown[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.brown,
                          ),
                          onSelected: (value) async {
                            switch (value) {
                              case 'delete':
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Supprimer l'ami(e)"),
                                    content: Text(
                                      "Voulez-vous vraiment supprimer $name ?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Annuler"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Supprimer"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  // Supprime l'ami de la sous-collection
                                  await firestore
                                      .collection('users')
                                      .doc(uid)
                                      .collection("friends")
                                      .doc(allfriends[index].id)
                                      .delete();
                                }
                                break;
                              case 'send_money':
                                _verifyPin(name, friendIdUnique);
                                break;

                              case 'chat':
                                final friendId = extractInternalId(
                                  friendIdUnique,
                                );
                                final friendName = friendData['name'];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                      friendId: friendId,
                                      friendName: friendName,
                                    ),
                                  ),
                                );
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Supprimer'),
                            ),
                            const PopupMenuItem(
                              value: 'send_money',
                              child: Text('Envoyer de l\'argent'),
                            ),
                            const PopupMenuItem(
                              value: 'chat',
                              child: Text('Discuter'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
