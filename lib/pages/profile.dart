import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  String name = '';
  String email = '';
  String phone = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = _auth.currentUser!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          name = data['name'] ?? '';
          email = data['email'] ?? '';
          phone = data['phone'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement profil: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final uid = _auth.currentUser!.uid;

      await _firestore.collection('users').doc(uid).update({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB8860B),
          content: Text('✅ Profil mis à jour avec succès'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFB8860B)),
        ),
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF3E2723),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mon profil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ----- Avatar rond -----
              CircleAvatar(
                radius: 45,
                backgroundColor: const Color(0xFFB8860B),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                name.isNotEmpty ? name : "Utilisateur",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 25),

              // ----- Formulaire -----
              _buildInputField(
                label: "Nom complet",
                icon: Icons.person_outline,
                initial: name,
                onChanged: (val) => name = val,
                validator: (val) => val == null || val.isEmpty
                    ? 'Veuillez entrer un nom'
                    : null,
              ),
              const SizedBox(height: 20),

              _buildInputField(
                label: "Adresse e-mail",
                icon: Icons.email_outlined,
                initial: email,
                onChanged: (val) => email = val,
                validator: (val) => val == null || val.isEmpty
                    ? 'Veuillez entrer un email'
                    : (!val.contains('@') ? 'Email invalide' : null),
              ),
              const SizedBox(height: 20),

              _buildInputField(
                label: "Numéro de téléphone",
                icon: Icons.phone_outlined,
                initial: phone,
                keyboardType: TextInputType.phone,
                onChanged: (val) => phone = val,
                validator: (val) => val == null || val.isEmpty
                    ? 'Veuillez entrer un numéro'
                    : null,
              ),
              const SizedBox(height: 30),

              // ----- Bouton enregistrer -----
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB8860B), Color(0xFF3E2723)],
                  ),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isSaving ? "Enregistrement..." : "Enregistrer",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveChanges,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Widget réutilisable pour les champs -----
  Widget _buildInputField({
    required String label,
    required IconData icon,
    required String initial,
    required void Function(String) onChanged,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      initialValue: initial,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFB8860B)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFB8860B), width: 1.8),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFB8860B), width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
