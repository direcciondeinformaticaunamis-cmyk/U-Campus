import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // ¡NUEVO! El reproductor
import 'quiz_webview_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class ActivityScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Map<String, dynamic> moduleData;

  const ActivityScreen({
    super.key,
    required this.title,
    this.subtitle = '',
    this.moduleData = const {},
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool isOpeningFile = false;
  String downloadedHtmlContent = '';
  bool isLoadingHtml = false;

  // Lista para guardar y apagar los reproductores cuando nos vamos
  final List<YoutubePlayerController> _ytControllers = [];

  @override
  void initState() {
    super.initState();
    _checkIfNeedsToDownloadHtml();
  }

  @override
  void dispose() {
    // Apagamos los videos si el alumno se va de la pantalla
    for (var controller in _ytControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _cleanHtmlLayout(String html) {
    String clean = html;

    clean = clean.replaceAll(RegExp(r'color\s*:\s*[^;"]+;?', caseSensitive: false), 'color: #222222;');
    clean = clean.replaceAll(RegExp(r'color\s*=\s*"[^"]*"', caseSensitive: false), 'color="#222222"');
    clean = clean.replaceAll(RegExp(r"color\s*=\s*'[^']*'", caseSensitive: false), "color='#222222'");

    clean = clean.replaceAll(RegExp(r'background-color\s*:\s*[^;"]+;?', caseSensitive: false), 'background-color: transparent;');

    clean = clean.replaceAll(RegExp(r'display\s*:\s*flex\s*;?', caseSensitive: false), 'display: block;');
    clean = clean.replaceAll(RegExp(r'display\s*:\s*grid\s*;?', caseSensitive: false), 'display: block;');
    clean = clean.replaceAll(RegExp(r'float\s*:\s*[^;"]+;?', caseSensitive: false), 'float: none;');
    clean = clean.replaceAll(RegExp(r'width\s*:\s*[^;"]+;?', caseSensitive: false), 'width: 100%;');
    clean = clean.replaceAll(RegExp(r'width\s*=\s*"[^"]*"', caseSensitive: false), 'width="100%"');
    return clean;
  }

  Future<void> _checkIfNeedsToDownloadHtml() async {
    final modName = (widget.moduleData['modname'] ?? '').toString().toLowerCase();

    if (modName == 'page' || modName == 'label') {
      final file = _getFirstFile();

      if (file != null && (file['filename'] ?? '').toString().toLowerCase().endsWith('.html')) {
        setState(() { isLoadingHtml = true; });

        final rawUrl = (file['fileurl'] ?? '').toString();
        final token = (widget.moduleData['usertoken'] ?? '').toString();

        if (rawUrl.isNotEmpty && token.isNotEmpty) {
          try {
            final fileUrl = rawUrl.contains('?') ? '$rawUrl&token=$token' : '$rawUrl?token=$token';
            final response = await http.get(Uri.parse(fileUrl));

            if (response.statusCode == 200) {
              if (mounted) {
                setState(() {
                  String html = utf8.decode(response.bodyBytes);
                  html = html.replaceAll('/pluginfile.php/', '/webservice/pluginfile.php/');
                  html = html.replaceAllMapped(RegExp(r'src="(https?://[^"]+)"'), (match) {
                    String url = match.group(1)!;
                    if (!url.contains('token=')) {
                      url += url.contains('?') ? '&token=$token' : '?token=$token';
                    }
                    return 'src="$url"';
                  });
                  downloadedHtmlContent = _cleanHtmlLayout(html);
                  isLoadingHtml = false;
                });
              }
              return;
            }
          } catch (e) {
            debugPrint('Error descargando HTML: $e');
          }
        }
        if (mounted) setState(() { isLoadingHtml = false; });
      }
    }
  }

  String _getDescription() {
    final modName = (widget.moduleData['modname'] ?? '').toString().toLowerCase();

    if (downloadedHtmlContent.isNotEmpty) {
      return downloadedHtmlContent;
    }

    String rawDescription = (widget.moduleData['description'] ??
        widget.moduleData['intro'] ??
        widget.moduleData['summary'] ?? '').toString();

    if (modName == 'qbank') {
      return '<p>Este es un banco de preguntas interno del curso. Las evaluaciones y cuestionarios utilizarán los recursos de este banco automáticamente.</p>';
    }

    if (modName == 'subsection') {
      return '<p><b>Subsección del curso</b><br><br>Este ítem funciona como un separador u organizador. Los materiales, foros y actividades correspondientes a este encuentro los encontrarás listados en la pantalla anterior.</p>';
    }

    if (modName == 'quiz' && rawDescription.isEmpty) {
      return '<p><b>Evaluación / Cuestionario</b><br><br>Presione el botón inferior para abrir y responder este cuestionario en la plataforma de manera segura.</p>';
    }

    String finalDesc = '';
    if (rawDescription.isNotEmpty) {
      finalDesc = _cleanHtmlLayout(rawDescription);
    }

    final contents = widget.moduleData['contents'];
    bool hasAttachedFiles = false;

    if (contents is List && contents.isNotEmpty) {
      final first = contents.first;
      if (first is Map<String, dynamic>) {
        final fileUrl = (first['fileurl'] ?? '').toString();
        if (fileUrl.isNotEmpty && modName != 'url' && modName != 'page' && modName != 'label' && modName != 'attendance' && modName != 'subsection') {
          hasAttachedFiles = true;
        }
      }
    }

    if (hasAttachedFiles) {
      String fileText = '<p><i>Este recurso contiene archivos adjuntos. Puede abrirlos o descargarlos usando el botón inferior.</i></p>';
      if (finalDesc.isNotEmpty) {
        finalDesc += '<br><br>$fileText';
      } else {
        finalDesc = fileText;
      }
    }

    if (finalDesc.isNotEmpty) {
      return finalDesc;
    }

    if (widget.subtitle.isNotEmpty) {
      return '<p>Contenido correspondiente a: <b>${widget.subtitle}</b></p>';
    }

    return '<p>No hay información adicional para mostrar en este recurso.</p>';
  }

  List<Map<String, dynamic>> _getResourceDetails() {
    final result = <Map<String, dynamic>>[];
    final modName = (widget.moduleData['modname'] ?? '').toString().toLowerCase();

    if (modName == 'page' || modName == 'label' || modName == 'qbank' || modName == 'subsection') {
      return result;
    }

    if (modName.isNotEmpty) {
      result.add({
        'label': 'Tipo de recurso Moodle',
        'value': modName.toUpperCase(),
      });
    }

    final contents = widget.moduleData['contents'];
    if (contents is List) {
      for (final item in contents) {
        if (item is Map<String, dynamic>) {
          final name = (item['filename'] ?? item['name'] ?? '').toString();
          final type = (item['type'] ?? '').toString();
          final fileUrl = (item['fileurl'] ?? '').toString();

          if (name.isNotEmpty && type != 'url') {
            result.add({
              'label': type.isEmpty ? 'Archivo' : type,
              'value': name,
              'fileurl': fileUrl,
              'filename': name,
            });
          }
          else if (modName == 'url' && fileUrl.isNotEmpty) {
            result.add({
              'label': 'Enlace externo',
              'value': fileUrl,
              'fileurl': fileUrl,
            });
          }
        }
      }
    }

    return result;
  }

  IconData _getIcon() {
    final modName = (widget.moduleData['modname'] ?? '').toString().toLowerCase();

    if (modName.contains('assign') || modName.contains('quiz')) {
      return Icons.assignment_rounded;
    }
    if (modName.contains('url')) {
      return Icons.link_rounded;
    }
    if (modName.contains('qbank')) {
      return Icons.quiz_rounded;
    }
    if (modName.contains('subsection')) {
      return Icons.layers_rounded;
    }
    if (modName.contains('resource') ||
        modName.contains('page') ||
        modName.contains('folder')) {
      return Icons.folder_rounded;
    }
    if (modName.contains('label')) {
      return Icons.info_outline_rounded;
    }
    if (modName.contains('forum')) {
      return Icons.forum_rounded;
    }
    return Icons.menu_book_rounded;
  }

  Map<String, dynamic>? _getFirstFile() {
    final contents = widget.moduleData['contents'];
    if (contents is List) {
      for (final item in contents) {
        if (item is Map<String, dynamic>) {
          final fileUrl = (item['fileurl'] ?? '').toString();
          if (fileUrl.isNotEmpty) {
            return item;
          }
        }
      }
    }
    return null;
  }

  bool _isPdfFile(Map<String, dynamic>? file) {
    if (file == null) return false;
    final name = (file['filename'] ?? '').toString().toLowerCase();
    return name.endsWith('.pdf');
  }

  String _getExternalUrl(Map<String, dynamic>? file) {
    if (file == null) return '';
    final type = (file['type'] ?? '').toString().toLowerCase();
    if (type == 'url') {
      return (file['fileurl'] ?? '').toString();
    }
    return '';
  }

  Future<void> _openExternalUrl(String urlString) async {
    if (urlString.isEmpty) return;
    try {
      final uri = Uri.parse(urlString);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir el enlace.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace desde la app.')),
        );
      }
    }
  }

  Future<void> _openSpecificFile(String rawUrl, String fileName) async {
    final token = (widget.moduleData['usertoken'] ?? '').toString();
    if (rawUrl.isEmpty || token.isEmpty) return;

    setState(() {
      isOpeningFile = true;
    });

    try {
      final fileUrl = rawUrl.contains('?')
          ? '$rawUrl&token=$token'
          : '$rawUrl?token=$token';

      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode != 200) {
        throw Exception('No se pudo descargar el archivo');
      }

      final dir = await getTemporaryDirectory();
      final safeFileName = fileName.replaceAll(' ', '_');
      final localFile = File('${dir.path}/$safeFileName');

      await localFile.writeAsBytes(response.bodyBytes);

      if (!mounted) return;

      if (safeFileName.toLowerCase().endsWith('.pdf')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              title: fileName,
              filePath: localFile.path,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo guardado. Solo se pueden abrir PDFs dentro de la app.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al abrir el archivo.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isOpeningFile = false;
        });
      }
    }
  }

  Future<void> _openPdf() async {
    final file = _getFirstFile();
    if (file == null) return;
    final rawUrl = (file['fileurl'] ?? '').toString();
    final fileName = (file['filename'] ?? 'archivo.pdf').toString();

    await _openSpecificFile(rawUrl, fileName);
  }

  @override
  Widget build(BuildContext context) {
    final details = _getResourceDetails();
    final firstFile = _getFirstFile();
    final hasPdf = _isPdfFile(firstFile);

    final modName = (widget.moduleData['modname'] ?? '').toString().toLowerCase();
    final isExternalLink = modName == 'url';
    final externalUrl = _getExternalUrl(firstFile);

    final isQuiz = modName == 'quiz';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFB3123B).withOpacity(0.12),
                  child: Icon(
                    _getIcon(),
                    color: const Color(0xFFB3123B),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                isLoadingHtml
                    ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    : HtmlWidget(
                  _getDescription(),
                  textStyle: const TextStyle(
                    fontSize: 15.0,
                    height: 1.5,
                  ),
                  onTapUrl: (url) async {
                    await _openExternalUrl(url);
                    return true;
                  },
                  // ¡LA MAGIA DE YOUTUBE!
                  customWidgetBuilder: (element) {
                    final src = element.attributes['src'] ?? element.attributes['href'] ?? '';

                    // Si el elemento es un iframe o un link de youtube
                    if (src.contains('youtube.com') || src.contains('youtu.be')) {
                      final videoId = YoutubePlayer.convertUrlToId(src);

                      if (videoId != null) {
                        // Creamos el controlador para este video en particular
                        final controller = YoutubePlayerController(
                          initialVideoId: videoId,
                          flags: const YoutubePlayerFlags(
                            autoPlay: false,
                            mute: false,
                            disableDragSeek: false,
                            loop: false,
                            isLive: false,
                            forceHD: false,
                            enableCaption: true,
                          ),
                        );

                        // Lo guardamos para poder apagarlo cuando nos vayamos
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

                    // Si NO es de YouTube, pero es un iframe raro, le dejamos el botón azul de antes
                    if (element.localName == 'iframe' || element.className.contains('mediaplugin')) {
                      if (src.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: ElevatedButton.icon(
                            onPressed: () => _openExternalUrl(src),
                            icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
                            label: const Text('Abrir enlace externo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                          ),
                        );
                      }
                    }
                    return null;
                  },
                  customStylesBuilder: (element) {
                    final tag = element.localName ?? '';

                    if (tag == 'td' || tag == 'th' || tag == 'tr') {
                      return {'display': 'block', 'width': '100%', 'box-sizing': 'border-box', 'margin-bottom': '10px'};
                    }
                    if (tag == 'table') {
                      return {'display': 'block', 'width': '100%'};
                    }
                    if (tag == 'div') {
                      return {'display': 'block', 'width': '100%', 'box-sizing': 'border-box', 'word-wrap': 'normal', 'word-break': 'normal', 'white-space': 'normal'};
                    }
                    if (tag == 'p' || tag == 'span' || tag.startsWith('h') || tag == 'strong' || tag == 'b' || tag == 'a' || tag == 'font') {
                      return {'color': '#222222', 'word-break': 'normal'};
                    }
                    if (tag == 'img') {
                      return {'max-width': '100%', 'height': 'auto', 'border-radius': '8px'};
                    }
                    return null;
                  },
                ),

                if (hasPdf) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isOpeningFile ? null : _openPdf,
                      icon: isOpeningFile
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(
                        isOpeningFile ? 'Abriendo PDF...' : 'Abrir PDF principal',
                      ),
                    ),
                  ),
                ],

                if (isExternalLink && externalUrl.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openExternalUrl(externalUrl),
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Abrir enlace (Teams/Web)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                ],

                if (isQuiz) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final baseUrl = (widget.moduleData['url'] ?? '').toString();
                        final token = (widget.moduleData['usertoken'] ?? '').toString();

                        if(baseUrl.isNotEmpty){
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizWebViewScreen(
                                quizUrl: baseUrl,
                                moodleToken: token,
                                title: widget.title,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se encontró el enlace al cuestionario.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.quiz_rounded),
                      label: const Text('Realizar Cuestionario'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB3123B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],

              ],
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Detalles del recurso',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...details.map(
                  (item) => Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(item['value']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(item['label']?.toString() ?? ''),
                  leading: Icon(
                      item['label'] == 'Enlace externo'
                          ? Icons.link_rounded
                          : Icons.insert_drive_file_rounded
                  ),
                  trailing: item['fileurl'] != null
                      ? const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38)
                      : null,
                  onTap: () {
                    final url = item['fileurl']?.toString() ?? '';
                    final name = item['filename']?.toString() ?? 'archivo.pdf';
                    final label = item['label']?.toString() ?? '';

                    if (label == 'Enlace externo') {
                      _openExternalUrl(url);
                    } else if (url.isNotEmpty && !isOpeningFile) {
                      _openSpecificFile(url, name);
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PdfViewerScreen extends StatelessWidget {
  final String title;
  final String filePath;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SfPdfViewer.file(File(filePath)),
    );
  }
}