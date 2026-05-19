import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Asegurate de tener intl en tu pubspec.yaml
import 'package:intl/date_symbol_data_local.dart';
import 'attendance_detail_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class AttendanceScreen extends StatefulWidget {
  final String moodleToken;
  final String courseId;
  final String courseName;
  final bool isTeacherView;

  const AttendanceScreen({
    super.key,
    required this.moodleToken,
    required this.courseId,
    required this.courseName,
    required this.isTeacherView,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> sessions = [];
  Map<String, dynamic>? studentSummary;

  // --- NUEVO: Necesitamos el ID del alumno para el auto-registro ---
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null).then((_) {
      _loadAttendanceData();
    });
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Pedimos la lista de clases al servidor
      final url = Uri.parse(
          '${AppConfig.apiUrl}/attendance-sessions?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=${widget.courseId}');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        print('🔥🔥 RESPUESTA DEL SERVIDOR: ${response.body}');
        throw Exception('Error al cargar las sesiones');
      }

      final List<dynamic> data = jsonDecode(response.body);
      sessions = data.map((e) => Map<String, dynamic>.from(e)).toList();

      // 2. Si es ALUMNO, pedimos su porcentaje de asistencia y su ID
      if (!widget.isTeacherView) {
        // Pedimos info del usuario para sacar su ID
        final siteInfoUrl = Uri.parse('${AppConfig.apiUrl}/site-info?token=${Uri.encodeComponent(widget.moodleToken)}');
        final siteInfoResponse = await http.get(siteInfoUrl);
        if (siteInfoResponse.statusCode == 200) {
          final siteInfo = jsonDecode(siteInfoResponse.body);
          currentUserId = siteInfo['userid']?.toString();
        }

        if (sessions.isNotEmpty) {
          final summaryUrl = Uri.parse(
              '${AppConfig.apiUrl}/attendance-my-status?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=${widget.courseId}');
          final summaryResponse = await http.get(summaryUrl);
          if (summaryResponse.statusCode == 200) {
            studentSummary = jsonDecode(summaryResponse.body);
          }
        }
      }
    } catch (e) {
      print('🔥🔥 ERROR FATAL EN ASISTENCIA: $e');
      errorMessage = 'No se pudo cargar el registro de asistencia.';
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // --- NUEVA FUNCIÓN PARA EL ALUMNO: Auto-registrarse ---
  Future<void> _marcarAsistenciaAlumno(String sessionId) async {
    print('🕵️‍♂️ ESPÍA ALUMNO - ID DE USUARIO ACTUAL: $currentUserId'); // <--- ESPÍA AGREGADO AQUÍ

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar tu usuario')),
      );
      return;
    }

    // Mostramos un circulito de carga mientras envía
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final url = Uri.parse('${AppConfig.apiUrl}/student-attendance-submit');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionid': sessionId,
          'studentid': currentUserId,
          'statusid': 0, // Mandamos 0 para que el servidor busque el ID real de "Presente"
        }),
      );

      Navigator.pop(context); // Ocultar el circulito de carga

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Presente registrado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAttendanceData(); // Recargar la lista para que se vea verde
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Error desconocido');
      }
    } catch (e) {
      print('🔥🔥 ERROR AL INTENTAR MARCAR PRESENTE: $e'); // <--- ESPÍA AGREGADO AQUÍ

      if (mounted) {
        // Asegurarnos de cerrar el circulito si hubo error antes del pop
        if (Navigator.canPop(context)) Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo marcar asistencia. Tal vez el profesor aún no habilitó la clase o ya pasó el tiempo.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  // ------------------------------------------------------

  // Función para convertir la fecha rara de Moodle a texto legible
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

    return '${days[date.weekday - 1]} ${date.day} de ${months[date.month - 1]} ${date.year}';
  }

  String _getStudentStatusForSession(int sessionId) {
    if (studentSummary == null || studentSummary!['statuses'] == null) return 'Pendiente';

    final history = studentSummary!['statuses'] as List<dynamic>? ?? [];
    for (var record in history) {
      if (record['sessionid'] == sessionId) {
        return (record['description'] ?? 'Registrada').toString();
      }
    }
    return 'Pendiente';
  }

  @override
  Widget build(BuildContext context) {

    // --- ESPÍA PARA VER LA ESTRUCTURA REAL QUE MANDA MOODLE ---
    print('🕵️‍♂️ CHISMOSO MOODLE - HISTORIAL: ${studentSummary?.toString()}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      )
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isTeacherView ? 'Registro Docente' : 'Mi Asistencia',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sessions.isEmpty
                      ? 'Este curso no utiliza el registro de asistencia.'
                      : widget.isTeacherView
                      ? 'Seleccione un encuentro para tomar lista a los alumnos.'
                      : (studentSummary != null && studentSummary!['summary'] != null)
                      ? 'Porcentaje actual: ${studentSummary!['summary']['percentage'] ?? '0'}%'
                      : 'Revisá tus presentes y ausentes del curso.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (sessions.isEmpty)
            Card(
              elevation: 0,
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 48, color: Colors.orange.shade800),
                    const SizedBox(height: 16),
                    Text(
                      'Sin registro oficial',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Este curso no tiene configurado el módulo oficial de asistencia de Moodle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Text(
              'Clases programadas',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ...sessions.map((sess) {
              final timestamp = int.tryParse(sess['sessdate'].toString()) ?? 0;
              final dateString = _formatDate(timestamp);
              final description = (sess['description'] ?? 'Clase regular').toString();

              final isTaken = (sess['lasttaken'] ?? 0) > 0;
              String statusText = '';

              if (widget.isTeacherView) {
                statusText = isTaken ? 'Lista tomada' : 'Pendiente';
              } else {
                statusText = _getStudentStatusForSession(sess['id']);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AttendanceClassCard(
                  title: description,
                  date: dateString,
                  course: widget.courseName,
                  status: statusText,
                  isTaken: isTaken,
                  isTeacherView: widget.isTeacherView,
                  onTap: () {
                    if (widget.isTeacherView) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttendanceDetailScreen(
                            classTitle: description,
                            classDate: dateString,
                            courseName: widget.courseName,
                            // Magia: pasamos token y ID de la sesión para que busque alumnos reales
                            moodleToken: widget.moodleToken,
                            sessionId: sess['id'].toString(),
                          ),
                        ),
                      ).then((_) => _loadAttendanceData());
                    } else {
                      // --- NUEVA LÓGICA PARA EL ALUMNO ---
                      if (statusText == 'Pendiente') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Marcar asistencia'),
                            content: const Text('¿Estás presente en esta clase?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // Cierra el cuadro de diálogo
                                  _marcarAsistenciaAlumno(sess['id'].toString()); // Dispara el auto-registro
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB3123B)),
                                child: const Text('Sí, marcar Presente', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Si ya tiene falta o presente, solo le avisamos
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Estado de esta clase: $statusText')),
                        );
                      }
                      // ------------------------------------
                    }
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class AttendanceClassCard extends StatelessWidget {
  final String title;
  final String date;
  final String course;
  final String status;
  final bool isTaken;
  final bool isTeacherView;
  final VoidCallback onTap;

  const AttendanceClassCard({
    super.key,
    required this.title,
    required this.date,
    required this.course,
    required this.status,
    required this.isTaken,
    required this.isTeacherView,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor = const Color(0xFFB3123B);
    Color statusColor = Colors.orange;
    IconData icon = Icons.event_note_rounded;

    if (isTeacherView) {
      if (isTaken) {
        iconColor = Colors.green;
        statusColor = Colors.green;
        icon = Icons.task_alt_rounded;
      }
    } else {
      if (status.toLowerCase().contains('presente')) {
        iconColor = Colors.green;
        statusColor = Colors.green;
        icon = Icons.check_circle_rounded;
      } else if (status.toLowerCase().contains('ausente') || status.toLowerCase().contains('falta')) {
        iconColor = Colors.red;
        statusColor = Colors.red;
        icon = Icons.cancel_rounded;
      } else if (status.toLowerCase().contains('tarde') || status.toLowerCase().contains('justificad')) {
        iconColor = Colors.amber.shade800;
        statusColor = Colors.amber.shade800;
        icon = Icons.warning_rounded;
      }
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                course,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        isThreeLine: true,
        // Al alumno le mostramos la flechita si la clase está "Pendiente" para que sepa que puede tocarla
        trailing: (isTeacherView || status == 'Pendiente')
            ? const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black45)
            : null,
        onTap: onTap,
      ),
    );
  }
}