import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AddForumPostScreen extends StatefulWidget {
  final String moodleToken;
  final String forumId;
  final String courseId;
  final String? replyToSubject; // Si viene lleno, significa que tocó "Responder"

  const AddForumPostScreen({
    super.key,
    required this.moodleToken,
    required this.forumId,
    required this.courseId,
    this.replyToSubject,
  });

  @override
  State<AddForumPostScreen> createState() => _AddForumPostScreenState();
}

class _AddForumPostScreenState extends State<AddForumPostScreen> {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.replyToSubject != null && widget.replyToSubject!.isNotEmpty) {
      subjectController.text = 'Re: ${widget.replyToSubject}';
    }
  }

  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final subject = subjectController.text.trim();
    final message = messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingrese un asunto y un mensaje.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // ¡LA MAGIA ACÁ! Separamos la lógica según la acción
      final isReply = widget.replyToSubject != null && widget.replyToSubject!.isNotEmpty;
      final endpoint = isReply ? '/student/forum-reply' : '/student/forum-new-discussion';
      final url = Uri.parse('${AppConfig.apiUrl}$endpoint');

      final bodyData = {
        'token': widget.moodleToken,
        'subject': subject,
        'message': message,
      };

      if (isReply) {
        bodyData['discussionid'] = widget.forumId;
      } else {
        bodyData['forumid'] = widget.forumId;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensaje publicado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        // Leemos el error exacto que nos tira el backend para no ver el genérico
        String errorMsg = 'Error del servidor';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            errorMsg = errorData['error'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.replyToSubject != null ? 'Responder al debate' : 'Añadir tema de debate'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: subjectController,
                    decoration: InputDecoration(
                      labelText: 'Asunto',
                      hintText: 'Ej: Consulta sobre la tarea',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: 'Mensaje',
                      hintText: 'Escriba su mensaje o respuesta aquí...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB3123B),
                foregroundColor: Colors.white,
              ),
              icon: isSubmitting
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(
                isSubmitting ? 'Enviando...' : 'Publicar en el foro',
              ),
            ),
          ),
        ],
      ),
    );
  }
}