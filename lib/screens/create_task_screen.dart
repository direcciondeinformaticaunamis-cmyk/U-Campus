import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Agregado para filtrar solo números
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();

  // ¡NUEVO! Controlador para el puntaje personalizado
  final TextEditingController maxScoreController = TextEditingController(text: '20');

  String selectedType = 'Archivo';
  bool allowFileUpload = true;
  bool graded = true;

  final List<String> taskTypes = [
    'Archivo',
    'Foro',
    'Cuestionario',
    'Enlace',
  ];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    dueDateController.dispose();
    maxScoreController.dispose(); // No olvidemos limpiar este
    super.dispose();
  }

  void _publishTask() {
    final title = titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese un título para la tarea'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validamos que el puntaje sea un número válido si tiene calificación
    int finalMaxScore = 0;
    if (graded) {
      final scoreText = maxScoreController.text.trim();
      if (scoreText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingrese el puntaje máximo para la tarea'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      finalMaxScore = int.tryParse(scoreText) ?? 0;
      if (finalMaxScore <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El puntaje debe ser mayor a 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    Navigator.pop(
      context,
      {
        'title': title,
        'description': descriptionController.text.trim(),
        'dueDate': dueDateController.text.trim(),
        'type': selectedType,
        'allowFileUpload': allowFileUpload,
        'graded': graded,
        'maxScore': finalMaxScore, // Mandamos el puntaje personalizado
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear tarea'),
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
                  'Nueva actividad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Cree una tarea para sus estudiantes y defina si tendrá calificación.',
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
                      labelText: 'Título de la tarea',
                      hintText: 'Ej: Actividad 2 - Lectura comprensiva',
                      prefixIcon: const Icon(Icons.assignment_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Explique las instrucciones de la actividad',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 64),
                        child: Icon(Icons.description_rounded),
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
                      labelText: 'Tipo de actividad',
                      prefixIcon: const Icon(Icons.category_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    items: taskTypes.map((type) {
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: dueDateController,
                    decoration: InputDecoration(
                      labelText: 'Fecha de entrega',
                      hintText: 'Ej: 20 marzo 2026 - 23:59',
                      prefixIcon: const Icon(Icons.calendar_month_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
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
                      Icons.upload_file_rounded,
                      const Color(0xFF7DB7FF),
                    ),
                    title: const Text(
                      'Permitir subida de archivos',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Los estudiantes podrán adjuntar archivos',
                    ),
                    value: allowFileUpload,
                    activeColor: const Color(0xFFB3123B),
                    onChanged: (value) {
                      setState(() {
                        allowFileUpload = value;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: _optionIcon(
                      Icons.grade_rounded,
                      const Color(0xFFA5D6A7),
                    ),
                    title: const Text(
                      'Actividad con calificación',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'La tarea tendrá nota o evaluación',
                    ),
                    value: graded,
                    activeColor: const Color(0xFFB3123B),
                    onChanged: (value) {
                      setState(() {
                        graded = value;
                      });
                    },
                  ),
                  if (graded) ...[
                    const SizedBox(height: 16),
                    // ¡ACÁ ESTÁ EL CAMBIO! Cajita de texto para números
                    TextField(
                      controller: maxScoreController,
                      keyboardType: TextInputType.number, // Abre el teclado numérico
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Solo deja escribir números
                      decoration: InputDecoration(
                        labelText: 'Puntaje máximo',
                        hintText: 'Ej: 10, 20, 100...',
                        prefixIcon: const Icon(Icons.stars_rounded),
                        suffixText: 'puntos',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onChanged: (value) {
                        // Forzamos que se redibuje la tarjeta de abajo (Vista Previa) cuando escribe
                        setState(() {});
                      },
                    ),
                  ],
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
                      color: const Color(0xFFB3123B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getIconForType(selectedType),
                      size: 34,
                      color: const Color(0xFFB3123B),
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
                    allowFileUpload
                        ? 'Los estudiantes podrán adjuntar archivos.'
                        : 'La entrega será sin archivos adjuntos.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    graded
                        ? 'La actividad contará con calificación sobre ${maxScoreController.text.isEmpty ? '...' : maxScoreController.text} puntos.'
                        : 'La actividad será sin nota.',
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
              onPressed: _publishTask,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Publicar tarea'),
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
      case 'Archivo':
        return Icons.upload_file_rounded;
      case 'Foro':
        return Icons.forum_rounded;
      case 'Cuestionario':
        return Icons.quiz_rounded;
      case 'Enlace':
        return Icons.link_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }
}