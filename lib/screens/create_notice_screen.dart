import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // ¡NUEVO! Para conectarnos al servidor
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class CreateNoticeScreen extends StatefulWidget {
  final String moodleToken; // ¡NUEVO! Para saber quién publica
  final String courseId;    // ¡NUEVO! Para saber en qué curso

  const CreateNoticeScreen({
    super.key,
    required this.moodleToken,
    required this.courseId,
  });

  @override
  State<CreateNoticeScreen> createState() => _CreateNoticeScreenState();
}

class _CreateNoticeScreenState extends State<CreateNoticeScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String selectedType = 'Importante';
  bool notifyStudents = true;
  bool pinNotice = false;
  bool isSubmitting = false; // ¡NUEVO! Para el circulito de carga

  final List<String> noticeTypes = [
    'Importante',
    'Recordatorio',
    'Material',
    'Clase',
  ];

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  // ¡MAGIA ACÁ! Enviamos el aviso al servidor
  Future<void> _submitNotice() async {
    final title = titleController.text.trim();
    final message = messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingrese un título y un mensaje.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final url = Uri.parse('${AppConfig.apiUrl}/teacher/create-notice');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.moodleToken,
          'courseid': widget.courseId,
          'title': title,
          'message': message,
          'type': selectedType,
          'notify': notifyStudents,
          'pin': pinNotice,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso "$title" publicado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Volvemos atrás avisando que fue exitoso
      } else {
        throw Exception('El servidor rechazó la publicación del aviso');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
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
    final noticeColor = _getColorForType(selectedType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear aviso'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB3123B),
                  Color(0xFFC6285A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nuevo aviso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Publique anuncios y novedades para mantener informados a sus estudiantes.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Título del aviso',
                      hintText: 'Ej: Cambio de fecha de entrega',
                      prefixIcon: const Icon(Icons.campaign_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Mensaje',
                      hintText: 'Escriba el contenido del aviso',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 84),
                        child: Icon(Icons.message_rounded),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Tipo de aviso',
                      prefixIcon: const Icon(Icons.category_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    items: noticeTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: _optionIcon(
                      Icons.notifications_active_rounded,
                      const Color(0xFF7DB7FF),
                    ),
                    title: const Text(
                      'Notificar a estudiantes',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Enviar notificación al publicar el aviso',
                    ),
                    value: notifyStudents,
                    activeColor: const Color(0xFFB3123B),
                    onChanged: (value) {
                      setState(() {
                        notifyStudents = value;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: _optionIcon(
                      Icons.push_pin_rounded,
                      const Color(0xFFFFD180),
                    ),
                    title: const Text(
                      'Fijar aviso',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Mantener el aviso destacado en la parte superior',
                    ),
                    value: pinNotice,
                    activeColor: const Color(0xFFB3123B),
                    onChanged: (value) {
                      setState(() {
                        pinNotice = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: noticeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getIconForType(selectedType),
                      size: 34,
                      color: noticeColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Vista previa: $selectedType',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notifyStudents
                        ? 'Los estudiantes recibirán una notificación.'
                        : 'El aviso se publicará sin notificación.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pinNotice
                        ? 'Este aviso quedará fijado en la parte superior.'
                        : 'El aviso se mostrará en orden cronológico normal.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
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
              onPressed: isSubmitting ? null : _submitNotice, // ¡Llamamos a la nueva función!
              icon: isSubmitting
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
              )
                  : const Icon(Icons.send_rounded),
              label: Text(isSubmitting ? 'Publicando...' : 'Publicar aviso'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionIcon(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Importante':
        return Icons.priority_high_rounded;
      case 'Recordatorio':
        return Icons.notifications_active_rounded;
      case 'Material':
        return Icons.menu_book_rounded;
      case 'Clase':
        return Icons.video_call_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Importante':
        return Colors.red;
      case 'Recordatorio':
        return Colors.orange;
      case 'Material':
        return Colors.blue;
      case 'Clase':
        return Colors.green;
      default:
        return const Color(0xFFB3123B);
    }
  }
}