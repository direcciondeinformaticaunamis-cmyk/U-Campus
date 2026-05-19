import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart'; // ¡NUEVO!
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // ¡NUEVO!
import 'activity_screen.dart';
import 'forum_detail_screen.dart';
import 'task_submission_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class MaterialsSectionScreen extends StatelessWidget {
  final String sectionTitle;
  final List<Map<String, dynamic>> materials;
  final String courseId;
  final String moodleToken;

  const MaterialsSectionScreen({
    super.key,
    required this.sectionTitle,
    this.materials = const [],
    this.courseId = '',
    this.moodleToken = '',
  });

  List<Map<String, dynamic>> _normalizeMaterials() {
    return materials.map((material) {
      final title =
      (material['name'] ?? material['title'] ?? 'Material').toString();

      final modName =
      (material['modname'] ?? material['type'] ?? 'Archivo').toString();

      String date = 'Disponible en el curso';
      final added = material['added'];
      if (added != null) {
        date = added.toString();
      }

      final Map<String, dynamic> rawData = Map<String, dynamic>.from(material);
      if (modName.toLowerCase() == 'forum' && courseId.isNotEmpty) {
        rawData['course'] = courseId;
        rawData['usertoken'] = moodleToken;
      }

      return {
        'title': title,
        'type': modName,
        'date': date,
        'raw': rawData,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeMaterials();

    return Scaffold(
      appBar: AppBar(
        title: Text(sectionTitle),
        backgroundColor: const Color(0xFFB3123B),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      body: normalized.isEmpty
          ? const Center(
        child: Text(
          "Aún no hay materiales para esta sección.",
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Recursos disponibles",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...normalized.map(
                (material) {
              final type = material["type"]!.toString().toLowerCase();

              // ¡LA MAGIA! Si es una Etiqueta (Label), dibujamos el video/texto suelto
              if (type == 'label') {
                return InlineHtmlLabel(
                  moduleData: material["raw"] as Map<String, dynamic>? ?? {},
                );
              }

              // Si no es etiqueta, dibujamos la tarjeta normal que ya tenías
              return MaterialCard(
                title: material["title"]!.toString(),
                type: material["type"]!.toString(),
                date: material["date"]!.toString(),
                rawMaterial:
                material["raw"] as Map<String, dynamic>? ?? {},
              );
            },
          ),
        ],
      ),
    );
  }
}

class MaterialCard extends StatelessWidget {
  final String title;
  final String type;
  final String date;
  final Map<String, dynamic> rawMaterial;

  const MaterialCard({
    super.key,
    required this.title,
    required this.type,
    required this.date,
    required this.rawMaterial,
  });

  IconData getFileIcon() {
    final lower = type.toLowerCase();

    if (lower.contains("assign") || lower.contains("quiz")) {
      return Icons.assignment_rounded;
    } else if (lower.contains("forum")) {
      return Icons.forum_rounded;
    } else if (lower.contains("pdf")) {
      return Icons.picture_as_pdf_rounded;
    } else if (lower.contains("ppt")) {
      return Icons.slideshow_rounded;
    } else if (lower.contains("folder")) {
      return Icons.folder_rounded;
    } else if (lower.contains("url")) {
      return Icons.link_rounded;
    } else if (lower.contains("page") || lower.contains("label")) {
      return Icons.article_rounded;
    } else if (lower.contains("attendance")) {
      return Icons.fact_check_rounded;
    } else {
      return Icons.insert_drive_file_rounded;
    }
  }

  Color getColor() {
    final lower = type.toLowerCase();

    if (lower.contains("assign")) {
      return const Color(0xFFB3123B); // Rojo tareas
    } else if (lower.contains("forum")) {
      return Colors.purple; // Morado foros
    } else if (lower.contains("pdf")) {
      return const Color(0xFFD32F2F);
    } else if (lower.contains("ppt")) {
      return Colors.orange;
    } else if (lower.contains("folder")) {
      return Colors.amber;
    } else if (lower.contains("url")) {
      return Colors.blue;
    } else if (lower.contains("attendance")) {
      return Colors.teal;
    } else {
      return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          final lowerType = type.toLowerCase();

          if (lowerType.contains('forum')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ForumDetailScreen(
                  forumTitle: title,
                  forumData: rawMaterial,
                ),
              ),
            );
          } else if (lowerType.contains('assign')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskSubmissionScreen(
                  title: title,
                  subtitle: type,
                  moduleData: rawMaterial,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ActivityScreen(
                  title: title,
                  subtitle: type,
                  moduleData: rawMaterial,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: getColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  getFileIcon(),
                  color: getColor(),
                  size: 26,
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
                    const SizedBox(height: 4),
                    Text(
                      type.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black54,
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
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// ¡NUEVO WIDGET! Para dibujar los videos y textos sueltos en la lista
// =========================================================================
class InlineHtmlLabel extends StatefulWidget {
  final Map<String, dynamic> moduleData;
  const InlineHtmlLabel({super.key, required this.moduleData});

  @override
  State<InlineHtmlLabel> createState() => _InlineHtmlLabelState();
}

class _InlineHtmlLabelState extends State<InlineHtmlLabel> {
  final List<YoutubePlayerController> _ytControllers = [];

  @override
  void dispose() {
    for (var controller in _ytControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String htmlContent = (widget.moduleData['description'] ??
        widget.moduleData['intro'] ??
        widget.moduleData['summary'] ?? '').toString();

    if (htmlContent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: HtmlWidget(
        htmlContent,
        textStyle: const TextStyle(fontSize: 15.0),
        customWidgetBuilder: (element) {
          final src = element.attributes['src'] ?? element.attributes['href'] ?? '';
          if (src.contains('youtube.com') || src.contains('youtu.be')) {
            final videoId = YoutubePlayer.convertUrlToId(src);
            if (videoId != null) {
              final controller = YoutubePlayerController(
                initialVideoId: videoId,
                flags: const YoutubePlayerFlags(
                  autoPlay: false,
                  mute: false,
                  disableDragSeek: false,
                  loop: false,
                  isLive: false,
                  forceHD: false,
                ),
              );
              _ytControllers.add(controller);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: YoutubePlayer(
                    controller: controller,
                    showVideoProgressIndicator: true,
                    progressColors: const ProgressBarColors(
                      playedColor: Color(0xFFB3123B),
                      handleColor: Color(0xFFB3123B),
                    ),
                  ),
                ),
              );
            }
          }
          return null;
        },
      ),
    );
  }
}