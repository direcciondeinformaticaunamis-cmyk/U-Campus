import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

class TaskSubmissionScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Map<String, dynamic> moduleData;

  const TaskSubmissionScreen({
    super.key,
    required this.title,
    this.subtitle = '',
    this.moduleData = const {},
  });

  @override
  State<TaskSubmissionScreen> createState() => _TaskSubmissionScreenState();
}

class _TaskSubmissionScreenState extends State<TaskSubmissionScreen> {
  final TextEditingController commentController = TextEditingController();

  bool submitted = false;
  bool isLoading = true;
  bool isPickingFile = false;
  bool isSubmitting = false;

  String? loadError;
  String? pickedFileName;
  String? pickedFilePath;

  Map<String, dynamic> assignmentDetail = {};
  Map<String, dynamic> assignmentStatus = {};

  @override
  void initState() {
    super.initState();
    _loadAssignmentData();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  // Limpiamos el HTML para que se vea bien en el tema de la app
  String _cleanHtmlLayout(String html) {
    String clean = html;
    clean = clean.replaceAll(RegExp(r'color\s*:\s*[^;"]+;?', caseSensitive: false), 'color: #222222;');
    clean = clean.replaceAll(RegExp(r'background-color\s*:\s*[^;"]+;?', caseSensitive: false), 'background-color: transparent;');
    clean = clean.replaceAll(RegExp(r'width\s*:\s*[^;"]+;?', caseSensitive: false), 'width: 100%;');
    return clean;
  }

  Future<void> _loadAssignmentData() async {
    final token = (widget.moduleData['usertoken'] ?? '').toString();
    final courseId = (widget.moduleData['courseid'] ?? '').toString();
    final cmid = (widget.moduleData['cmid'] ?? '').toString();

    try {
      final detailUrl = Uri.parse('${AppConfig.apiUrl}/assignment-detail?token=${Uri.encodeComponent(token)}&courseid=$courseId&cmid=$cmid');
      final detailResponse = await http.get(detailUrl);

      if (detailResponse.statusCode == 200) {
        assignmentDetail = jsonDecode(detailResponse.body);
        final assignId = assignmentDetail['id'].toString();

        final statusUrl = Uri.parse('${AppConfig.apiUrl}/assignment-status?token=${Uri.encodeComponent(token)}&assignid=$assignId');
        final statusResponse = await http.get(statusUrl);

        if (statusResponse.statusCode == 200) {
          assignmentStatus = jsonDecode(statusResponse.body);

          // --- RECUPERAR ARCHIVO Y COMENTARIO DE MOODLE (PARA QUE NO SALGA VACÍO) ---
          final submission = assignmentStatus['submission'];
          if (submission != null && submission['plugins'] != null) {
            final plugins = submission['plugins'] as List;

            for (var p in plugins) {
              // Buscar el archivo
              if (p['type'] == 'file' && p['fileareas'] != null && p['fileareas'].isNotEmpty) {
                final files = p['fileareas'][0]['files'] as List;
                if (files.isNotEmpty) {
                  pickedFileName = files[0]['filename'];
                }
              }
              // Buscar el comentario
              if (p['type'] == 'onlinetext' && p['editorfields'] != null && p['editorfields'].isNotEmpty) {
                final text = p['editorfields'][0]['text'] ?? '';
                commentController.text = text.toString().replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ');
              }
            }
          }

          final subStatus = (assignmentStatus['submissionstatus'] ?? '').toString().toLowerCase();
          submitted = subStatus == 'submitted' || subStatus == 'submittedearly' || (assignmentStatus['submitted'] == true);
        }
      }

      setState(() {
        isLoading = false;
        loadError = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        loadError = 'Error de conexión. Asegúrate de que el backend esté corriendo.';
      });
    }
  }

  Future<void> _pickFile() async {
    setState(() => isPickingFile = true);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );
    if (result != null) {
      setState(() {
        pickedFileName = result.files.first.name;
        pickedFilePath = result.files.first.path;
      });
    }
    setState(() => isPickingFile = false);
  }

  void _unsubmitTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Anular entrega?'),
        content: const Text('Podrás quitar el archivo actual o subir uno nuevo para corregir tu entrega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Anular', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        submitted = false; // Habilitamos la edición localmente
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ahora puedes modificar tu entrega.'))
      );
    }
  }

  Future<void> _submitTask() async {
    if (pickedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, adjunta un archivo.')));
      return;
    }
    setState(() => isSubmitting = true);

    try {
      final token = widget.moduleData['usertoken'];
      final assignId = assignmentDetail['id'];

      String? fileBase64;
      if (pickedFilePath != null) {
        fileBase64 = base64Encode(await File(pickedFilePath!).readAsBytes());
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/assignment-submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'assignid': assignId,
          'fileName': pickedFileName,
          'fileBase64': fileBase64,
          'comment': commentController.text,
          'finalSubmit': true,
        }),
      );

      if (response.statusCode == 200) {
        await _loadAssignmentData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Tarea enviada correctamente!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar la tarea'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  HtmlWidget(_cleanHtmlLayout(assignmentDetail['intro'] ?? widget.moduleData['intro'] ?? 'Sin descripción.')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TARJETA DE ADJUNTAR ARCHIVO
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adjuntar archivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8FA),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFE4E4E8)),
                    ),
                    child: Column(
                      children: [
                        Icon(pickedFileName != null ? Icons.description : Icons.cloud_upload, size: 40, color: const Color(0xFFB3123B)),
                        const SizedBox(height: 10),
                        Text(pickedFileName ?? 'Ningún archivo adjunto',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center
                        ),
                        const SizedBox(height: 15),

                        // LÓGICA DE BOTONES:
                        if (submitted == false)
                          OutlinedButton.icon(
                            onPressed: isPickingFile ? null : (pickedFileName != null ? () => setState(() => pickedFileName = null) : _pickFile),
                            icon: Icon(pickedFileName != null ? Icons.delete : Icons.attach_file),
                            label: Text(pickedFileName != null ? 'Quitar archivo' : 'Adjuntar archivo'),
                          )
                        else
                        // AQUÍ SALE EL BOTÓN DE ANULAR SI YA SE ENVIÓ
                          OutlinedButton.icon(
                            onPressed: _unsubmitTask,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red)
                            ),
                            icon: const Icon(Icons.undo),
                            label: const Text('Anular entrega'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: commentController,
                    enabled: !submitted,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Comentario para el docente',
                        hintText: 'Escribe algo sobre tu entrega...'
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Mini tarjetas de estado
          Row(
            children: [
              Expanded(child: _statusMini(pickedFileName != null ? 'Adjunto' : 'Vacío', 'Archivo', pickedFileName != null)),
              const SizedBox(width: 10),
              Expanded(child: _statusMini(submitted ? 'Enviada' : 'Pendiente', 'Entrega', submitted)),
            ],
          ),
          const SizedBox(height: 24),

          // Botón Enviar (Deshabilitado si ya se envió)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (submitted || isSubmitting) ? null : _submitTask,
              child: Text(isSubmitting ? 'Enviando...' : submitted ? 'Tarea ya enviada' : 'Entregar tarea'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB3123B), Color(0xFFC6285A)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estado de la Tarea', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(submitted ? '¡Tu entrega está lista para revisión!' : 'Sube tu archivo para completar la actividad.',
              style: const TextStyle(color: Colors.white70)
          ),
        ],
      ),
    );
  }

  Widget _statusMini(String val, String label, bool ok) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(ok ? Icons.check_circle : Icons.warning, color: ok ? Colors.green : Colors.orange, size: 18),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(val, style: TextStyle(color: ok ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}