import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../notification_service.dart'; // Assure-toi que ton service est importé

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  Color primaryColor = const Color(0xFF8B4513); // marron
  Color backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();

    // Listener temps réel pour les nouvelles demandes
    firestore
        .collection('users')
        .doc(myUid)
        .collection('friendrequest')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final requesterId = change.doc['request'] as String;

              firestore
                  .collection('users')
                  .where('idUnique', isEqualTo: requesterId)
                  .limit(1)
                  .get()
                  .then((query) {
                    if (query.docs.isNotEmpty) {
                      final requesterName = query.docs.first['name'];

                      NotificationService.showNotification(
                        title: "Nouvelle demande d'ami(e)",
                        body: "$requesterName vous a envoyé une demande",
                      );
                    }
                  });
            }
          }
        });
  }

  Future<List<Map<String, dynamic>>> getFriendRequests() async {
    final snapshot = await firestore
        .collection('users')
        .doc(myUid)
        .collection('friendrequest')
        .get();

    List<Map<String, dynamic>> requests = [];
    for (var doc in snapshot.docs) {
      final requesterId = doc['request'] as String;

      final userQuery = await firestore
          .collection('users')
          .where('idUnique', isEqualTo: requesterId)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        requests.add({
          'docId': doc.id,
          'requesterId': requesterId,
          'name': userQuery.docs.first['name'],
        });
      }
    }
    return requests;
  }

  Future<void> acceptRequest(String docId, String requesterId) async {
    // Ajouter à mes amis
    await firestore.collection('users').doc(myUid).collection('friends').add({
      'friend': requesterId,
    });

    // Supprimer la demande
    await firestore
        .collection('users')
        .doc(myUid)
        .collection('friendrequest')
        .doc(docId)
        .delete();
  }

  Future<void> deleteRequest(String docId) async {
    await firestore
        .collection('users')
        .doc(myUid)
        .collection('friendrequest')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Demandes d'ami(e)s",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: getFriendRequests(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return Center(
              child: Text(
                "Aucune demande pour le moment",
                style: GoogleFonts.poppins(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final name = request['name'];
              final docId = request['docId'];
              final requesterId = request['requesterId'];

              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: primaryColor, width: 1),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        onPressed: () async {
                          await acceptRequest(docId, requesterId);
                          setState(() {});
                        },
                        child: Text(
                          "Accepter",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () async {
                          await deleteRequest(docId);
                          setState(() {});
                        },
                        child: Text(
                          "Supprimer",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
