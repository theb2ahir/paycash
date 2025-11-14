import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paycash/auth/connection.dart';
import 'package:paycash/pages/profile.dart';
import 'package:google_fonts/google_fonts.dart';

import '../notification_service.dart';
import '../transactions/retrait.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    try {
      final uid = _auth.currentUser!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur récupération utilisateur : $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Déconnecter",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Connection()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = userData?['name'] ?? 'Utilisateur';
    final email = userData?['email'] ?? 'email inconnu';
    final phone = userData?['phone'] ?? 'Non renseigné';
    final status = userData?['status'] ?? 'Inconnu';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E342E),
        centerTitle: true,
        elevation: 2,
        title: Text(
          "Profil & Paramètres",
          style: GoogleFonts.poppins(
            color: const Color(0xFFD7B98E),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- En-tête profil ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4E342E), Color(0xFF6D4C41)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFD7B98E),
                    child: Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD7B98E),
                      foregroundColor: Colors.brown[900],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Modifier le profil"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Section Infos personnelles ---
            buildSectionTitle("Informations personnelles"),
            buildInfoTile(Icons.phone, "Téléphone", phone, Colors.green),
            buildInfoTile(Icons.verified_user, "Statut du compte", status, Colors.blue),
            GestureDetector(
                onTap: () {
                  logout();
                },
                child: buildInfoTile(Icons.logout, "Déconnexion", "Se déconnecter", Colors.red)),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WithdrawPage()),
                );
              },
                child: buildInfoTile(Icons.money, "Faire un retrait", "Retirer de mon compte", Colors.teal)),

            const SizedBox(height: 24),

            // --- Section Sécurité ---
            buildSectionTitle("Sécurité"),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.orange),
              title: const Text("Changer le mot de passe"),
              onTap: () async {
                try {
                  await _auth.sendPasswordResetEmail(email: email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Un lien de réinitialisation a été envoyé à votre e-mail."),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur : $e")),
                  );
                }
              },
            ),

            const SizedBox(height: 8),

            // --- Section Aide / Support ---
            buildSectionTitle("Aide & Support"),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.purple),
              title: const Text("Contacter le support"),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text("Support client"),
                    content: const Text(
                        "📞 Contactez-nous à supportpaycash@gmail.com ou via WhatsApp au +228 92 34 96 98"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Fermer"),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Divider(thickness: 1.2),

            // --- Déconnexion ---
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                "Se déconnecter",
                style: GoogleFonts.poppins(
                    color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: logout,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Widgets utilitaires ----------

  Widget buildSectionTitle(String title) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.brown[800],
        ),
      ),
    );
  }

  Widget buildInfoTile(IconData icon, String title, String subtitle, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 13)),
      ),
    );
  }
}
