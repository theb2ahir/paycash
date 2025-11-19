import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  String extractInternalId(String friendIdUnique) {
    final parts = friendIdUnique.split('_');
    return parts.length >= 2 ? parts[parts.length - 2] : friendIdUnique;
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
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF8B4513), size: 28),
            tooltip: "Demandes d'ami(e)s",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendRequestsPage()),
              );
            },
          )
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
                                final TextEditingController amountCtrl =
                                    TextEditingController();

                                final send = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text("Envoyer de l'argent à $name"),
                                    content: TextField(
                                      controller: amountCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: "Montant",
                                        prefixText: "\$ ",
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Annuler"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Envoyer"),
                                      ),
                                    ],
                                  ),
                                );

                                if (send == true &&
                                    amountCtrl.text.isNotEmpty) {
                                  final amount = double.tryParse(
                                    amountCtrl.text.trim(),
                                  );
                                  if (amount == null || amount <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Montant invalide"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    break;
                                  }

                                  try {
                                    final senderRef = firestore
                                        .collection('users')
                                        .doc(uid);
                                    final senderSnap = await senderRef.get();
                                    final senderBalance =
                                        (senderSnap.data()?['balance'] ?? 0)
                                            .toDouble();

                                    if (senderBalance < amount) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Solde insuffisant"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      break;
                                    }

                                    await firestore
                                        .collection("transactions")
                                        .add({
                                          'amount': amount,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                          'from': senderSnap
                                              .data()?['idUnique'],
                                          'to': friendIdUnique,
                                          'status': "terminée",
                                          'type': "transfert",
                                        });

                                    NotificationService.showNotification(
                                      title: "💸 Paiement envoyé",
                                      body:
                                          "Vous avez envoyé ${amount.toStringAsFixed(0)} FCFA à ${friendData['name']}",
                                    );

                                    // 1️⃣ Déduire de l'envoyeur
                                    await senderRef.update({
                                      'balance': senderBalance - amount,
                                    });

                                    // 2️⃣ Ajouter à l'ami
                                    final friendQuery = await firestore
                                        .collection('users')
                                        .where(
                                          'idUnique',
                                          isEqualTo: friendIdUnique,
                                        )
                                        .limit(1)
                                        .get();

                                    if (friendQuery.docs.isNotEmpty) {
                                      final friendDoc = friendQuery.docs.first;
                                      final friendBalance =
                                          (friendDoc.data()['balance'] ?? 0)
                                              .toDouble();

                                      await firestore
                                          .collection('users')
                                          .doc(friendDoc.id)
                                          .update({
                                            'balance': friendBalance + amount,
                                          });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "\$${amount.toStringAsFixed(2)} envoyé à $name !",
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      // Rembourse l'envoyeur si ami introuvable
                                      await senderRef.update({
                                        'balance': senderBalance,
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Utilisateur introuvable",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Erreur: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                                break;
                              case 'chat':
                                final friendId = extractInternalId(friendIdUnique);
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
