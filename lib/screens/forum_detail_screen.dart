import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'add_forum_post_screen.dart';
import '../config.dart';

class ForumDetailScreen extends StatefulWidget {
  final String forumTitle;
  final Map<String, dynamic> forumData;

  const ForumDetailScreen({
    super.key,
    required this.forumTitle,
    this.forumData = const {},
  });

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  bool isLoading = true;
  String? loadError;
  List<dynamic> discussions = [];
  String fetchedIntro = ''; // <-- Nueva variable para guardar el texto forzado

  @override
  void initState() {
    super.initState();
    _loadDiscussions();
  }

  Future<void> _loadDiscussions() async {
    final token = (widget.forumData['usertoken'] ?? '').toString();
    final forumId = (widget.forumData['instance'] ?? '').toString();
    final courseId = (widget.forumData['course'] ?? '').toString();

    if (token.isEmpty || forumId.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Pedimos los debates y también la info del foro al mismo tiempo
      final urlDiscussions = Uri.parse(
        '${AppConfig.apiUrl}/forum-discussions?token=${Uri.encodeComponent(token)}&forumid=$forumId',
      );
      final urlInfo = Uri.parse(
        '${AppConfig.apiUrl}/forum-info?token=${Uri.encodeComponent(token)}&courseid=$courseId&forumid=$forumId',
      );

      // Usamos Future.wait para hacer las dos peticiones a la vez (más rápido)
      final responses = await Future.wait([
        http.get(urlDiscussions),
        http.get(urlInfo).catchError((_) => http.Response('{}', 500)), // Evita romper si la ruta no existe aún
      ]);

      final responseDisc = responses[0];
      final responseInfo = responses[1];

      if (responseDisc.statusCode == 200) {
        final data = jsonDecode(responseDisc.body);

        // Extraemos la descripción forzada si el backend respondió bien
        String extraIntro = '';
        if (responseInfo.statusCode == 200) {
          try {
            final infoData = jsonDecode(responseInfo.body);
            if (infoData['intro'] != null && infoData['intro'].toString().isNotEmpty) {
              extraIntro = infoData['intro'].toString();
            }
          } catch (_) {}
        }

        setState(() {
          discussions = data is List ? data : [];
          fetchedIntro = extraIntro;
          isLoading = false;
        });
      } else {
        throw Exception('Falló la carga desde Moodle');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        loadError = 'No se pudieron cargar los debates del foro.';
      });
    }
  }

  String _getDescription() {
    // 1. Si logramos forzar la descarga del texto real desde el backend, usamos ese.
    if (fetchedIntro.isNotEmpty) {
      return fetchedIntro;
    }

    // 2. Si no, intentamos buscar en los datos locales
    String intro = '';

    if (widget.forumData.containsKey('intro') && widget.forumData['intro'] != null) {
      intro = widget.forumData['intro'].toString();
    } else if (widget.forumData.containsKey('description') && widget.forumData['description'] != null) {
      intro = widget.forumData['description'].toString();
    }
    else if (widget.forumData.containsKey('modules')) {
      try {
        final mods = widget.forumData['modules'] as List;
        if (mods.isNotEmpty) {
          intro = (mods.first['description'] ?? '').toString();
        }
      } catch (_) {}
    }
    else if (widget.forumData.containsKey('name')) {
      final nameVal = widget.forumData['name'].toString();
      if (nameVal != widget.forumTitle) {
        intro = nameVal;
      }
    }

    intro = intro.trim();
    if (intro.isNotEmpty) {
      return intro;
    }

    return '<p>Espacio de intercambio académico del curso.</p>';
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '';
    try {
      final int timestamp = value is int ? value : int.parse(value.toString());
      if (timestamp <= 0) return '';
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = _getDescription();

    final uniqueParticipants = discussions.map((d) => d['userfullname']).toSet().length;

    final courseId = (widget.forumData['course'] ?? '').toString();
    final token = (widget.forumData['usertoken'] ?? '').toString();
    final forumId = (widget.forumData['instance'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forumTitle),
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
                Text(
                  widget.forumTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                HtmlWidget(
                  description,
                  textStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ForumStatCard(
                        label: 'Debates',
                        value: '${discussions.length}',
                        icon: Icons.forum_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ForumStatCard(
                        label: 'Participantes',
                        value: '$uniqueParticipants',
                        icon: Icons.people_alt_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Participaciones',
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
          else if (discussions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Todavía no hay mensajes cargados para este foro dentro de la app.',
                ),
              ),
            )
          else
            ...discussions.map(
                  (discussion) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ForumMessageCard(
                  author: (discussion['userfullname'] ?? 'Participante').toString(),
                  role: 'Participante',
                  date: _formatTimestamp(discussion['created']),
                  subject: (discussion['name'] ?? '').toString(),
                  message: (discussion['message'] ?? '').toString(),
                  discussionId: (discussion['discussion'] ?? discussion['id'] ?? '').toString(),
                  moodleToken: token,
                  forumId: forumId,
                  courseId: courseId,
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFB3123B),
        foregroundColor: Colors.white,
        onPressed: () async {
          if (courseId.isNotEmpty && token.isNotEmpty && forumId.isNotEmpty) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddForumPostScreen(
                  moodleToken: token,
                  forumId: forumId,
                  courseId: courseId,
                ),
              ),
            );

            if (result == true) {
              setState(() {
                isLoading = true;
              });
              _loadDiscussions();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Faltan datos para crear un debate.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Nuevo debate'),
      ),
    );
  }
}

class _ForumStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ForumStatCard({
    required this.label,
    required this.value,
    required this.icon,
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

class ForumMessageCard extends StatelessWidget {
  final String author;
  final String role;
  final String date;
  final String subject;
  final String message;
  final String discussionId;
  final String moodleToken;
  final String forumId;
  final String courseId;

  const ForumMessageCard({
    super.key,
    required this.author,
    required this.role,
    required this.date,
    required this.subject,
    required this.message,
    required this.discussionId,
    required this.moodleToken,
    required this.forumId,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    final isTeacher = role == 'Docente';
    final accentColor = isTeacher ? const Color(0xFFB3123B) : const Color(0xFF1E88E5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: accentColor.withOpacity(0.15),
                  child: Text(
                    _initials(author),
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (subject.isNotEmpty) ...[
              Text(
                subject,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: HtmlWidget(
                message.isEmpty ? '<p>Sin contenido disponible.</p>' : message,
                textStyle: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddForumPostScreen(
                        moodleToken: moodleToken,
                        forumId: discussionId,
                        courseId: courseId,
                        replyToSubject: subject,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: const Text('Responder en el debate'),
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}