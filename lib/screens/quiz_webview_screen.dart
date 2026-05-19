import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart'; // Importamos la configuración centralizada

class QuizWebViewScreen extends StatefulWidget {
  final String quizUrl;
  final String moodleToken;
  final String title;

  const QuizWebViewScreen({
    super.key,
    required this.quizUrl,
    required this.moodleToken,
    required this.title,
  });

  @override
  State<QuizWebViewScreen> createState() => _QuizWebViewScreenState();
}

class _QuizWebViewScreenState extends State<QuizWebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setUserAgent('MoodleMobile') // Máscara para que Moodle lo vea como app
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
        ),
      );

    _loadWithAutoLogin();
  }

  Future<void> _loadWithAutoLogin() async {
    try {
      // 1. Recuperamos la llave privada (privatetoken) de la memoria
      final prefs = await SharedPreferences.getInstance();
      final privateToken = prefs.getString('moodle_private_token') ?? '';

      if (privateToken.isEmpty) {
        throw Exception('No hay llave privada guardada. Inicie sesión nuevamente.');
      }

      // 2. ¡MAGIA! Llamamos a la nueva ruta de Node.js
      final url = Uri.parse('${AppConfig.apiUrl}/get-autologin-url');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.moodleToken,
          'privatetoken': privateToken,
          'destinationUrl': widget.quizUrl, // Le pasamos la URL del cuestionario
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['ok'] == true && data['magicUrl'] != null) {
          // 3. Cargamos el Link Mágico en el navegador interno
          controller.loadRequest(Uri.parse(data['magicUrl']));
        } else {
          throw Exception('El servidor no devolvió el link mágico');
        }
      } else {
        throw Exception('Error del servidor (Código: ${response.statusCode})');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ingreso automático falló. $e'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      // Plan B: Si Node.js falla, intentamos cargar la URL normal
      controller.loadRequest(Uri.parse(widget.quizUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    const unamisRed = Color(0xFFB3123B); // <-- ¡Volvimos al rojo UNAMIS!

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: unamisRed,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: unamisRed),
              ),
          ],
        ),
      ),
    );
  }
}