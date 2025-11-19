import 'package:flutter/material.dart';
import 'package:paycash/pages/friends.dart';
import 'historique.dart';
import 'homepage.dart';
import 'settings.dart';

class Acceuil extends StatefulWidget {
  const Acceuil({super.key});

  @override
  State<Acceuil> createState() => _AcceuilState();
}

class _AcceuilState extends State<Acceuil> {
  int _selectedIndex = 0;

  final List<Widget> pages = [
    const Homepage(),
    const Historique(),
    const Friends(),
    const Settings(),
  ];

  void _setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EC), // fond beige doux
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: pages[_selectedIndex],
      ),

      // 🌟 Barre de navigation modernisée et lisible
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF523B36), // marron profond
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: _selectedIndex,
            onTap: _setSelectedIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Color(0xFFF3AA77),
            // doré clair
            unselectedItemColor: Colors.white,
            selectedFontSize: 13,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            items: const [
              BottomNavigationBarItem(
                label: "Accueil",
                icon: Icon(Icons.home_rounded, size: 28),
              ),
              BottomNavigationBarItem(
                label: "Historique",
                icon: Icon(Icons.history_rounded, size: 26),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: "Amis",
              ),
              BottomNavigationBarItem(
                label: "Profil",
                icon: Icon(Icons.settings_rounded, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
