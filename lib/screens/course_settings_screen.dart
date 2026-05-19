import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart'; // Importamos la configuración centralizada

class CourseSettingsScreen extends StatefulWidget {
  final String initialCourseTitle;
  final String initialTeacherName;
  final String initialCohortText;
  final String initialCode;
  final String initialModality;
  final String initialLoadHours;
  final String initialDescription;

  // Necesitamos la llave y el ID para mandar a Moodle
  final String moodleToken;
  final String courseId;

  const CourseSettingsScreen({
    super.key,
    required this.initialCourseTitle,
    required this.initialTeacherName,
    required this.initialCohortText,
    required this.initialCode,
    required this.initialModality,
    required this.initialLoadHours,
    required this.initialDescription,
    required this.moodleToken,
    required this.courseId,
  });

  @override
  State<CourseSettingsScreen> createState() => _CourseSettingsScreenState();
}

class _CourseSettingsScreenState extends State<CourseSettingsScreen> {
  late final TextEditingController courseTitleController;
  late final TextEditingController teacherNameController;
  late final TextEditingController cohortController;
  late final TextEditingController codeController;
  late final TextEditingController modalityController;
  late final TextEditingController loadHoursController;
  late final TextEditingController descriptionController;

  bool isSaving = false; // Variable para mostrar el estado de carga

  @override
  void initState() {
    super.initState();
    courseTitleController =
        TextEditingController(text: widget.initialCourseTitle);
    teacherNameController =
        TextEditingController(text: widget.initialTeacherName);
    cohortController =
        TextEditingController(text: widget.initialCohortText);
    codeController =
        TextEditingController(text: widget.initialCode);
    modalityController =
        TextEditingController(text: widget.initialModality);
    loadHoursController =
        TextEditingController(text: widget.initialLoadHours);
    descriptionController =
        TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    courseTitleController.dispose();
    teacherNameController.dispose();
    cohortController.dispose();
    codeController.dispose();
    modalityController.dispose();
    loadHoursController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // ¡ACÁ ESTÁ LA MAGIA! Apunta al nuevo endpoint de nuestro server.js
  Future<void> _saveSettings() async {
    setState(() {
      isSaving = true;
    });

    try {
      final url = Uri.parse('${AppConfig.apiUrl}/guardar-config-curso');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'courseId': widget.courseId,
          'codigo': codeController.text.trim(),
          'cohorte': cohortController.text.trim(),
          'modalidad': modalityController.text.trim(),
          'cargaHoraria': loadHoursController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(
          context,
          {
            'courseTitle': courseTitleController.text.trim(),
            'teacherName': teacherNameController.text.trim(),
            'cohortText': cohortController.text.trim(),
            'code': codeController.text.trim(),
            'modality': modalityController.text.trim(),
            'loadHours': loadHoursController.text.trim(),
            'description': descriptionController.text.trim(),
          },
        );
      } else {
        throw Exception('Error del servidor al actualizar');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. No se pudieron guardar los cambios.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del curso'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB3123B), // <-- Rojo UNAMIS intacto
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
                  'Editar datos del curso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Modifique la información general del curso. El diseño y los colores permanecerán iguales.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildField(
            controller: courseTitleController,
            label: 'Nombre del curso',
            icon: Icons.school_rounded,
            readOnly: true,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: codeController,
            label: 'Código',
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: teacherNameController,
            label: 'Docente',
            icon: Icons.person_rounded,
            readOnly: true,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: cohortController,
            label: 'Cohorte / año',
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: modalityController,
            label: 'Modalidad',
            icon: Icons.view_agenda_rounded,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: loadHoursController,
            label: 'Carga horaria',
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: descriptionController,
            label: 'Descripción corta',
            icon: Icons.description_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : _saveSettings,
              icon: isSaving
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
              )
                  : const Icon(Icons.save_rounded),
              label: Text(isSaving ? 'Guardando...' : 'Guardar cambios'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? Colors.black54 : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: readOnly ? Colors.grey : null),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}