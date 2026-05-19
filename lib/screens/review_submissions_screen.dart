import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class ReviewSubmissionsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> createdTasks;
  final String moodleToken;
  final String courseId;

  const ReviewSubmissionsScreen({
    super.key,
    this.createdTasks = const [],
    this.moodleToken = '',
    this.courseId = '',
  });

  @override
  State<ReviewSubmissionsScreen> createState() => _ReviewSubmissionsScreenState();
}

class _ReviewSubmissionsScreenState extends State<ReviewSubmissionsScreen> {
  bool isLoading = true;
  String? loadError;
  List<Map<String, dynamic>> courseTasks = [];

  @override
  void initState() {
    super.initState();
    _loadAssignmentsFromMoodle();
  }

  Future<void> _loadAssignmentsFromMoodle() async {
    if (widget.moodleToken.isEmpty) {
      setState(() {
        isLoading = false;
        loadError = 'Falta el token de acceso para consultar a Moodle.';
      });
      return;
    }

    try {
      List<Map<String, dynamic>> foundTasks = [];
      List<dynamic> coursesToFetch = [];

      // Si nos pasan un curso específico
      if (widget.courseId.isNotEmpty && widget.courseId != '0') {
        coursesToFetch.add({
          'id': widget.courseId,
          'fullname': 'Actividad del curso'
        });
      }
      // Si entramos desde el Inicio (courseId es '0'), buscamos TODOS los cursos
      else {
        final crsRes = await http.get(Uri.parse(
            '${AppConfig.apiUrl}/my-courses?token=${Uri.encodeComponent(widget.moodleToken)}'));
        if (crsRes.statusCode == 200) {
          coursesToFetch = jsonDecode(crsRes.body) as List<dynamic>;
        } else {
          throw Exception('Error al cargar la lista de cursos');
        }
      }

      for (var course in coursesToFetch) {
        final cid = course['id'].toString();
        final courseName = course['fullname']?.toString() ?? 'Actividad del curso';

        // ¡EL CAZADOR DE NOMBRES!
        // Primero descargamos la lista real de todos los participantes del curso
        Map<String, String> realNamesMap = {};
        try {
          final partUrl = Uri.parse(
              '${AppConfig.apiUrl}/course-participants?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=$cid');
          final partRes = await http.get(partUrl);
          if (partRes.statusCode == 200) {
            final parts = jsonDecode(partRes.body) as List<dynamic>;
            for (var p in parts) {
              final pid = p['id']?.toString() ?? '';
              final pName = p['fullname']?.toString() ?? '';
              if (pid.isNotEmpty && pName.isNotEmpty) {
                realNamesMap[pid] = pName;
              }
            }
          }
        } catch (e) {
          debugPrint('No se pudo cargar la lista de participantes para cruzar nombres.');
        }

        final assignUrl = Uri.parse(
            '${AppConfig.apiUrl}/course-contents?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=$cid');

        final resContents = await http.get(assignUrl);
        if (resContents.statusCode == 200) {
          final contents = jsonDecode(resContents.body) as List<dynamic>;

          for (var section in contents) {
            final modules = section['modules'] as List<dynamic>? ?? [];
            for (var mod in modules) {
              if (mod['modname'] == 'assign') {
                final assignId = mod['instance'].toString();

                final subsUrl = Uri.parse(
                    '${AppConfig.apiUrl}/teacher/assignment-submissions?token=${Uri.encodeComponent(widget.moodleToken)}&assignid=$assignId&courseid=$cid');

                final resSubs = await http.get(subsUrl);
                List<Map<String, dynamic>> mappedSubmissions = [];

                int currentMaxScore = 100;

                if (resSubs.statusCode == 200) {
                  final decoded = jsonDecode(resSubs.body);
                  List<dynamic> rawSubs = [];

                  if (decoded is Map<String, dynamic>) {
                    currentMaxScore = decoded['maxGrade'] as int? ?? 100;
                    rawSubs = decoded['submissions'] as List<dynamic>? ?? [];
                  } else if (decoded is List) {
                    rawSubs = decoded;
                  }

                  mappedSubmissions = rawSubs.map((s) {
                    final uid = s['userid'].toString();

                    // ¡ACÁ OCURRE LA MAGIA! Cruzamos el ID genérico con el nombre real de la lista
                    String finalName = s['studentName'] ?? 'Estudiante';
                    if (finalName.startsWith('Estudiante ID:') && realNamesMap.containsKey(uid)) {
                      finalName = realNamesMap[uid]!;
                    }

                    // Limpiamos las notas negativas que tira Moodle
                    String finalGrade = s['grade'] != null ? '${s['grade']}' : '';
                    if (finalGrade.isNotEmpty) {
                      final gradeValue = double.tryParse(finalGrade.split('/').first.trim()) ?? 0;
                      if (gradeValue < 0) {
                        finalGrade = '';
                      }
                    }

                    return {
                      'userid': uid,
                      'student': finalName,
                      'file': s['fileName'] ?? '',
                      'fileUrl': s['fileUrl'] ?? '',
                      'status': s['status'] == 'submitted' ? 'Entregado' : 'No entregado',
                      'grade': finalGrade,
                      'reviewed': s['reviewed'] == true,
                      'comment': s['comment'] ?? '',
                    };
                  }).toList();
                }

                int delivered = mappedSubmissions.where((s) => s['status'] == 'Entregado').length;
                int pending = mappedSubmissions.length - delivered;
                int reviewed = mappedSubmissions.where((s) => s['reviewed'] == true).length;

                foundTasks.add({
                  'assignid': assignId,
                  'week': section['name'] ?? 'Sección',
                  'activity': mod['name'] ?? 'Tarea',
                  'course': courseName,
                  'maxScore': currentMaxScore,
                  'delivered': delivered,
                  'pending': pending,
                  'reviewed': reviewed,
                  'submissions': mappedSubmissions,
                });
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          courseTasks = foundTasks;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          loadError = 'Error al conectar con Moodle. Intente más tarde.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar entregas'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
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
                  'Revisión por semanas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Seleccione una actividad para ver entregas, pendientes y revisiones del encuentro correspondiente.',
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
          const Text(
            'Actividades por revisar',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          if (loadError != null)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(loadError!,
                        style: const TextStyle(color: Colors.red)))),
          if (courseTasks.isEmpty && loadError == null)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No hay tareas configuradas en este curso o en sus materias.'))),
          ...courseTasks.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SubmissionGroupCard(
                moodleToken: widget.moodleToken,
                assignid: item['assignid'].toString(),
                week: item['week'] as String,
                activity: item['activity'] as String,
                course: item['course'] as String,
                maxScore: item['maxScore'] as int,
                delivered: item['delivered'] as int,
                pending: item['pending'] as int,
                reviewed: item['reviewed'] as int,
                submissions:
                item['submissions'] as List<Map<String, dynamic>>,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SubmissionGroupCard extends StatelessWidget {
  final String moodleToken;
  final String assignid;
  final String week;
  final String activity;
  final String course;
  final int maxScore;
  final int delivered;
  final int pending;
  final int reviewed;
  final List<Map<String, dynamic>> submissions;

  const SubmissionGroupCard({
    super.key,
    required this.moodleToken,
    required this.assignid,
    required this.week,
    required this.activity,
    required this.course,
    required this.maxScore,
    required this.delivered,
    required this.pending,
    required this.reviewed,
    required this.submissions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubmissionGroupDetailScreen(
                moodleToken: moodleToken,
                assignid: assignid,
                week: week,
                activity: activity,
                course: course,
                maxScore: maxScore,
                initialSubmissions: submissions,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3123B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: Color(0xFFB3123B),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$week · $activity',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          maxScore > 0
                              ? 'Puntaje máximo: $maxScore'
                              : 'Actividad sin calificación',
                          style: const TextStyle(
                            color: Color(0xFFB3123B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.black45,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _miniBox(
                      label: 'Entregados',
                      value: '$delivered',
                      icon: Icons.upload_file_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniBox(
                      label: 'Pendientes',
                      value: '$pending',
                      icon: Icons.schedule_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniBox(
                      label: 'Revisados',
                      value: '$reviewed',
                      icon: Icons.task_alt_rounded,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SubmissionGroupDetailScreen extends StatefulWidget {
  final String moodleToken;
  final String assignid;
  final String week;
  final String activity;
  final String course;
  final int maxScore;
  final List<Map<String, dynamic>> initialSubmissions;

  const SubmissionGroupDetailScreen({
    super.key,
    required this.moodleToken,
    required this.assignid,
    required this.week,
    required this.activity,
    required this.course,
    required this.maxScore,
    required this.initialSubmissions,
  });

  @override
  State<SubmissionGroupDetailScreen> createState() =>
      _SubmissionGroupDetailScreenState();
}

class _SubmissionGroupDetailScreenState
    extends State<SubmissionGroupDetailScreen> {
  late List<Map<String, dynamic>> submissions;

  @override
  void initState() {
    super.initState();
    submissions = widget.initialSubmissions
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final deliveredCount =
        submissions.where((item) => item['status'] == 'Entregado').length;
    final pendingCount = submissions.length - deliveredCount;
    final reviewedCount =
        submissions.where((item) => item['reviewed'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar entregas'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.week} · ${widget.activity}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.course,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.maxScore > 0
                      ? 'Puntaje máximo: ${widget.maxScore}'
                      : 'Actividad sin calificación',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.maxScore > 0
                      ? 'Revise archivos, seleccione la nota y agregue observaciones.'
                      : 'Revise archivos y agregue observaciones si lo desea.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _summaryBox(
                        label: 'Entregados',
                        value: '$deliveredCount',
                        icon: Icons.upload_file_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryBox(
                        label: 'Pendientes',
                        value: '$pendingCount',
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryBox(
                        label: 'Revisados',
                        value: '$reviewedCount',
                        icon: Icons.task_alt_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: submissions.length,
              itemBuilder: (context, index) {
                final item = submissions[index];
                return SubmissionCard(
                  student: item['student'] as String,
                  file: item['file'] as String,
                  fileUrl: item['fileUrl'] as String? ?? '',
                  status: item['status'] as String,
                  grade: item['grade'] as String,
                  reviewed: item['reviewed'] as bool,
                  comment: item['comment'] as String,
                  onReview: () async {
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubmissionDetailScreen(
                          moodleToken: widget.moodleToken,
                          assignid: widget.assignid,
                          userid: item['userid'] as String,
                          student: item['student'] as String,
                          file: item['file'] as String,
                          fileUrl: item['fileUrl'] as String? ?? '',
                          status: item['status'] as String,
                          maxScore: widget.maxScore,
                          initialGrade: item['grade'] as String,
                          initialComment: item['comment'] as String,
                        ),
                      ),
                    );

                    if (result != null) {
                      setState(() {
                        item['grade'] = result['grade'] as String;
                        item['comment'] = result['comment'] as String;
                        item['reviewed'] = true;
                      });
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class SubmissionCard extends StatelessWidget {
  final String student;
  final String file;
  final String fileUrl;
  final String status;
  final String grade;
  final bool reviewed;
  final String comment;
  final VoidCallback onReview;

  const SubmissionCard({
    super.key,
    required this.student,
    required this.file,
    required this.fileUrl,
    required this.status,
    required this.grade,
    required this.reviewed,
    required this.comment,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final isDelivered = status == 'Entregado';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3123B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      _initials(student),
                      style: const TextStyle(
                        color: Color(0xFFB3123B),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    student,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDelivered
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isDelivered ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow(
              icon: Icons.attach_file_rounded,
              text: file.isEmpty ? 'Sin archivo adjunto' : file,
            ),
            const SizedBox(height: 8),
            _infoRow(
              icon: Icons.grade_rounded,
              text: grade.isEmpty ? 'Sin calificación' : 'Nota: $grade',
            ),
            const SizedBox(height: 8),
            _infoRow(
              icon: reviewed
                  ? Icons.check_circle_rounded
                  : Icons.pending_actions_rounded,
              text: reviewed ? 'Revisado' : 'Pendiente de revisión',
              color: reviewed ? Colors.green : Colors.orange,
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Observación: $comment',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.rate_review_rounded),
                label: Text(reviewed ? 'Editar revisión' : 'Revisar entrega'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    Color color = Colors.black54,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    if (name.startsWith('Estudiante ID:')) return 'E';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class SubmissionDetailScreen extends StatefulWidget {
  final String moodleToken;
  final String assignid;
  final String userid;
  final String student;
  final String file;
  final String fileUrl;
  final String status;
  final int maxScore;
  final String initialGrade;
  final String initialComment;

  const SubmissionDetailScreen({
    super.key,
    required this.moodleToken,
    required this.assignid,
    required this.userid,
    required this.student,
    required this.file,
    required this.fileUrl,
    required this.status,
    required this.maxScore,
    required this.initialGrade,
    required this.initialComment,
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  late final TextEditingController commentController;
  int? selectedScore;
  bool isSaving = false;
  bool isOpeningFile = false;

  @override
  void initState() {
    super.initState();
    commentController = TextEditingController(text: widget.initialComment);

    if (widget.initialGrade.isNotEmpty) {
      final obtained = widget.initialGrade.split('/').first.trim();
      selectedScore =
          int.tryParse(obtained) ?? double.tryParse(obtained)?.toInt();

      if (selectedScore != null && selectedScore! < 0) {
        selectedScore = null;
      }
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _saveGrade() async {
    setState(() {
      isSaving = true;
    });

    try {
      final url = Uri.parse('${AppConfig.apiUrl}/teacher/assignment-grade');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.moodleToken,
          'assignid': widget.assignid,
          'userid': widget.userid,
          'grade': selectedScore ?? 0,
          'comment': commentController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calificación guardada exitosamente')),
        );
        Navigator.pop(
          context,
          {
            'grade': selectedScore == null ? '' : '$selectedScore',
            'comment': commentController.text.trim(),
          },
        );
      } else {
        // ¡LA LUPA ESPÍA!: Si falla, intentamos leer qué dice el servidor
        final data = jsonDecode(response.body);
        final detail = data['detail'] != null ? jsonEncode(data['detail']) : 'Sin detalles';
        throw Exception('Moodle rechazó la nota. \nRespuesta: $detail');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10), // Tiempo para leer el error
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
    final isDelivered = widget.status == 'Entregado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de entrega'),
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
            child: Text(
              widget.student,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información de la entrega',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _detailInfoRow(
                    icon: Icons.attach_file_rounded,
                    text: widget.file.isEmpty
                        ? 'No se adjuntó archivo'
                        : widget.file,
                  ),
                  const SizedBox(height: 10),
                  _detailInfoRow(
                    icon: Icons.info_rounded,
                    text: widget.status,
                    color: isDelivered ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  _detailInfoRow(
                    icon: Icons.stars_rounded,
                    text: widget.maxScore > 0
                        ? 'Puntaje máximo: ${widget.maxScore}'
                        : 'Actividad sin calificación',
                    color: const Color(0xFFB3123B),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: (isDelivered && widget.fileUrl.isNotEmpty && !isOpeningFile)
                        ? () async {
                      setState(() { isOpeningFile = true; });
                      try {
                        final urlString = '${widget.fileUrl}?token=${widget.moodleToken}';

                        final response = await http.get(Uri.parse(urlString));
                        if (response.statusCode == 200) {
                          final dir = await getTemporaryDirectory();
                          final safeFileName = widget.file.replaceAll(' ', '_');
                          final localFile = File('${dir.path}/$safeFileName');
                          await localFile.writeAsBytes(response.bodyBytes);

                          if (!context.mounted) return;
                          setState(() { isOpeningFile = false; });

                          final nameLower = safeFileName.toLowerCase();

                          if (nameLower.endsWith('.pdf')) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: Text(widget.file)),
                                  body: SfPdfViewer.file(localFile),
                                ),
                              ),
                            );
                          } else if (nameLower.endsWith('.jpg') || nameLower.endsWith('.jpeg') || nameLower.endsWith('.png')) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: Text(widget.file),
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                  ),
                                  backgroundColor: Colors.black,
                                  body: InteractiveViewer(
                                    minScale: 0.1,
                                    maxScale: 4.0,
                                    child: Center(
                                      child: Image.file(localFile),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            final uri = Uri.parse(urlString);
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        } else {
                          throw Exception('Fallo al descargar');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() { isOpeningFile = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error al procesar el archivo')),
                          );
                        }
                      }
                    }
                        : null,
                    icon: isOpeningFile
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.visibility_rounded),
                    label: Text(isOpeningFile ? 'Cargando archivo...' : 'Ver archivo'),
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
                  if (widget.maxScore > 0) ...[
                    DropdownButtonFormField<int>(
                      value: selectedScore,
                      items: List.generate(
                        widget.maxScore + 1,
                            (index) => DropdownMenuItem(
                          value: index,
                          child: Text('$index / ${widget.maxScore}'),
                        ),
                      ),
                      onChanged: isDelivered
                          ? (value) {
                        setState(() {
                          selectedScore = value;
                        });
                      }
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Calificación',
                        prefixIcon: const Icon(Icons.grade_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Observación del docente',
                      hintText: 'Escriba una devolución o comentario',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 64),
                        child: Icon(Icons.comment_rounded),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                      isSaving ? null : (isDelivered ? _saveGrade : null),
                      icon: isSaving
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label:
                      Text(isSaving ? 'Guardando...' : 'Guardar revisión'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailInfoRow({
    required IconData icon,
    required String text,
    Color color = Colors.black87,
  }) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}