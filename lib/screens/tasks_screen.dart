import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'task_submission_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class TasksScreen extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;
  final String moodleToken;

  const TasksScreen({
    super.key,
    this.tasks = const [],
    this.moodleToken = '',
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool isLoading = false;
  List<Map<String, dynamic>> fetchedTasks = [];

  @override
  void initState() {
    super.initState();
    // Si pasamos token, buscamos las tareas de verdad
    if (widget.tasks.isEmpty && widget.moodleToken.isNotEmpty) {
      _loadRealTasks();
    } else {
      fetchedTasks = widget.tasks;
    }
  }

  Future<void> _loadRealTasks() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1. Buscamos los cursos del usuario
      final crsRes = await http.get(Uri.parse(
          '${AppConfig.apiUrl}/my-courses?token=${Uri.encodeComponent(widget.moodleToken)}'));
      if (crsRes.statusCode != 200) throw Exception();
      final courses = jsonDecode(crsRes.body) as List;

      List<Map<String, dynamic>> realTasks = [];

      // 2. Por cada curso, buscamos sus contenidos y extraemos las tareas ('assign')
      for (var c in courses) {
        final cid = c['id'];
        final cname = c['fullname'] ?? 'Curso';

        final contRes = await http.get(Uri.parse(
            '${AppConfig.apiUrl}/course-contents?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=$cid'));
        if (contRes.statusCode == 200) {
          final contents = jsonDecode(contRes.body) as List;
          for (var sec in contents) {
            final mods = sec['modules'] as List? ?? [];
            for (var m in mods) {
              if (m['modname'] == 'assign') {
                final modData = Map<String, dynamic>.from(m);
                // Le inyectamos la info necesaria para que la TaskSubmissionScreen no tire error rojo
                modData['usertoken'] = widget.moodleToken;
                modData['courseid'] = cid;
                modData['cmid'] = m['id'];

                final assignInstanceId = m['instance'].toString();

                // 3. ¡MAGIA NUEVA! Consultamos el estado real de ESTA tarea específica
                String finalStatus = 'Pendiente';

                try {
                  final statusRes = await http.get(Uri.parse(
                      '${AppConfig.apiUrl}/assignment-status?token=${Uri.encodeComponent(widget.moodleToken)}&assignid=$assignInstanceId'));

                  if (statusRes.statusCode == 200) {
                    final statusData = jsonDecode(statusRes.body);
                    final subStatus = (statusData['submissionstatus'] ?? '').toString().toLowerCase();

                    if (subStatus == 'submitted' || subStatus == 'submittedearly' || statusData['submitted'] == true) {
                      finalStatus = 'Entregado';
                    }
                  }
                } catch (e) {
                  // Si falla la consulta, lo dejamos como Pendiente por defecto para no romper la app
                  debugPrint('Error consultando estado de tarea $assignInstanceId: $e');
                }

                realTasks.add({
                  'title': m['name'],
                  'course': cname,
                  'date': 'Vence próximamente',
                  'status': finalStatus, // ¡USAMOS EL ESTADO REAL AQUÍ!
                  'icon': Icons.assignment_rounded,
                  'color': const Color(0xFFB3123B),
                  'subtitle': sec['name'] ?? 'Sección',
                  'moduleData': modData,
                });
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          fetchedTasks = realTasks;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFallbackTasks() {
    return [
      {
        'title': 'Tarea 1',
        'course': 'Control de Proyectos',
        'date': 'Vence próximamente',
        'status': 'Pendiente',
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFFB3123B),
        'subtitle': 'Curso',
        'moduleData': <String, dynamic>{},
      },
    ];
  }

  List<Map<String, dynamic>> _normalizeTasks() {
    final source = fetchedTasks.isEmpty && widget.moodleToken.isEmpty
        ? _getFallbackTasks()
        : fetchedTasks;

    return source.map((task) {
      final title = (task['title'] ?? task['name'] ?? 'Actividad').toString();
      final course = (task['course'] ?? 'Curso').toString();
      final subtitle = (task['subtitle'] ?? course).toString();

      String date = 'Sin fecha visible';
      final dueDate = task['duedate'];
      if (dueDate != null) {
        try {
          final int timestamp = dueDate is int
              ? dueDate
              : int.parse(dueDate.toString());
          final d = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          date = 'Vence: ${d.day}/${d.month}/${d.year}';
        } catch (_) {
          date = dueDate.toString();
        }
      } else if (task['date'] != null) {
        date = task['date'].toString();
      }

      final status = (task['status'] ?? 'Pendiente').toString();

      return {
        'title': title,
        'course': course,
        'date': date,
        'status': status,
        'icon': task['icon'] ?? Icons.assignment_rounded,
        'color': task['color'] ?? const Color(0xFFB3123B),
        'subtitle': subtitle,
        'moduleData': task['moduleData'] ?? task,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedTasks = _normalizeTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas'),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actividades',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Revise fechas, estados y entregue sus actividades a tiempo.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Lista de tareas (${normalizedTasks.length})',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          if (normalizedTasks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay tareas para mostrar.'),
              ),
            )
          else
            ...normalizedTasks.map(
                  (task) => TaskCard(
                title: task['title'].toString(),
                course: task['course'].toString(),
                date: task['date'].toString(),
                status: task['status'].toString(),
                icon: task['icon'] as IconData,
                color: task['color'] as Color,
                subtitle: task['subtitle'].toString(),
                moduleData:
                task['moduleData'] as Map<String, dynamic>? ?? {},
              ),
            ),
        ],
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final String title;
  final String course;
  final String date;
  final String status;
  final IconData icon;
  final Color color;
  final String subtitle;
  final Map<String, dynamic> moduleData;

  const TaskCard({
    super.key,
    required this.title,
    required this.course,
    required this.date,
    required this.status,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.moduleData,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'Pendiente';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // Refrescamos la pantalla al volver por si el alumno entregó la tarea
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskSubmissionScreen(
                title: title,
                subtitle: subtitle,
                moduleData: moduleData,
              ),
            ),
          ).then((_) {
            // Forzamos un setState indirecto si tuvieramos un callback,
            // pero al salir y volver a entrar a esta pantalla desde el Home se refrescará.
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: isPending
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}