// ignore_for_file: use_build_context_synchronously

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:paycash/transactions/paymentsucces.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
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
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  double _currentBalance = 0;
  bool _isProcessing = false;
  String _selectedOperator = 'YAS';
  String enteredPin = "";
  String pindeclaglob = "";
  final String backendUrl = "http://192.168.1.64:3000";

  @override
  void initState() {
    super.initState();
    _loadBalance();
    fetchUserData();
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

  _verifyPin() async {
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
                                  _withdraw();
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
    String phone = _phoneController.text.trim();
    const double withdrawFee = 50;


    if (amount == null || amount <= 0 || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Montant ou téléphone invalide")),
      );
      return;
    }

    if (!phone.startsWith("+228")) {
      phone = "+228$phone";
    }

    if (amount > _currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Solde insuffisant : $_currentBalance FCFA")),
      );
      return;
    }




    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    showLoading(context, text: "Envoi du paiement...");


    try {
      final user = _auth.currentUser!;

      final response = await http.post(
        Uri.parse("$backendUrl/paycashRETRAIT/withdraw"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': user.uid,
          'amount': amount,
          'number': phone,
          'operator': _selectedOperator,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final token = data['token'];
          // 🔹 Mettre à jour Firestore
          final userRef = _firestore.collection('users').doc(user.uid);
          await _firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(userRef);

            final transactionRef = _firestore.collection('transactions').doc();
            transaction.set(transactionRef, {
              'amount': amount,
              'from': uid,
              'to': "",
              "phone": phone,
              'type': 'retrait',
              'status': 'terminée',
              'operator': _selectedOperator,
              'createdAt': FieldValue.serverTimestamp(),
            });
          });

          Navigator.pop(context); // ✅ fermer loading


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
                reference: token,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Échec du retrait : ${data['message'] ?? 'Erreur'}",
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur serveur : ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
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
        automaticallyImplyLeading: false,
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
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Text("* il sera prelever 50f sur le retrait peut importe la somme retirer", style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF7C0404),
              ),),
            ),
            _balanceCard(),
            const SizedBox(height: 40),
            _operatorSelector(),
            const SizedBox(height: 30),
            _amountField("Montant à retirer"),
            const SizedBox(height: 20),
            _phoneField("Votre numéro de téléphone"),
            const SizedBox(height: 30),
            _actionButton("Retirer", _verifyPin),
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
          "${NumberFormat('#,###', 'fr_FR').format(_currentBalance)} FCFA",
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
