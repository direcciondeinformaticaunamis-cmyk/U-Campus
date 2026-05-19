import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class GradesScreen extends StatefulWidget {
  final String moodleToken;
  final String courseId;

  const GradesScreen({
    super.key,
    required this.moodleToken,
    required this.courseId,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  bool isLoading = true;
  String? loadError;
  List<dynamic> rawGrades = [];

  String overallAverage = '--';
  int gradedCount = 0;
  int totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    if (widget.moodleToken.isEmpty || widget.courseId.isEmpty) {
      setState(() {
        isLoading = false;
        loadError = 'Faltan datos del curso para cargar las calificaciones.';
      });
      return;
    }

    try {
      final url = Uri.parse(
        '${AppConfig.apiUrl}/course-grades?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=${widget.courseId}',
      );

      final response = await http.get(url);

      // --- ESPÍA AGREGADO AQUÍ ---
      if (response.statusCode == 200) {
        print('🕵️‍♂️ CHISMOSO DE NOTAS: ${response.body}');

        final data = jsonDecode(response.body);
        if (data is List) {
          _processGradesData(data);
        } else {
          throw Exception('Formato de datos incorrecto');
        }
      } else {
        throw Exception('Falló la carga desde Moodle');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        loadError = 'No se pudieron cargar las calificaciones.';
      });
    }
  }

  void _processGradesData(List<dynamic> items) {
    // Filtramos los items: nos quedamos solo con actividades ("mod"), y separamos el total del curso
    final List<dynamic> processedActivities = [];
    int graded = 0;

    for (var item in items) {
      final itemType = (item['itemtype'] ?? '').toString();

      // Si es el total del curso, sacamos el porcentaje para el banner
      if (itemType == 'course') {
        final percentFormatted = (item['percentageformatted'] ?? '').toString();
        if (percentFormatted.isNotEmpty && percentFormatted != '-') {
          overallAverage = percentFormatted;
        }
      }
      // Si es un módulo (tarea, quiz, foro calificado, asistencia) lo agregamos a la lista
      else if (itemType == 'mod') {
        processedActivities.add(item);

        // ¡RADAR MEJORADO! Buscamos la nota en varios campos porque Moodle esconde la asistencia
        final raw = item['graderaw'];
        final String gradeFmt = (item['gradeformatted'] ?? '-').toString().trim();
        final String percFmt = (item['percentageformatted'] ?? '-').toString().trim();

        final bool isGraded = raw != null ||
            (gradeFmt != '-' && gradeFmt.isNotEmpty && gradeFmt != 'null') ||
            (percFmt != '-' && percFmt.isNotEmpty && percFmt != 'null');

        if (isGraded) {
          graded++;
        }
      }
    }

    setState(() {
      rawGrades = processedActivities;
      totalCount = processedActivities.length;
      gradedCount = graded;
      isLoading = false;
    });
  }

  String _formatDate(dynamic timestampStr) {
    if (timestampStr == null) return '--';
    try {
      final int timestamp = timestampStr is int ? timestampStr : int.parse(timestampStr.toString());
      if (timestamp <= 0) return '--';
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificaciones'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen académico',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Consulte el estado de sus entregas, notas y observaciones del docente.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GradeSummaryBox(
                        label: 'Promedio general',
                        value: overallAverage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradeSummaryBox(
                        label: 'Actividades',
                        value: '$gradedCount / $totalCount',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mis actividades',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          if (loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  loadError!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else if (rawGrades.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay actividades calificables configuradas para este curso.',
                ),
              ),
            )
          else
            ...rawGrades.map((gradeItem) {

              final String title = (gradeItem['itemname'] ?? 'Actividad').toString();
              final String moduleName = (gradeItem['itemmodule'] ?? '').toString();

              // Evaluamos con el radar mejorado
              final raw = gradeItem['graderaw'];
              final String gradeFmt = (gradeItem['gradeformatted'] ?? '-').toString().trim();
              final String percFmt = (gradeItem['percentageformatted'] ?? '-').toString().trim();

              final bool hasGrade = raw != null ||
                  (gradeFmt != '-' && gradeFmt.isNotEmpty && gradeFmt != 'null') ||
                  (percFmt != '-' && percFmt.isNotEmpty && percFmt != 'null');

              // Asignamos la nota visualizando primero el formato, luego el porcentaje y al final el raw
              String finalScore = '--';
              if (hasGrade) {
                if (gradeFmt != '-' && gradeFmt.isNotEmpty && gradeFmt != 'null') {
                  finalScore = gradeFmt;
                } else if (percFmt != '-' && percFmt.isNotEmpty && percFmt != 'null') {
                  finalScore = percFmt;
                } else if (raw != null) {
                  finalScore = raw.toString();
                }
              }

              // La fecha de calificación si existe
              final String dateStr = _formatDate(gradeItem['gradedatesubmitted'] ?? gradeItem['gradedategraded']);

              // El feedback del profesor
              final String feedbackHtml = (gradeItem['feedback'] ?? '').toString();

              // Asignamos colores según el módulo
              Color cardColor = const Color(0xFF1E88E5); // Azul por defecto
              if (moduleName == 'assign') cardColor = const Color(0xFF8E24AA); // Tareas = morado
              if (moduleName == 'quiz') cardColor = const Color(0xFFF9A825); // Cuestionario = amarillo
              if (moduleName == 'forum') cardColor = const Color(0xFF43A047); // Foro = verde
              if (moduleName == 'attendance') cardColor = const Color(0xFFE53935); // Asistencia = rojo

              return GradeCompactCard(
                title: title,
                type: moduleName.toUpperCase(),
                score: hasGrade ? finalScore : '--',
                status: hasGrade ? 'Calificado' : 'Pendiente de revisión',
                date: dateStr,
                feedback: feedbackHtml,
                color: cardColor,
              );
            }),
        ],
      ),
    );
  }
}

class GradeSummaryBox extends StatelessWidget {
  final String label;
  final String value;

  const GradeSummaryBox({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class GradeCompactCard extends StatelessWidget {
  final String title;
  final String type;
  final String score;
  final String status;
  final String date;
  final String feedback;
  final Color color;

  const GradeCompactCard({
    super.key,
    required this.title,
    required this.type,
    required this.score,
    required this.status,
    required this.date,
    required this.feedback,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isReviewed = status == 'Calificado';
    final isPending = status == 'Pendiente de revisión';

    Color statusColor;
    Color statusBg;

    if (isReviewed) {
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade100;
    } else if (isPending) {
      statusColor = Colors.orange.shade700;
      statusBg = Colors.orange.shade100;
    } else {
      statusColor = Colors.red.shade700;
      statusBg = Colors.red.shade100;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getIconForType(type.toLowerCase()),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.isEmpty ? 'ACTIVIDAD' : type,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _smallInfo(
                    icon: Icons.calendar_month_rounded,
                    text: date,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _smallInfo(
                    icon: Icons.grade_rounded,
                    text: score == '--' ? 'Sin nota' : score,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: feedback.isEmpty
                  ? const Text(
                'Sin observaciones del docente.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              )
                  : HtmlWidget(
                feedback,
                textStyle: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallInfo({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFB3123B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    if (type.contains('assign')) return Icons.assignment_rounded;
    if (type.contains('forum')) return Icons.forum_rounded;
    if (type.contains('quiz')) return Icons.quiz_rounded;
    if (type.contains('attendance')) return Icons.how_to_reg_rounded;
    return Icons.grade_rounded;
  }
}