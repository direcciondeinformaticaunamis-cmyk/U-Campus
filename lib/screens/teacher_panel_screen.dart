import 'package:flutter/material.dart';
import 'attendance_screen.dart';
import 'upload_material_screen.dart';
import 'create_task_screen.dart';
import 'create_notice_screen.dart';
import 'review_submissions_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class TeacherPanelScreen extends StatefulWidget {
  final String moodleToken;
  final String courseId;

  const TeacherPanelScreen({
    super.key,
    required this.moodleToken,
    required this.courseId,
  });

  @override
  State<TeacherPanelScreen> createState() => _TeacherPanelScreenState();
}

class _TeacherPanelScreenState extends State<TeacherPanelScreen> {
  final List<Map<String, dynamic>> createdTasks = [];
  final List<Map<String, dynamic>> recentActions = [
    {
      'title': 'Material subido',
      'description': 'Se cargó el archivo "Unidad 2 - Introducción.pdf".',
      'time': 'Hoy, 08:45',
      'icon': Icons.upload_file_rounded,
      'color': const Color(0xFF1E88E5),
    },
    {
      'title': 'Asistencia registrada',
      'description': 'Se guardó la asistencia de la clase del martes.',
      'time': 'Ayer, 10:05',
      'icon': Icons.how_to_reg_rounded,
      'color': const Color(0xFF26A69A),
    },
    {
      'title': 'Aviso publicado',
      'description':
      'Se notificó a los estudiantes sobre el cambio de fecha.',
      'time': 'Ayer, 08:10',
      'icon': Icons.campaign_rounded,
      'color': const Color(0xFFAB47BC),
    },
  ];

  Future<void> _openCreateTaskScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateTaskScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        createdTasks.insert(0, result);

        final title = (result['title'] as String?) ?? 'Nueva tarea';
        final dueDate = (result['dueDate'] as String?) ?? 'Sin fecha';
        final graded = (result['graded'] as bool?) ?? false;
        final maxScore = (result['maxScore'] as int?) ?? 0;

        recentActions.insert(0, {
          'title': 'Tarea creada',
          'description': graded
              ? 'Se publicó "$title" con calificación sobre $maxScore puntos.'
              : 'Se publicó "$title" sin calificación.',
          'time': dueDate.isEmpty ? 'Hoy' : dueDate,
          'icon': Icons.post_add_rounded,
          'color': const Color(0xFFF9A825),
        });
      });

      if (!mounted) return;

      final title = result['title'] as String? ?? 'Nueva tarea';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tarea "$title" creada correctamente'),
        ),
      );
    }
  }

  void _showGlobalWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Por favor, ingrese al Panel Docente desde un curso específico para usar esta herramienta.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTasks = 7 + createdTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Docente'),
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
                  'Herramientas del docente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Gestione materiales, tareas, avisos, asistencia y revisión de entregas.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Acciones rápidas',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.02,
            children: [
              TeacherActionCard(
                icon: Icons.upload_file_rounded,
                title: 'Subir material',
                subtitle: 'PDF, PPT, videos',
                color: const Color(0xFF7DB7FF),
                onTap: () {
                  if (widget.courseId == '0') {
                    _showGlobalWarning();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UploadMaterialScreen(),
                    ),
                  );
                },
              ),
              TeacherActionCard(
                icon: Icons.post_add_rounded,
                title: 'Crear tarea',
                subtitle: 'Nueva actividad',
                color: const Color(0xFFFFD180),
                onTap: () {
                  if (widget.courseId == '0') {
                    _showGlobalWarning();
                    return;
                  }
                  _openCreateTaskScreen();
                },
              ),
              TeacherActionCard(
                icon: Icons.how_to_reg_rounded,
                title: 'Asistencia',
                subtitle: 'Marcar presentes',
                color: const Color(0xFF80DEEA),
                onTap: () {
                  if (widget.courseId == '0') {
                    _showGlobalWarning();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AttendanceScreen(
                        moodleToken: widget.moodleToken,
                        courseId: widget.courseId,
                        courseName: 'Curso actual',
                        isTeacherView: true,
                      ),
                    ),
                  );
                },
              ),
              TeacherActionCard(
                icon: Icons.campaign_rounded,
                title: 'Crear aviso',
                subtitle: 'Enviar anuncio',
                color: const Color(0xFFCE93D8),
                onTap: () {
                  if (widget.courseId == '0') {
                    _showGlobalWarning();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // ¡ACÁ ESTÁ EL CAMBIO! Le pasamos el token y el ID del curso
                      builder: (context) => CreateNoticeScreen(
                        moodleToken: widget.moodleToken,
                        courseId: widget.courseId,
                      ),
                    ),
                  );
                },
              ),
              TeacherActionCard(
                icon: Icons.rate_review_rounded,
                title: 'Revisar entregas',
                subtitle: 'Calificar tareas',
                color: const Color(0xFFA5D6A7),
                onTap: () {
                  if (widget.courseId == '0') {
                    _showGlobalWarning();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReviewSubmissionsScreen(
                        createdTasks: createdTasks,
                        moodleToken: widget.moodleToken,
                        courseId: widget.courseId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Resumen docente',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: TeacherStatCard(
                  label: 'Cursos',
                  value: '4', // Este sí lo podemos conectar a la base luego
                  icon: Icons.menu_book_rounded,
                  color: Color(0xFF7DB7FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TeacherStatCard(
                  label: 'Tareas',
                  value: '$totalTasks',
                  icon: Icons.assignment_rounded,
                  color: const Color(0xFFFFD180),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: TeacherStatCard(
                  label: 'Entregas',
                  value: '18',
                  icon: Icons.upload_file_rounded,
                  color: Color(0xFFA5D6A7),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TeacherStatCard(
                  label: 'Avisos',
                  value: '5',
                  icon: Icons.notifications_rounded,
                  color: Color(0xFFCE93D8),
                ),
              ),
            ],
          ),
          if (createdTasks.isNotEmpty) ...[
            const SizedBox(height: 26),
            const Text(
              'Tareas creadas en esta sesión',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ...createdTasks.map(
                  (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CreatedTaskCard(task: task),
              ),
            ),
          ],
          const SizedBox(height: 26),
          const Text(
            'Acciones recientes',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ...recentActions.map(
                (action) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TeacherRecentActionCard(
                title: action['title'] as String,
                description: action['description'] as String,
                time: action['time'] as String,
                icon: action['icon'] as IconData,
                color: action['color'] as Color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const TeacherActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.black87),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeacherStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const TeacherStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeacherRecentActionCard extends StatelessWidget {
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color color;

  const TeacherRecentActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$description\n$time'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _CreatedTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;

  const _CreatedTaskCard({
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final title = task['title'] as String? ?? 'Sin título';
    final type = task['type'] as String? ?? 'Actividad';
    final dueDate = task['dueDate'] as String? ?? 'Sin fecha';
    final graded = task['graded'] as bool? ?? false;
    final maxScore = task['maxScore'] as int? ?? 0;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD180).withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.assignment_rounded,
            color: Color(0xFFB3123B),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            graded
                ? '$type · $dueDate · sobre $maxScore puntos'
                : '$type · $dueDate · sin calificación',
          ),
        ),
      ),
    );
  }
}