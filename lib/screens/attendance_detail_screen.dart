import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class AttendanceDetailScreen extends StatefulWidget {
  final String classTitle;
  final String classDate;
  final String courseName;

  // ¡Acá están las variables mágicas para que desaparezca el error rojo!
  final String moodleToken;
  final String sessionId;

  const AttendanceDetailScreen({
    super.key,
    required this.classTitle,
    required this.classDate,
    required this.courseName,
    required this.moodleToken,
    required this.sessionId,
  });

  @override
  State<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends State<AttendanceDetailScreen> {
  bool isLoading = true;
  bool isSaving = false;

  List<Map<String, dynamic>> students = [];

  // Moodle usa IDs internos para decir qué es "Presente" y qué es "Ausente"
  int presentStatusId = 0;
  int absentStatusId = 0;

  @override
  void initState() {
    super.initState();
    _loadRealStudents();
  }

  // 1. CHUPAMOS LOS ALUMNOS DEL SERVIDOR
  Future<void> _loadRealStudents() async {
    try {
      final url = Uri.parse(
          '${AppConfig.apiUrl}/attendance-session-detail?token=${widget.moodleToken}&sessionid=${widget.sessionId}');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> usersData = data['users'] ?? [];
        final List<dynamic> statusesData = data['statuses'] ?? [];

        // Buscamos cuáles son los IDs de Presente y Ausente en este curso
        if (statusesData.isNotEmpty) {
          presentStatusId = statusesData[0]['id']; // Por defecto el primero es Presente
          absentStatusId = statusesData.length > 1 ? statusesData[1]['id'] : presentStatusId;

          for (var s in statusesData) {
            final acronym = (s['acronym'] ?? '').toString().toUpperCase();
            if (acronym == 'P') presentStatusId = s['id'];
            if (acronym == 'A' || acronym == 'F') absentStatusId = s['id'];
          }
        }

        // Armamos la lista de estudiantes para la pantalla
        setState(() {
          students = usersData.map((u) {
            // Moodle manda el estado actual en 'statusid' o 'attendanceid'
            final currentStatus = u['statusid'] ?? u['attendanceid'];

            // Si el profesor todavía no tomó lista, Moodle manda null o 0.
            // Ponemos a todos en Presente por defecto para que sea más fácil llamar lista.
            bool isPresent = (currentStatus == presentStatusId) || currentStatus == null || currentStatus == 0;

            // --- ACÁ ESTÁ EL ÚNICO CAMBIO: Traductor de nombres ---
            String finalName = u['fullname']?.toString() ?? '';
            if (finalName.trim().isEmpty) {
              final String firstName = u['firstname']?.toString() ?? '';
              final String lastName = u['lastname']?.toString() ?? '';
              finalName = '$firstName $lastName'.trim();
            }
            if (finalName.isEmpty) {
              finalName = 'Estudiante'; // Por si Moodle de verdad no manda nada
            }
            // ------------------------------------------------------

            return {
              'id': u['id'], // Necesitamos su ID real para guardar después
              'name': finalName, // Usamos el nombre traducido
              'present': isPresent,
            };
          }).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar la lista de alumnos')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 2. ENVIAMOS LOS PRESENTES Y AUSENTES A MOODLE
  Future<void> _saveAttendanceToMoodle() async {
    setState(() {
      isSaving = true;
    });

    try {
      // Preparamos los datos en el formato que quiere Node.js
      final studentData = students.map((s) => {
        'studentid': s['id'],
        'statusid': s['present'] == true ? presentStatusId : absentStatusId,
      }).toList();

      final url = Uri.parse('${AppConfig.apiUrl}/attendance-submit');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.moodleToken,
          'sessionid': widget.sessionId,
          'studentData': studentData,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Asistencia guardada correctamente en Moodle!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Volvemos a la pantalla anterior
        }
      } else {
        // ¡LUPA ESPÍA ACTIVADA ACÁ!
        final data = jsonDecode(response.body);
        final detail = data['detail'] != null ? jsonEncode(data['detail']) : 'Sin detalles';
        throw Exception('Moodle rechazó la lista. Detalles: $detail');
      }
    } catch (e) {
      if (mounted) {
        // Ahora el cartel rojo mostrará el error REAL que manda el servidor
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 10), // Lo dejamos más tiempo para que puedas leerlo
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount =
        students.where((student) => student['present'] == true).length;
    final absentCount = students.length - presentCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de asistencia'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
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
                  widget.classTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.classDate,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.courseName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        label: 'Presentes',
                        value: '$presentCount',
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        label: 'Ausentes',
                        value: '$absentCount',
                        icon: Icons.cancel_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (students.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No hay alumnos matriculados en este curso.'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Card(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        secondary: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB3123B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(student['name'] as String),
                              style: const TextStyle(
                                color: Color(0xFFB3123B),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          student['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            student['present'] ? 'Presente' : 'Ausente',
                            style: TextStyle(
                              color: student['present']
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        value: student['present'] as bool,
                        activeColor: const Color(0xFFB3123B),
                        onChanged: (value) {
                          setState(() {
                            student['present'] = value;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // ACÁ CONECTAMOS EL BOTÓN
                onPressed: isSaving ? null : _saveAttendanceToMoodle,
                icon: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(isSaving ? 'Guardando...' : 'Guardar asistencia'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
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

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}