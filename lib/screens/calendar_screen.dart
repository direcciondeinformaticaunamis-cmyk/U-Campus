import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart'; // ¡LIBRERÍA NUEVA AGREGADA!
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

// ¡NUEVO! Importamos las pantallas a las que vamos a navegar
import 'attendance_screen.dart';
import 'task_submission_screen.dart';
import 'forum_detail_screen.dart'; // ¡Agregado para los foros!

class CalendarScreen extends StatefulWidget {
  final String moodleToken; // ¡NUEVO! Necesitamos la llave para ver tu calendario

  const CalendarScreen({
    super.key,
    required this.moodleToken,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> realEvents = [];

  // Variables para controlar el calendario de grilla
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchCalendarEvents();
  }

  Future<void> _fetchCalendarEvents() async {
    // Usamos el año y mes del calendario que estamos mirando
    try {
      final url = Uri.parse(
          '${AppConfig.apiUrl}/calendar-events?token=${Uri.encodeComponent(widget.moodleToken)}&year=${_focusedDay.year}&month=${_focusedDay.month}');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Map<String, dynamic>> parsedEvents = [];

        for (var event in data) {
          final timestamp = event['timestart'] as int? ?? 0;
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

          final months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
          final dayStr = date.day.toString().padLeft(2, '0');
          final monthStr = months[date.month - 1];
          final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

          final eventName = (event['name'] ?? 'Evento').toString();

          // ¡NUEVO!: Capturamos los datos crudos para poder navegar
          final String courseName = (event['course']?['fullname'] ?? event['coursename'] ?? 'Curso general').toString();
          final String courseId = (event['course']?['id'] ?? event['courseid'] ?? '').toString();
          final String rawInstance = (event['instance'] ?? '').toString();
          final String modName = (event['modulename'] ?? '').toString();

          String type = 'Evento';
          Color color = const Color(0xFF1E88E5);

          final lowerName = eventName.toLowerCase();
          if (lowerName.contains('asistencia')) {
            type = 'Asistencia';
            color = const Color(0xFFE53935);
          } else if (lowerName.contains('vencimiento') || lowerName.contains('tarea') || lowerName.contains('assign')) {
            type = 'Entrega';
            color = const Color(0xFFE65100); // Naranja fuerte para que se lea
          } else if (lowerName.contains('foro') || lowerName.contains('forum')) {
            type = 'Foro';
            color = const Color(0xFF8E24AA);
          }

          // ¡NUEVO!: Capturamos el "isCompleted" que manda tu servidor Ninja
          final bool isCompleted = event['isCompleted'] == true;

          parsedEvents.add({
            'day': dayStr,
            'month': monthStr,
            'title': eventName,
            'course': courseName,
            'time': timeStr,
            'color': color,
            'type': type,
            'timestamp': timestamp,
            'date': date, // Guardamos el objeto DateTime para comparar rápido
            'isCompleted': isCompleted, // ¡Guardamos el estado para dibujarlo después!
            // ¡NUEVO!: Datos invisibles pero vitales para la navegación
            'courseId': courseId,
            'instance': rawInstance,
            'modulename': modName,
            'rawEvent': event, // Guardamos todo por si acaso
          });
        }

        parsedEvents.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

        if (mounted) {
          setState(() {
            realEvents = parsedEvents;
            isLoading = false;
          });
        }
      } else {
        throw Exception('Error al cargar eventos');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Esta función le da a la grilla los eventos del día para dibujar las bolitas
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return realEvents.where((event) {
      final eventDate = event['date'] as DateTime;
      return eventDate.year == day.year &&
          eventDate.month == day.month &&
          eventDate.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Tomamos los eventos solo del día que el usuario tiene seleccionado
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
      ),
      // ¡EL ARREGLO ESTÁ ACÁ! Envolvemos la columna entera en un scroll
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Tu cabecera original (intacta)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
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
                      'Próximos eventos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Actividades, entregas y asistencias de todos sus cursos.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ¡EL CALENDARIO DE GRILLA!
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay; // Actualiza el mes si toca un día gris del mes siguiente
                    });
                  },
                  // Al deslizar para cambiar de mes, descargamos los datos del nuevo mes
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                      isLoading = true;
                      realEvents = [];
                    });
                    _fetchCalendarEvents();
                  },
                  eventLoader: (day) {
                    return _getEventsForDay(day);
                  },
                  // Estilos para que combine con tus colores
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: const Color(0xFFB3123B).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Color(0xFFB3123B),
                      shape: BoxShape.circle,
                    ),
                    markerSize: 6,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  // ¡MAGIA DE LAS BOLITAS DE COLORES!
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox();

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        // Mostramos hasta 4 bolitas máximo para que no se amontonen
                        children: events.take(4).map((event) {
                          final ev = event as Map<String, dynamic>;

                          // Si está completado, lo dibujamos verde en el calendario de grilla
                          final dotColor = ev['isCompleted'] == true ? Colors.green.shade600 : ev['color'] as Color;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.0),
                            width: 6.0,
                            height: 6.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // LA LISTA DE EVENTOS DEL DÍA QUE SELECCIONASTE
            // ¡ARREGLO ACÁ! Ya no usamos Expanded.
            isLoading
                ? const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )
                : selectedEvents.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Día libre. No hay actividades.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
                : ListView.builder(
              // ¡ARREGLO ACÁ! Hacemos que la lista no se desplace por sí sola,
              // sino que deje que el SingleChildScrollView controle todo.
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: selectedEvents.length,
              itemBuilder: (context, index) {
                final event = selectedEvents[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  // Tu tarjeta con la navegación inyectada
                  child: CalendarEventCard(
                    day: event['day'] as String,
                    month: event['month'] as String,
                    title: event['title'] as String,
                    course: event['course'] as String,
                    time: event['time'] as String,
                    color: event['color'] as Color,
                    type: event['type'] as String,
                    isCompleted: event['isCompleted'] as bool,

                    // ¡NUEVO!: Parámetros ocultos para poder navegar
                    courseId: event['courseId'] as String,
                    instanceId: event['instance'] as String,
                    moduleName: event['modulename'] as String,
                    moodleToken: widget.moodleToken, // Pasamos el token de la app
                    rawEvent: event['rawEvent'],
                  ),
                );
              },
            ),

            // Un pequeño espacio extra al final para que no quede pegado al borde del teléfono
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class CalendarEventCard extends StatelessWidget {
  final String day;
  final String month;
  final String title;
  final String course;
  final String time;
  final Color color;
  final String type;
  final bool isCompleted;

  // ¡NUEVAS VARIABLES INVISIBLES PARA NAVEGAR!
  final String courseId;
  final String instanceId;
  final String moduleName;
  final String moodleToken;
  final dynamic rawEvent;

  const CalendarEventCard({
    super.key,
    required this.day,
    required this.month,
    required this.title,
    required this.course,
    required this.time,
    required this.color,
    required this.type,
    required this.isCompleted,

    // Inicializamos las nuevas variables
    required this.courseId,
    required this.instanceId,
    required this.moduleName,
    required this.moodleToken,
    required this.rawEvent,
  });

  @override
  Widget build(BuildContext context) {

    // Configuramos los colores basados en si está completado
    final cardBgColor = isCompleted ? Colors.green.shade50 : Colors.white;
    final primaryColor = isCompleted ? Colors.green.shade700 : color;
    final badgeText = isCompleted ? '¡Completado!' : type;
    final badgeBgColor = isCompleted ? Colors.green.shade100 : color.withOpacity(0.12);
    final badgeTextColor = isCompleted ? Colors.green.shade800 : color;

    return Card(
      color: cardBgColor, // Si está completado, le damos un fondito verde muy suave
      elevation: isCompleted ? 0 : 1, // Le quitamos la sombra si ya lo hizo (menos estrés visual)
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isCompleted ? BorderSide(color: Colors.green.shade200, width: 1) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // ¡MAGIA DE NAVEGACIÓN TOTAL!
          if (type == 'Asistencia' && courseId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceScreen(
                  moodleToken: moodleToken,
                  courseId: courseId,
                  courseName: course,
                  isTeacherView: false, // Asumimos vista de alumno por defecto
                ),
              ),
            );
          }
          else if (type == 'Entrega') {
            // PRECISIÓN MATEMÁTICA: Pasamos los nombres de variables EXACTOS que exige TaskSubmissionScreen
            Map<String, dynamic> perfectModuleData = {
              'usertoken': moodleToken, // <- Clave exigida por _loadAssignmentData
              'courseid': courseId,      // <- Clave exigida por _loadAssignmentData
              'cmid': instanceId,        // <- Clave exigida por _loadAssignmentData
            };

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskSubmissionScreen(
                  title: title,
                  subtitle: course,
                  moduleData: perfectModuleData,
                ),
              ),
            );
          }
          else if (type == 'Foro') {
            // PRECISIÓN MATEMÁTICA: Pasamos las variables exactas para ForumDetailScreen
            Map<String, dynamic> perfectForumData = {
              'usertoken': moodleToken,
              'course': courseId,
              'instance': instanceId, // Moodle usa la instancia como forumId
              'intro': rawEvent != null ? rawEvent['description'] ?? '' : '',
            };

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ForumDetailScreen(
                  forumTitle: title,
                  forumData: perfectForumData,
                ),
              ),
            );
          }
          else {
            // Evento normal o general (mensaje en la parte inferior)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(title),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      month,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              height: 1.2,
                              decoration: isCompleted ? TextDecoration.lineThrough : null, // Tachamos el título si ya lo hizo
                              color: isCompleted ? Colors.black54 : Colors.black87,
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
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeTextColor,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded, // Cambiamos el reloj por un check
                          size: 16,
                          color: isCompleted ? Colors.green.shade600 : Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            time,
                            style: TextStyle(
                              color: isCompleted ? Colors.green.shade700 : Colors.black54,
                              fontSize: 13,
                              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isCompleted ? Colors.transparent : Colors.black45, // Ocultamos la flechita si ya está completado
              ),
            ],
          ),
        ),
      ),
    );
  }
}