import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:paycash/transactions/paymentsucces.dart';
import 'dart:convert';

import '../notification_service.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  double _currentBalance = 0;
  bool _isProcessing = false;
  String _selectedOperator = 'YAS';
  final String backendUrl = "https://paycash-d2q6.onrender.com";

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        _currentBalance = (doc['balance'] ?? 0).toDouble();
      });
    }
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountController.text);
    final phone = _phoneController.text.trim();

    if (amount == null || amount <= 0 || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Montant ou téléphone invalide")),
      );
      return;
    }

    if (amount > _currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Solde insuffisant : $_currentBalance FCFA")),
      );
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser!;

      final response = await http.post(
        Uri.parse("$backendUrl/withdraw"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'phone': phone,
          'operator': _selectedOperator,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          // 🔹 Mettre à jour Firestore
          final userRef = _firestore.collection('users').doc(user.uid);
          await _firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(userRef);
            final currentBalance = (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;

            transaction.update(userRef, {'balance': currentBalance - amount});

            final transactionRef = _firestore.collection('transactions').doc();
            transaction.set(transactionRef, {
              'amount': amount,
              'from': snapshot.data()?['idUnique'] ?? '',
              'to': phone,
              'type': 'retrait',
              'status': 'terminée',
              'operator': _selectedOperator,
              'createdAt': FieldValue.serverTimestamp(),
            });
          });

          _amountController.clear();
          _phoneController.clear();
          _loadBalance();

          NotificationService.showNotification(
            title: "Retrait réussi",
            body: "Vous avez retiré $amount FCFA vers $phone.",
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentSuccessPage(
                title: "Retrait réussi",
                amount: amount,
                operator: _selectedOperator,
                reference: data['data']['transaction_id'] ?? "",
                paymentUrl: backendUrl, // Retrait simple, peut rester backend
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Échec du retrait : ${data['message'] ?? 'Erreur'}")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur serveur : ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B5E3C),
        title: const Text(
          "Retirer de l'argent",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _balanceCard(),
            const SizedBox(height: 40),
            _operatorSelector(),
            const SizedBox(height: 30),
            _amountField("Montant à retirer"),
            const SizedBox(height: 20),
            _phoneField("Numéro du destinataire"),
            const SizedBox(height: 30),
            _actionButton("Retirer", _withdraw),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F0E6),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
      ],
    ),
    child: Column(
      children: [
        Text(
          "Solde actuel",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5A3E2B),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "$_currentBalance FCFA",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8B5E3C),
          ),
        ),
      ],
    ),
  );

  Widget _operatorSelector() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F0E6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [_chip("YAS"), _chip("MOOV")],
    ),
  );

  Widget _chip(String name) => ChoiceChip(
    label: Text(name),
    selected: _selectedOperator == name,
    selectedColor: const Color(0xFF8B5E3C),
    backgroundColor: Colors.white,
    labelStyle: TextStyle(
      color: _selectedOperator == name ? Colors.white : const Color(0xFF8B5E3C),
      fontWeight: FontWeight.bold,
    ),
    onSelected: (_) => setState(() => _selectedOperator = name),
  );

  Widget _amountField(String label) => TextField(
    controller: _amountController,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.money_off, color: Color(0xFF8B5E3C)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _phoneField(String label) => TextField(
    controller: _phoneController,
    keyboardType: TextInputType.phone,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.phone, color: Color(0xFF8B5E3C)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _actionButton(String label, VoidCallback onPressed) => SizedBox(
    width: double.infinity,
    height: 55,
    child: ElevatedButton(
      onPressed: _isProcessing ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B5E3C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isProcessing
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
        label,
        style: const TextStyle(fontSize: 20, color: Colors.white),
      ),
    ),
  );
}
