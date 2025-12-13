import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'paymentsucces.dart';

class FacturePage extends StatefulWidget {
  final String url;
  final String token;
  final double amount;
  final String operator;

  const FacturePage({
    super.key,
    required this.url,
    required this.token,
    required this.amount,
    required this.operator,
  });

  @override
  State<FacturePage> createState() => _FacturePageState();
}

class _FacturePageState extends State<FacturePage> {
  bool _loading = true;
  final backendUrl = "https://paycash-d2q6.onrender.com";

  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      // Mobile (Android/iOS) → initialisation du controller
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => setState(() => _loading = false),
            onNavigationRequest: (request) async {
              if (request.url.contains("/paydunya_callback")) {
                await _verifyPayment();
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    }

    if (kIsWeb) {
      // Web → ouverture du navigateur externe
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPaymentWeb(widget.url);
      });
    }
  }

  // Flutter Web → ouvre le navigateur externe
  Future<void> _openPaymentWeb(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir le paiement")),
        );
      }
    }
  }

  // Vérification du paiement via backend
  Future<void> _verifyPayment() async {
    try {
      final response = await http.get(
        Uri.parse("$backendUrl/invoice_status?token=${widget.token}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['data']['status'] ?? 'pending';

        if (status.toString().toLowerCase() == "completed") {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentSuccessPage(
                title: "Recharge réussie",
                amount: widget.amount,
                operator: widget.operator,
                reference: widget.token, paymentUrl: '',
              ),
            ),
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Paiement en attente ou échoué")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur serveur: ${response.body}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Flutter Web → simple page avec bouton vérifier paiement
      return Scaffold(
        appBar: AppBar(
          title: const Text("Paiement"),
          backgroundColor: const Color(0xFF8B5E3C),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Redirection vers la page de paiement..."),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _verifyPayment(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5E3C),
                ),
                child: const Text("Vérifier le paiement"),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile (Android/iOS) → WebView intégrée
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paiement"),
        backgroundColor: const Color(0xFF8B5E3C),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
