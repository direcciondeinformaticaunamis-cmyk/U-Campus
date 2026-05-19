import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'forum_detail_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class NoticesScreen extends StatefulWidget {
  final String moodleToken;

  const NoticesScreen({
    super.key,
    required this.moodleToken,
  });

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> realNotices = [];

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    try {
      final coursesUrl = Uri.parse(
          '${AppConfig.apiUrl}/my-courses?token=${Uri.encodeComponent(widget.moodleToken)}');
      final coursesRes = await http.get(coursesUrl);

      if (coursesRes.statusCode == 200) {
        final courses = jsonDecode(coursesRes.body) as List;
        List<Map<String, dynamic>> allNotices = [];

        for (var course in courses) {
          final contentsUrl = Uri.parse(
              '${AppConfig.apiUrl}/course-contents?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=${course['id']}');
          final contentsRes = await http.get(contentsUrl);

          if (contentsRes.statusCode == 200) {
            final contents = jsonDecode(contentsRes.body) as List;
            for (var section in contents) {
              final modules = section['modules'] as List? ?? [];
              for (var mod in modules) {

                final modName = (mod['name'] ?? '').toString().toLowerCase();
                final isAnnouncementsForum = modName.contains('aviso') ||
                    modName.contains('novedad') ||
                    modName.contains('anuncio');

                if (mod['modname'] == 'forum' && isAnnouncementsForum) {
                  // Ya no hacemos otra petición para buscar los mensajes adentro.
                  // Simplemente guardamos la "Sala" (el foro) para que el alumno entre.

                  final subject = (mod['name'] ?? 'Avisos').toString();
                  final description = mod['description'] != null
                      ? _stripHtml(mod['description'].toString())
                      : 'Sala de comunicación del curso';

                  final moduleData = Map<String, dynamic>.from(mod);
                  moduleData['usertoken'] = widget.moodleToken;
                  // ¡LA INYECCIÓN MÁGICA! Pasamos el ID del curso.
                  moduleData['course'] = course['id'];

                  allNotices.add({
                    'title': subject,
                    'course': course['fullname'] ?? 'Curso',
                    'description': description,
                    'date': 'Sala activa',
                    'timestamp': course['id'],
                    'type': 'Aviso',
                    'moduleData': moduleData,
                  });
                }
              }
            }
          }
        }

        allNotices.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

        if (mounted) {
          setState(() {
            realNotices = allNotices;
            isLoading = false;
          });
        }
      } else {
        throw Exception('Error al cargar cursos');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _stripHtml(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return 'Fecha desconocida';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _determineType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('importante') || lower.contains('urgente') || lower.contains('atención')) return 'Importante';
    if (lower.contains('fecha') || lower.contains('entrega') || lower.contains('tarea') || lower.contains('recordatorio')) return 'Recordatorio';
    if (lower.contains('material') || lower.contains('unidad') || lower.contains('guía') || lower.contains('recurso')) return 'Material';
    if (lower.contains('clase') || lower.contains('sincrónica') || lower.contains('teams') || lower.contains('encuentro')) return 'Clase';
    return 'Aviso';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
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
                  'Avisos y novedades',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Manténgase al día con anuncios, recordatorios y novedades del aula virtual.',
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
            'Salas de comunicación',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          if (realNotices.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No hay salas de avisos disponibles.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),
              ),
            )
          else
            ...realNotices.map(
                  (notice) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: NoticeCard(
                  title: notice['title'] as String,
                  course: notice['course'] as String,
                  description: notice['description'] as String,
                  date: notice['date'] as String,
                  type: notice['type'] as String,
                  moduleData: notice['moduleData'] as Map<String, dynamic>,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NoticeCard extends StatelessWidget {
  final String title;
  final String course;
  final String description;
  final String date;
  final String type;
  final Map<String, dynamic> moduleData;

  const NoticeCard({
    super.key,
    required this.title,
    required this.course,
    required this.description,
    required this.date,
    required this.type,
    required this.moduleData,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor(type);
    final icon = _getTypeIcon(type);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ForumDetailScreen(
                forumTitle: title,
                forumData: moduleData,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course,
                      style: const TextStyle(
                        color: Color(0xFFB3123B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Importante':
        return Icons.priority_high_rounded;
      case 'Recordatorio':
        return Icons.notifications_active_rounded;
      case 'Material':
        return Icons.menu_book_rounded;
      case 'Clase':
        return Icons.video_call_rounded;
      case 'Aviso':
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Importante':
        return Colors.red;
      case 'Recordatorio':
        return Colors.orange;
      case 'Material':
        return Colors.blue;
      case 'Clase':
        return Colors.green;
      case 'Aviso':
      default:
        return const Color(0xFFAB47BC);
    }
  }
}