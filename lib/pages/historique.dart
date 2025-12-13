import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;




class Historique extends StatefulWidget {
  const Historique({super.key});

  @override
  State<Historique> createState() => _HistoriqueState();
}

class _HistoriqueState extends State<Historique> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? userUniqueId;

  @override
  void initState() {
    super.initState();
    fetchUserUniqueId();
    timeago.setLocaleMessages('fr', timeago.FrMessages());

  }

  String extractInternalId(String fullId) {
    final parts = fullId.split('_');
    return parts.length >= 2 ? parts[parts.length - 2] : fullId;
  }

  Future<void> fetchUserUniqueId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await firestore.collection('users').doc(uid).get();
    final data = doc.data()!;
    final fullId = data['idUnique'] as String;
    final parts = fullId.split('_');
    final internalId = parts.length >= 2 ? parts[parts.length - 2] : fullId;
    setState(() {
      userUniqueId = internalId;
    });
  }

  Future<String> getUserNameById(String idUnique) async {
    if (idUnique.isEmpty) return "Inconnu(e)";
    try {
      final query = await firestore
          .collection('users')
          .where('idUnique', isEqualTo: idUnique)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first['name'] ?? "Inconnu(e)";
      }
      return "Inconnu(e)";
    } catch (_) {
      return "Inconnu(e)";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userUniqueId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E342E),
        centerTitle: true,
        title: Text(
          "Historique des transactions",
          style: GoogleFonts.poppins(
            color: const Color(0xFFD7B98E),
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 4,
        shadowColor: Colors.brown,
      ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('transactions')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
        
            final allTx = snapshot.data!.docs;
            final userTx = allTx.where((doc) {
              final t = doc.data() as Map<String, dynamic>;
              final from = extractInternalId(t['from'] ?? '');
              final to = extractInternalId(t['to'] ?? '');
              return from == userUniqueId || to == userUniqueId;
            }).toList();
        
            if (userTx.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty_rounded,
                        size: 80, color: Colors.brown),
                    const SizedBox(height: 16),
                    Text(
                      "Aucune transaction pour le moment",
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
              itemCount: userTx.length,
              itemBuilder: (context, index) {
                final t = userTx[index].data() as Map<String, dynamic>;
                final fromFull = t['from'] ?? '';
                final toFull = t['to'] ?? '';
                final fromId = extractInternalId(fromFull);
                final toId = extractInternalId(toFull);
                final statut = t['status'] ?? '';
                final amount = t['amount'] ?? 0;
                final type = t['type'] ?? '';
                final createdAt = t['createdAt'] != null
                    ? (t['createdAt'] as Timestamp).toDate()
                    : DateTime.now();
        
                return FutureBuilder<List<String>>(
                  future: Future.wait([
                    getUserNameById(fromFull),
                    getUserNameById(toFull),
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.brown,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2),
                          ],
                        ),
                      );
                    }
        
                    final fromName = snapshot.data![0];
                    final toName = snapshot.data![1];
        
                    String title = "";
                    String subtitle = "";
                    IconData icon;
                    Color color;
        
                    if (type == 'retrait' ||
                        (fromId == userUniqueId && toFull.isEmpty)) {
                      title = "Retrait";
                      subtitle = "Vous avez retiré $amount FCFA";
                      icon = Icons.arrow_downward_rounded;
                      color = Colors.orangeAccent;
                    } else if (type == 'recharge') {
                      title = "recharge";
                      subtitle = "Vous avez rechargé $amount FCFA";
                      icon = Icons.add_circle_outline_rounded;
                      color = Colors.blueAccent;
                    } else if (type == 'transfert') {
                      if (fromId == userUniqueId) {
                        title = "Transfert";
                        subtitle = "À $toName : $amount FCFA";
                        icon = Icons.call_made_rounded;
                        color = Colors.redAccent;
                      } else if (toId == userUniqueId) {
                        title = "Transfert reçu";
                        subtitle = "De $fromName : $amount FCFA";
                        icon = Icons.call_received_rounded;
                        color = Colors.green;
                      } else {
                        title = "Transfert";
                        subtitle = "$amount FCFA";
                        icon = Icons.swap_horiz_rounded;
                        color = Colors.grey;
                      }
                    } else {
                      title = "Transaction";
                      subtitle = "$amount FCFA";
                      icon = Icons.swap_horiz_rounded;
                      color = Colors.grey;
                    }
        
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.brown,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.brown[800],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      statut == "terminée"
                                          ? Icons.check_circle
                                          : statut == "en_attente"
                                          ? Icons.access_time
                                          : Icons.cancel,
                                      color: statut == "terminée"
                                          ? Colors.green
                                          : statut == "en_attente"
                                          ? Colors.orange
                                          : Colors.red,
                                      size: 15,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.brown[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "$amount FCFA",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeago.format(createdAt, locale: 'fr'),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
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
