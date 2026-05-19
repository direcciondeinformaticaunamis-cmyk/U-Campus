import 'package:flutter/material.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class ParticipantsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> participants;

  const ParticipantsScreen({
    super.key,
    this.participants = const [],
  });

  @override
  Widget build(BuildContext context) {
    final normalizedParticipants = participants.map((participant) {
      final fullName = (participant['fullname'] ?? participant['name'] ?? 'Sin nombre').toString();
      final email = (participant['email'] ?? '').toString();
      final rawRole = (participant['roles'] ?? participant['role'] ?? 'Estudiante').toString();

      final role = _normalizeRole(rawRole);

      return {
        'name': fullName,
        'email': email.isEmpty ? 'Sin correo disponible' : email,
        'role': role,
        'status': 'Activo',
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Participantes'),
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
                  'Participantes del curso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Visualice docentes y estudiantes vinculados a este espacio académico.',
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
            'Miembros activos (${normalizedParticipants.length})',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          if (normalizedParticipants.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay participantes para mostrar.'),
              ),
            )
          else
            ...normalizedParticipants.map(
                  (participant) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ParticipantCard(
                  name: participant['name']!.toString(),
                  email: participant['email']!.toString(),
                  role: participant['role']!.toString(),
                  status: participant['status']!.toString(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _normalizeRole(String rawRole) {
    final roleLower = rawRole.toLowerCase();

    if (roleLower.contains('teacher') ||
        roleLower.contains('editingteacher') ||
        roleLower.contains('docente') ||
        roleLower.contains('profesor')) {
      return 'Docente';
    }

    return 'Estudiante';
  }
}

class ParticipantCard extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String status;

  const ParticipantCard({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final isTeacher = role == 'Docente';
    final roleColor = isTeacher ? const Color(0xFFB3123B) : const Color(0xFF1E88E5);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.black45,
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Perfil de $name próximamente disponible'),
            ),
          );
        },
      ),
    );
  }

  String _getInitials(String text) {
    final parts = text.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}