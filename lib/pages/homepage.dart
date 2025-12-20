// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:intl/intl.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paycash/pages/setorupdatepin.dart';
import 'package:paycash/transactions/receivemoney.dart';
import 'package:paycash/transactions/sendmoney.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../transactions/recharge.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController pinnewentryCtrl = TextEditingController();
  String? userUniqueId;
  String userName = "";
  String enteredPin = "";
  bool _isBalanceVisible = false;
  String pindeclaglob = "";
  String idtotal = "";

  @override
  void initState() {
    super.initState();
    fetchUserData();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
  }
  //
  // void listenToNewTransactions(String userUniqueId) {
  //   final firestore = FirebaseFirestore.instance;
  //   String? lastTransactionId; // pour éviter les doublons
  //
  //   firestore
  //       .collection('transactions')
  //       .orderBy('createdAt', descending: true)
  //       .snapshots()
  //       .listen((snapshot) async {
  //         for (var change in snapshot.docChanges) {
  //           if (change.type == DocumentChangeType.added) {
  //             final t = change.doc.data() as Map<String, dynamic>;
  //             final fromFull = t['from'] ?? '';
  //             final toFull = t['to'] ?? '';
  //             final amount = t['amount'] ?? 0;
  //             final type = t['type'] ?? '';
  //
  //             // éviter double notification pour la même transaction
  //             if (change.doc.id == lastTransactionId) continue;
  //             lastTransactionId = change.doc.id;
  //
  //             // vérifier si l'utilisateur est concerné
  //             final fromId = extractInternalId(fromFull);
  //             final toId = extractInternalId(toFull);
  //
  //             // attendre les noms
  //             final fromName = await getUserName(fromFull);
  //             final toName = await getUserName(toFull);
  //
  //             if (fromId == userUniqueId || toId == userUniqueId) {
  //               String title = "";
  //               String body = "";
  //
  //               if (type == 'retrait' ||
  //                   (fromId == userUniqueId && toFull.isEmpty)) {
  //                 title = "📷 Retrait";
  //                 body = "Vous avez retiré $amount FCFA";
  //               } else if (type == 'recharge') {
  //                 title = "💰 Recharge";
  //                 body = "Vous avez rechargé votre compte de $amount FCFA";
  //               } else if (type == 'transfert') {
  //                 if (fromId == userUniqueId) {
  //                   title = "💸 Transfert envoyé";
  //                   body = "Vous avez envoyé $amount FCFA à $toName";
  //                 } else if (toId == userUniqueId) {
  //                   title = "💸 Transfert reçu";
  //                   body = "Vous avez reçu $amount FCFA de $fromName";
  //                 }
  //               }
  //
  //               if (title.isNotEmpty && body.isNotEmpty) {
  //                 NotificationService.showNotification(
  //                   title: title,
  //                   body: body,
  //                 );
  //               }
  //             }
  //           }
  //         }
  //       });
  // }

  // Extraction de l'ID interne pour comparer localement (utilisé pour filtrer)
  String extractInternalId(String fullId) {
    final parts = fullId.split('_');
    return parts.length >= 2 ? parts[parts.length - 2] : fullId;
  }

  // Récupération du user actuel et préparation de son ID interne
  Future<void> fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await firestore.collection('users').doc(uid).get();
    final data = doc.data()!;
    final fullIdUnique = data['idUnique'] as String;
    final internalId = extractInternalId(fullIdUnique);

    setState(() {
      userUniqueId = internalId;
      userName = data['name'] ?? "Utilisateur";
      pindeclaglob = data['pin'] ?? "";
      idtotal = data['idUnique'] ?? "";
    });
  }

  // Données utilisateur pour solde / email / statut
  Future<Map<String, dynamic>> getUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await firestore.collection('users').doc(uid).get();
    return doc.data()!;
  }

  // Récupérer le nom de l'utilisateur via son idUnique complet
  Future<String> getUserNameById(String fullIdUnique) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fullIdUnique)
          .get();

      if (doc.exists) {
        return doc.data()!['name'] ?? "Inconnu(e)";
      } else {
        return "Inconnu(e)";
      }
    } catch (e) {
      return "Inconnu(e)";
    }
  }

  Future<String> getUserName(String fullIdUnique) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('idUnique', isEqualTo: fullIdUnique)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first['name'] ?? "Inconnu(e)";
      } else {
        return "Inconnu(e)";
      }
    } catch (e) {
      return "Inconnu(e)";
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (userUniqueId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: const Color(0xFFF8F3EC),
        centerTitle: true,
        title: Text(
          "PayCash",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4E342E),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌟 Carte utilisateur (style carte bancaire)
                FutureBuilder<Map<String, dynamic>>(
                  future: getUserData(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final userdata = snapshot.data!;
                    final name = userdata['name'];
                    final status = userdata['status'];
                    final fullIdUnique = userdata['idUnique'] ?? "";
                    final pinset = userdata['pinSet'];
                    final pin = userdata['pin'] ?? "";

                    return Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4E342E), Color(0xFF6D4C41)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.brown.withOpacity(0.3),
                            offset: const Offset(0, 6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            status,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFD7B98E),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                fullIdUnique.substring(0, 12) + "••••",
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white,
                                  fontSize: 18,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  if (pinset == true) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) {
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            final double screenWidth =
                                                constraints.maxWidth;
                                            final double dialogWidth =
                                                screenWidth > 500
                                                ? 420
                                                : screenWidth * 0.9;

                                            return StatefulBuilder(
                                              builder: (context, setStateDialog) {
                                                Color pinColor;
                                                if (enteredPin.length < 4) {
                                                  pinColor = Colors.red;
                                                } else if (enteredPin.length <
                                                    6) {
                                                  pinColor = Colors.orange;
                                                } else {
                                                  pinColor = Colors.green;
                                                }

                                                return AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.all(20),
                                                  content: SingleChildScrollView(
                                                    child: SizedBox(
                                                      width: dialogWidth,
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "Entrez votre code PIN de sécurité",
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: GoogleFonts.poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize:
                                                                  screenWidth <
                                                                      360
                                                                  ? 18
                                                                  : 22,
                                                              color:
                                                                  const Color(
                                                                    0xFF4E342E,
                                                                  ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 18,
                                                          ),

                                                          PinCodeTextField(
                                                            appContext: context,
                                                            length: 6,
                                                            obscureText: true,
                                                            obscuringCharacter:
                                                                "●",
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            animationType:
                                                                AnimationType
                                                                    .fade,
                                                            enableActiveFill:
                                                                true,
                                                            pinTheme: PinTheme(
                                                              shape:
                                                                  PinCodeFieldShape
                                                                      .box,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              fieldHeight:
                                                                  screenWidth <
                                                                      360
                                                                  ? 42
                                                                  : 48,
                                                              fieldWidth:
                                                                  screenWidth <
                                                                      360
                                                                  ? 38
                                                                  : 45,
                                                              inactiveFillColor:
                                                                  Colors.white,
                                                              selectedFillColor:
                                                                  Colors.white,
                                                              activeFillColor:
                                                                  Colors.white,
                                                              inactiveColor:
                                                                  pinColor,
                                                              selectedColor:
                                                                  const Color(
                                                                    0xFF6D4C41,
                                                                  ),
                                                              activeColor:
                                                                  pinColor,
                                                            ),
                                                            onChanged: (value) {
                                                              setStateDialog(
                                                                () =>
                                                                    enteredPin =
                                                                        value,
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text(
                                                        "Annuler",
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                enteredPin
                                                                        .length ==
                                                                    6
                                                                ? Colors.green
                                                                : const Color(
                                                                    0xFF6D4C41,
                                                                  ),
                                                            minimumSize:
                                                                const Size(
                                                                  110,
                                                                  45,
                                                                ),
                                                          ),
                                                      onPressed:
                                                          enteredPin.length == 6
                                                          ? () {
                                                              final bool
                                                              isValidPin =
                                                                  BCrypt.checkpw(
                                                                    enteredPin,
                                                                    pindeclaglob,
                                                                  );

                                                              if (isValidPin) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .check_circle,
                                                                          color:
                                                                              Colors.green,
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Text(
                                                                          "Code PIN correct",
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    duration:
                                                                        Duration(
                                                                          seconds:
                                                                              1,
                                                                        ),
                                                                  ),
                                                                );

                                                                setState(() {
                                                                  _isBalanceVisible =
                                                                      !_isBalanceVisible;
                                                                });

                                                                Navigator.pop(
                                                                  context,
                                                                );
                                                              } else {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .error,
                                                                          color:
                                                                              Colors.red,
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Text(
                                                                          "Code PIN incorrect",
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    duration:
                                                                        Duration(
                                                                          seconds:
                                                                              2,
                                                                        ),
                                                                  ),
                                                                );

                                                                setStateDialog(
                                                                  () =>
                                                                      enteredPin =
                                                                          "",
                                                                );
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
                                    );
                                  } else if (pinset == false) {
                                    final snack = ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Veuillez définir un code Pin.",
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );

                                    snack.closed.then((_) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SetOrUpdatePinPage(
                                            pinExists: pinset,
                                          ),
                                        ),
                                      );
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.copy,
                                  color: Color(0xFFD7B98E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // 💰 Solde et recharge
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Bouton recharge
                      Column(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RechargePage(),
                                ),
                              );
                            },
                            child: Container(
                              height: 65,
                              width: 65,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFD7B98E),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Recharge",
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF4E342E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Solde actuel
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                getUserData();
                              });
                            },
                            icon: Icon(Icons.refresh),
                          ),
                          FutureBuilder<Map<String, dynamic>>(
                            future: getUserData(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Text("..");
                              }
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Text(
                                  "...",
                                  style: GoogleFonts.roboto(
                                    fontSize: 23,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4E342E),
                                  ),
                                );
                              }
                              final data = snapshot.data!;
                              return Text(
                                _isBalanceVisible
                                    ? "${NumberFormat('#,###', 'fr_FR').format(data['balance'])} F"
                                    : "Solde",
                                style: GoogleFonts.poppins(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4E342E),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 3),
                          IconButton(
                            onPressed: () async {
                              String enteredPin =
                                  ""; // assure-toi que c'est défini dans le parent
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) {
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final double screenWidth =
                                          constraints.maxWidth;
                                      final double dialogWidth =
                                          screenWidth > 500
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
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.all(20),
                                            content: SingleChildScrollView(
                                              child: SizedBox(
                                                width: dialogWidth,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "Entrez votre code PIN de sécurité",
                                                      textAlign:
                                                          TextAlign.center,
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize:
                                                                screenWidth <
                                                                    360
                                                                ? 18
                                                                : 22,
                                                            color: const Color(
                                                              0xFF4E342E,
                                                            ),
                                                          ),
                                                    ),
                                                    const SizedBox(height: 18),

                                                    PinCodeTextField(
                                                      appContext: context,
                                                      length: 6,
                                                      obscureText: true,
                                                      obscuringCharacter: "●",
                                                      keyboardType:
                                                          TextInputType.number,
                                                      animationType:
                                                          AnimationType.fade,
                                                      enableActiveFill: true,
                                                      pinTheme: PinTheme(
                                                        shape: PinCodeFieldShape
                                                            .box,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        fieldHeight:
                                                            screenWidth < 360
                                                            ? 42
                                                            : 48,
                                                        fieldWidth:
                                                            screenWidth < 360
                                                            ? 38
                                                            : 45,
                                                        inactiveFillColor:
                                                            Colors.white,
                                                        selectedFillColor:
                                                            Colors.white,
                                                        activeFillColor:
                                                            Colors.white,
                                                        inactiveColor: pinColor,
                                                        selectedColor:
                                                            const Color(
                                                              0xFF6D4C41,
                                                            ),
                                                        activeColor: pinColor,
                                                      ),
                                                      onChanged: (value) {
                                                        setStateDialog(
                                                          () => enteredPin =
                                                              value,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      enteredPin.length == 6
                                                      ? Colors.green
                                                      : const Color(0xFF6D4C41),
                                                  minimumSize: const Size(
                                                    110,
                                                    45,
                                                  ),
                                                ),
                                                onPressed:
                                                    enteredPin.length == 6
                                                    ? () {
                                                        final bool isValidPin =
                                                            BCrypt.checkpw(
                                                              enteredPin,
                                                              pindeclaglob,
                                                            );

                                                        if (isValidPin) {
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
                                                              duration:
                                                                  Duration(
                                                                    seconds: 1,
                                                                  ),
                                                            ),
                                                          );

                                                          setState(() {
                                                            _isBalanceVisible =
                                                                !_isBalanceVisible;
                                                          });

                                                          Navigator.pop(
                                                            context,
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
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    "Code PIN incorrect",
                                                                  ),
                                                                ],
                                                              ),
                                                              duration:
                                                                  Duration(
                                                                    seconds: 2,
                                                                  ),
                                                            ),
                                                          );

                                                          setStateDialog(
                                                            () =>
                                                                enteredPin = "",
                                                          );
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
                              );
                            },
                            icon: Icon(
                              _isBalanceVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF4E342E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // 🔁 Envoyer / Recevoir
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _actionButton(
                      context,
                      icon: Icons.call_made_rounded,
                      label: "Envoyer",
                      color: const Color(0xFF8D6E63),
                      page: SendMoney(),
                    ),
                    _actionButton(
                      context,
                      icon: Icons.call_received,
                      label: "Recevoir",
                      color: const Color(0xFF6D4C41),
                      page: ReceiveMoney(),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Text(
                  "Historique des dernières transactions",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4E342E),
                  ),
                ),
                const SizedBox(height: 18),

                // Historique
                StreamBuilder<QuerySnapshot>(
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
                      final from = t['from'] ?? '';
                      final to = t['to'] ?? '';
                      return from == userUniqueId || to == userUniqueId;
                    }).toList();

                    if (userTx.isEmpty) {
                      return const Center(child: Text("Aucune transaction"));
                    }

                    final displayTx = userTx.length > 6
                        ? userTx.sublist(0, 4)
                        : userTx;

                    return ListView.builder(
                      shrinkWrap: true, // 👈 important
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayTx.length,
                      itemBuilder: (context, index) {
                        final t =
                            displayTx[index].data() as Map<String, dynamic>;
                        final fromFull = t['from'] ?? '';
                        final toFull = t['to'] ?? '';
                        final amount = t['amount'] ?? 0;
                        final type = t['type'] ?? '';
                        final statut = t['status'] ?? '';
                        final createdAt = t['createdAt'] != null
                            ? (t['createdAt'] as Timestamp).toDate()
                            : DateTime.now();

                        return FutureBuilder<List<String>>(
                          future: Future.wait([
                            getUserNameById(fromFull),
                            getUserNameById(toFull),
                          ]),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return const ListTile(
                                title: Text("Chargement..."),
                              );
                            }

                            final fromName = userSnapshot.data![0];
                            final toName = userSnapshot.data![1];

                            String title = "";
                            String subtitle = "";

                            if (type == 'retrait') {
                              title = "Retrait";
                              subtitle = "Vous avez retiré $amount FCFA";
                            } else if (type == 'recharge') {
                              title = "Recharge";
                              subtitle =
                                  "Vous avez rechargé votre compte de $amount FCFA";
                            } else if (type == 'transfert') {
                              if (fromFull == uid) {
                                title = "Transfert d'argent";
                                subtitle =
                                    "Vous avez envoyé $amount FCFA à $toName";
                              } else if (toFull == uid) {
                                title = "Transfert reçu";
                                subtitle =
                                    "Vous avez reçu $amount FCFA de $fromName";
                              }
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF523B36),
                                child: Text(
                                  (fromName.isNotEmpty ? fromName[0] : "?")
                                      .toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subtitle, style: GoogleFonts.poppins()),
                                  const SizedBox(height: 1),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      timeago.format(createdAt, locale: 'fr'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Widget page,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          },
          child: Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 42),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4E342E),
          ),
        ),
      ],
    );
  }
}
