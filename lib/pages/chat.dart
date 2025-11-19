import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../notification_service.dart';

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChatPage({super.key, required this.friendId, required this.friendName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String myId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _controller = TextEditingController();

  bool isFirstLoad = true;

  Color primaryColor = const Color(0xFF8B4513); // marron
  Color backgroundColor = Colors.white;

  late final String conversationID;
  String? lastNotifiedMessageId;

  @override
  void initState() {
    super.initState();
    conversationID = getConversationID(myId, widget.friendId);

    // Crée la conversation si elle n'existe pas
    firestore.collection("conversations").doc(conversationID).set({
      'users': [myId, widget.friendId],
      'lastMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 🔹 Listener global pour notifications
    firestore
        .collection("conversations")
        .doc(conversationID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots()
        .listen((snapshot) {
          if (isFirstLoad) {
            isFirstLoad = false;
            if (snapshot.docs.isNotEmpty) {
              lastNotifiedMessageId = snapshot.docs.last.id;
            }
            return;
          }

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final msg = change.doc.data() as Map<String, dynamic>;

              if (msg['sender'] != myId &&
                  lastNotifiedMessageId != change.doc.id) {
                lastNotifiedMessageId = change.doc.id;

                NotificationService.showNotification(
                  title: widget.friendName,
                  body: msg['text'],
                );
              }
            }
          }
        });
  }

  String getConversationID(String a, String b) {
    return a.hashCode <= b.hashCode ? "${a}_$b" : "${b}_$a";
  }

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Supprimer la conversation",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Voulez-vous vraiment supprimer tous les messages ?",
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              child: Text(
                "Annuler",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(
                "Supprimer",
                style: GoogleFonts.poppins(color: Colors.red),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await deleteEntireConversation();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteEntireConversation() async {
    final messagesRef = firestore
        .collection("conversations")
        .doc(conversationID)
        .collection("messages");

    final messages = await messagesRef.get();

    for (var doc in messages.docs) {
      await doc.reference.delete();
    }

    // Reset conversation metadata
    await firestore.collection("conversations").doc(conversationID).update({
      "lastMessage": "",
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // Optionnel : message toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Conversation supprimée", style: GoogleFonts.poppins()),
        backgroundColor: primaryColor,
      ),
    );

    setState(() {});
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    await firestore
        .collection("conversations")
        .doc(conversationID)
        .collection("messages")
        .add({
          'sender': myId,
          'receiver': widget.friendId,
          'text': text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });

    await firestore.collection("conversations").doc(conversationID).update({
      'lastMessage': text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          widget.friendName,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == "delete_conversation") {
                _showDeleteConversationDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: "delete_conversation",
                child: Text(
                  "Supprimer la conversation",
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firestore
                    .collection("conversations")
                    .doc(conversationID)
                    .collection("messages")
                    .orderBy("timestamp", descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg =
                          messages[index].data() as Map<String, dynamic>;
                      final isMe = msg['sender'] == myId;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isMe ? primaryColor : Colors.brown.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg['text'],
                            style: GoogleFonts.poppins(
                              color: isMe ? Colors.white : Colors.brown,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Écrire un message...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF8B4513)),
                    onPressed: () => sendMessage(_controller.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
