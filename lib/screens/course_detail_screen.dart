import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'activity_screen.dart';
import 'participants_screen.dart';
import 'forum_detail_screen.dart';
import 'materials_section_screen.dart';
import 'course_settings_screen.dart';
import 'grades_screen.dart';
import 'task_submission_screen.dart';
import 'teacher_panel_screen.dart';
import 'attendance_screen.dart';
import '../config.dart'; // Importamos la configuración centralizada

class CourseDetailScreen extends StatefulWidget {
  final bool isTeacherView;
  final String userName;
  final String moodleToken;
  final int courseId;
  final String courseTitle;
  final String teacherName;
  final String cohortText;

  const CourseDetailScreen({
    super.key,
    required this.isTeacherView,
    required this.userName,
    required this.moodleToken,
    required this.courseId,
    required this.courseTitle,
    required this.teacherName,
    required this.cohortText,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  int selectedTabIndex = 0;

  late String editableCourseTitle;
  late String editableTeacherName;
  late String editableCohortText;
  late String editableCode;
  late String editableModality;
  late String editableLoadHours;
  late String editableDescription;

  bool isLoading = true;
  String? loadError;

  List<Map<String, dynamic>> courseContents = [];
  List<Map<String, dynamic>> participants = [];

  @override
  void initState() {
    super.initState();
    editableCourseTitle = widget.courseTitle;
    editableTeacherName = widget.teacherName;
    editableCohortText = widget.cohortText;
    editableCode = 'CUR-${widget.courseId}';
    editableModality = 'Virtual';
    editableLoadHours = '--';
    editableDescription =
    'Espacio de aprendizaje organizado por materiales, actividades y recursos del curso.';

    _loadCourseData();
  }

  Future<void> _loadCourseData() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final detailUrl = Uri.parse(
        '${AppConfig.apiUrl}/course-detail?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=${widget.courseId}',
      );

      final contentsUrl = Uri.parse(
        '${AppConfig.apiUrl}/course-contents?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=${widget.courseId}',
      );

      final participantsUrl = Uri.parse(
        '${AppConfig.apiUrl}/course-participants?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=${widget.courseId}',
      );

      // ¡NUEVO!: Añadimos la llamada a nuestra mini base de datos local
      final configUrl = Uri.parse(
        '${AppConfig.apiUrl}/obtener-config-curso/${widget.courseId}',
      );

      final responses = await Future.wait([
        http.get(detailUrl),
        http.get(contentsUrl),
        http.get(participantsUrl),
        http.get(configUrl), // Llamamos a la configuración personalizada
      ]);

      final detailResponse = responses[0];
      final contentsResponse = responses[1];
      final participantsResponse = responses[2];
      final configResponse = responses[3]; // La respuesta de nuestra mini base

      // 1. Cargamos el detalle básico de Moodle
      if (detailResponse.statusCode == 200) {
        final detail = jsonDecode(detailResponse.body);

        editableCourseTitle =
            (detail['fullname'] ?? editableCourseTitle).toString();
        // Usamos el shortname de Moodle por defecto si nuestra mini base no tiene nada
        editableCohortText =
            (detail['shortname'] ?? editableCohortText).toString();

        final summary = (detail['summary'] ?? '').toString().trim();
        if (summary.isNotEmpty) {
          editableDescription = _stripHtml(summary);
        }
      }

      // 2. ¡EL TRUCO!: Sobrescribimos con los datos de nuestra mini base si existen
      if (configResponse.statusCode == 200) {
        final configData = jsonDecode(configResponse.body);

        // Solo sobrescribimos si el campo de la mini base tiene contenido
        if (configData['codigo'] != null && configData['codigo'].toString().trim().isNotEmpty) {
          editableCode = configData['codigo'].toString().trim();
        }
        if (configData['cohorte'] != null && configData['cohorte'].toString().trim().isNotEmpty) {
          editableCohortText = configData['cohorte'].toString().trim();
        }
        if (configData['modalidad'] != null && configData['modalidad'].toString().trim().isNotEmpty) {
          editableModality = configData['modalidad'].toString().trim();
        }
        if (configData['cargaHoraria'] != null && configData['cargaHoraria'].toString().trim().isNotEmpty) {
          editableLoadHours = configData['cargaHoraria'].toString().trim();
        }
      }

      if (contentsResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(contentsResponse.body);
        courseContents = data.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (participantsResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(participantsResponse.body);
        participants = data.map((e) => Map<String, dynamic>.from(e)).toList();

        if (participants.isNotEmpty) {
          final teachersList = participants.where(
                  (p) {
                final roles = (p['roles'] as String? ?? '').toLowerCase();
                return roles.contains('docente') ||
                    roles.contains('teacher') ||
                    roles.contains('profesor') ||
                    roles.contains('editingteacher');
              }
          ).toList();

          if (teachersList.isNotEmpty) {
            final realTeacher = teachersList.firstWhere(
                    (t) => !(t['fullname'] ?? '').toString().toLowerCase().contains('pablo cesar ramos'),
                orElse: () => teachersList.first
            );

            editableTeacherName = (realTeacher['fullname'] ?? editableTeacherName).toString();
          }
        }
      }
    } catch (e) {
      loadError = 'No se pudo cargar el detalle del curso.';
    } finally {
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

  Future<void> _openCourseSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CourseSettingsScreen(
          initialCourseTitle: editableCourseTitle,
          initialTeacherName: editableTeacherName,
          initialCohortText: editableCohortText,
          initialCode: editableCode,
          initialModality: editableModality,
          initialLoadHours: editableLoadHours,
          initialDescription: editableDescription,
          moodleToken: widget.moodleToken,
          courseId: widget.courseId.toString(),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        editableCourseTitle = result['courseTitle'] as String;
        editableTeacherName = result['teacherName'] as String;
        editableCohortText = result['cohortText'] as String;
        editableCode = result['code'] as String;
        editableModality = result['modality'] as String;
        editableLoadHours = result['loadHours'] as String;
        editableDescription = result['description'] as String;
      });
    }
  }

  List<Map<String, dynamic>> _buildContentItems() {
    final items = <Map<String, dynamic>>[];

    Map<String, List<dynamic>> realSubsectionsContents = {};
    for (var section in courseContents) {
      final secName = (section['name'] ?? '').toString().trim();
      realSubsectionsContents[secName] = section['modules'] as List<dynamic>? ?? [];
    }

    List<String> processedSections = [];

    // ¡NUEVO!: Ordenamos las secciones numéricamente (Encuentro 1, 2, 3...)
    final sortedSections = List<Map<String, dynamic>>.from(courseContents);
    sortedSections.sort((a, b) {
      final nameA = _stripHtml((a['name'] ?? '').toString());
      final nameB = _stripHtml((b['name'] ?? '').toString());
      
      final valA = int.tryParse(RegExp(r'\d+').stringMatch(nameA) ?? '');
      final valB = int.tryParse(RegExp(r'\d+').stringMatch(nameB) ?? '');

      if (valA != null && valB != null) return valA.compareTo(valB);
      if (valA != null) return 1; // Lo que tiene número va después de lo General
      if (valB != null) return -1;
      
      return 0; // Mantener orden original si ninguno tiene número
    });

    for (final section in sortedSections) {
      final rawSectionName = (section['name'] ?? 'Sección').toString().trim();
      final sectionName = _stripHtml(rawSectionName);

      if (processedSections.contains(rawSectionName)) continue;
      processedSections.add(rawSectionName);

      final modules = (section['modules'] as List<dynamic>? ?? []);

      // Agregamos una cabecera para la sección si tiene módulos
      if (modules.isNotEmpty) {
        items.add({
          'type': 'section_header',
          'title': sectionName,
        });
      }

      for (final module in modules) {
        final mod = Map<String, dynamic>.from(module);
        mod['usertoken'] = widget.moodleToken;
        mod['courseid'] = widget.courseId;
        mod['cmid'] = mod['id'];

        final rawModName = (mod['name'] ?? 'Recurso').toString().trim();
        final modName = _stripHtml(rawModName);
        final modType = (mod['modname'] ?? '').toString().toLowerCase();

        if (modType == 'subsection') {
          if (realSubsectionsContents.containsKey(rawModName)) {
            List<Map<String, dynamic>> realMaterials = [];
            for(final rM in realSubsectionsContents[rawModName]!) {
              final rMod = Map<String, dynamic>.from(rM);
              rMod['usertoken'] = widget.moodleToken;
              rMod['courseid'] = widget.courseId;
              rMod['cmid'] = rMod['id'];
              realMaterials.add(rMod);
            }

            items.add({
              'icon': Icons.folder_rounded,
              'title': modName,
              'subtitle': '${realMaterials.length} recursos disponibles',
              'type': 'folder_group',
              'section': sectionName,
              'moduleData': mod,
              'materials': realMaterials,
            });

            processedSections.add(rawModName);
          } else {
            items.add({
              'icon': Icons.folder_open_rounded,
              'title': modName,
              'subtitle': 'Sección vacía',
              'type': 'activity',
              'section': sectionName,
              'moduleData': mod,
            });
          }
        }
        else {
          IconData icon = Icons.insert_drive_file_rounded;
          String type = 'activity';

          if (modType.contains('forum')) {
            icon = Icons.forum_rounded;
            type = 'forum';
          } else if (modType.contains('resource') || modType.contains('folder') || modType.contains('url') || modType.contains('page')) {
            icon = Icons.folder_rounded;
            type = 'materials';
          } else if (modType.contains('assign') || modType.contains('quiz')) {
            icon = Icons.assignment_rounded;
            type = 'activity';
          } else if (modType.contains('attendance')) {
            icon = Icons.fact_check_rounded;
            type = 'attendance';
          }

          items.add({
            'icon': icon,
            'title': modName,
            'subtitle': sectionName,
            'type': type,
            'section': sectionName,
            'moduleData': mod,
          });
        }
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final contentItems = _buildContentItems();

    return Scaffold(
      appBar: AppBar(
        title: Text(editableCourseTitle),
        actions: [
          if (widget.isTeacherView)
            IconButton(
              onPressed: _openCourseSettings,
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Editar curso',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            loadError!,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CourseHeroHeader(
            courseTitle: editableCourseTitle,
            teacherName: editableTeacherName,
            cohortText: editableCohortText,
            code: editableCode,
            modality: editableModality,
            loadHours: editableLoadHours,
            description: editableDescription,
            isTeacherView: widget.isTeacherView,
          ),
          const SizedBox(height: 18),
          if (selectedTabIndex == 0) ...[
            _CourseNewsSection(
              isTeacherView: widget.isTeacherView,
              contentItems: contentItems,
            ),
          ] else if (selectedTabIndex == 1) ...[
            const Text(
              'Trabajo en clase',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            if (!widget.isTeacherView) ...[
              IntroNavigationCard(
                title: 'Mis calificaciones',
                subtitle: 'Ver notas y observaciones del curso',
                icon: Icons.grade_rounded,
                color: const Color(0xFFFFC857),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GradesScreen(
                        moodleToken: widget.moodleToken,
                        courseId: widget.courseId.toString(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ] else ...[
              IntroNavigationCard(
                title: 'Panel Docente',
                subtitle: 'Calificar entregas y gestionar el curso',
                icon: Icons.admin_panel_settings_rounded,
                color: const Color(0xFFB3123B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeacherPanelScreen(
                        moodleToken: widget.moodleToken,
                        courseId: widget.courseId.toString(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            if (contentItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay contenidos cargados.'),
                ),
              )
            else
              ...contentItems.map(
                (item) {
                  if (item['type'] == 'section_header') {
                    final isFirstHeader = contentItems.indexOf(item) == 0;
                    return Padding(
                      padding: EdgeInsets.only(top: isFirstHeader ? 8 : 24, bottom: 12, left: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isFirstHeader) 
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Divider(height: 1),
                            ),
                          Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB3123B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WeekItemTile(
                      icon: item['icon'] as IconData,
                      title: item['title'] as String,
                      subtitle: item['subtitle'] as String,
                      type: item['type'] as String,
                      section: item['section'] as String,
                      moduleData: item['moduleData'] as Map<String, dynamic>? ?? {},
                      materials: item['materials'] as List<Map<String, dynamic>>?,
                      moodleToken: widget.moodleToken,
                      courseId: widget.courseId.toString(),
                      courseTitle: editableCourseTitle,
                      isTeacherView: widget.isTeacherView,
                    ),
                  );
                },
              ),
          ] else ...[
            const Text(
              'Personas',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _PeoplePreviewCard(
              teacherName: editableTeacherName,
              participants: participants,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParticipantsScreen(
                      participants: participants,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'Novedades',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Trabajo en clase',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Personas',
          ),
        ],
      ),
    );
  }
}

class _CourseNewsSection extends StatelessWidget {
  final bool isTeacherView;
  final List<Map<String, dynamic>> contentItems;

  const _CourseNewsSection({
    required this.isTeacherView,
    required this.contentItems,
  });

  @override
  Widget build(BuildContext context) {
    final realActivities = contentItems.where((item) {
      final moduleType = ((item['moduleData']?['modname'] ?? '') as String).toLowerCase();
      return moduleType == 'assign' ||
          moduleType == 'forum' ||
          moduleType == 'resource' ||
          moduleType == 'folder';
    }).toList();

    final latestActivities = realActivities.reversed.take(3).toList();

    final newsItems = latestActivities.map((item) {
      final moduleType = ((item['moduleData']?['modname'] ?? '') as String).toLowerCase();

      String labelText = 'Nuevo material';
      Color labelColor = const Color(0xFF1E88E5);

      if (moduleType == 'assign') {
        labelText = 'Nueva tarea';
        labelColor = const Color(0xFFFFB300);
      } else if (moduleType == 'forum') {
        labelText = 'Nuevo foro';
        labelColor = const Color(0xFF8E24AA);
      }

      return {
        'title': item['title'],
        'subtitle': 'Sección: ${item['subtitle']}',
        'date': labelText,
        'icon': item['icon'],
        'color': labelColor,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isTeacherView) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.campaign_rounded,
                  color: Color(0xFF1E88E5),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Desde el panel docente puede publicar avisos, crear tareas y organizar el curso.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        const Text(
          'Últimas Novedades',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        if (newsItems.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay actividades recientes para mostrar.'),
            ),
          )
        else
          ...newsItems.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                    ),
                  ),
                  title: Text(
                    item['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['subtitle'] as String),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (item['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['date'] as String,
                            style: TextStyle(
                              color: item['color'] as Color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PeoplePreviewCard extends StatelessWidget {
  final String teacherName;
  final List<Map<String, dynamic>> participants;
  final VoidCallback onTap;

  const _PeoplePreviewCard({
    required this.teacherName,
    required this.participants,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final classmates = participants
        .where((p) =>
    !(p['roles'] as String? ?? '').toLowerCase().contains('docente') &&
        !(p['roles'] as String? ?? '').toLowerCase().contains('teacher') &&
        !(p['roles'] as String? ?? '').toLowerCase().contains('profesor'))
        .take(4)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Docente',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _personRow(
              initials: _initials(teacherName),
              name: teacherName,
              color: const Color(0xFFB3123B),
            ),
            const SizedBox(height: 18),
            const Text(
              'Compañeros de clase',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (classmates.isEmpty)
              const Text('No hay participantes para mostrar.')
            else
              ...classmates.map(
                    (person) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _personRow(
                    initials: _initials((person['fullname'] ?? '').toString()),
                    name: (person['fullname'] ?? 'Sin nombre').toString(),
                    color: const Color(0xFF1E88E5),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.people_alt_rounded),
                label: const Text('Ver todas las personas'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personRow({
    required String initials,
    required String name,
    required Color color,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.14),
          child: Text(
            initials,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class CourseHeroHeader extends StatelessWidget {
  final String courseTitle;
  final String teacherName;
  final String cohortText;
  final String code;
  final String modality;
  final String loadHours;
  final String description;
  final bool isTeacherView;

  const CourseHeroHeader({
    super.key,
    required this.courseTitle,
    required this.teacherName,
    required this.cohortText,
    required this.code,
    required this.modality,
    required this.loadHours,
    required this.description,
    required this.isTeacherView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7E0F2A),
            Color(0xFFB3123B),
            Color(0xFFC68A2E),
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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'UNAMIS · Aula Virtual 2026',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            courseTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cohortText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: HeaderInfoMiniCard(
                  title: 'Código',
                  value: code,
                  accent: const Color(0xFF8E102C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeaderInfoMiniCard(
                  title: 'Carga',
                  value: loadHours,
                  accent: const Color(0xFFC68A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: HeaderInfoMiniCard(
                  title: 'Modalidad',
                  value: modality,
                  accent: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeaderInfoMiniCard(
                  title: 'Docente',
                  value: teacherName,
                  accent: const Color(0xFF43A047),
                ),
              ),
            ],
          ),
          if (isTeacherView) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Vista docente',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HeaderInfoMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;

  const HeaderInfoMiniCard({
    super.key,
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: accent, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class IntroNavigationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const IntroNavigationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _WeekItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String type;
  final String section;
  final Map<String, dynamic> moduleData;
  final List<Map<String, dynamic>>? materials;

  final String moodleToken;
  final String courseId;
  final String courseTitle;
  final bool isTeacherView;

  const _WeekItemTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.section,
    this.moduleData = const {},
    this.materials,
    this.moodleToken = '',
    this.courseId = '',
    this.courseTitle = '',
    this.isTeacherView = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFB3123B).withOpacity(0.12),
          child: Icon(
            icon,
            color: const Color(0xFFB3123B),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {
          if (type == 'attendance') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceScreen(
                  moodleToken: moodleToken,
                  courseId: courseId,
                  courseName: courseTitle,
                  isTeacherView: isTeacherView,
                ),
              ),
            );
          } else if (type == 'folder_group' && materials != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaterialsSectionScreen(
                  sectionTitle: title,
                  materials: materials!,
                  // ¡NUEVAS LÍNEAS! Pasamos el ID y el Token
                  courseId: courseId,
                  moodleToken: moodleToken,
                ),
              ),
            );
          } else if (type == 'forum') {
            // ¡NUEVA LÍNEA! Le inyectamos el ID al foro por si entra directo
            moduleData['course'] = courseId;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ForumDetailScreen(
                  forumTitle: title,
                  forumData: moduleData,
                ),
              ),
            );
          } else if (type == 'materials') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaterialsSectionScreen(
                  sectionTitle: section,
                  materials: [moduleData],
                  // ¡NUEVAS LÍNEAS! Pasamos el ID y el Token
                  courseId: courseId,
                  moodleToken: moodleToken,
                ),
              ),
            );
          } else if ((moduleData['modname'] ?? '').toString().toLowerCase().contains('assign')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskSubmissionScreen(
                  title: title,
                  subtitle: subtitle,
                  moduleData: moduleData,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ActivityScreen(
                  title: title,
                  subtitle: subtitle,
                  moduleData: moduleData,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
