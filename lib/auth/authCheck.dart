// ignore_for_file: file_names

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/acceuil.dart';
import 'connection.dart';

class AuhtCheck extends StatelessWidget {
  const AuhtCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (snapshot.hasData) {
          return Acceuil();
        } else {
          return Connection();
        }
      },
    );
  }
}
