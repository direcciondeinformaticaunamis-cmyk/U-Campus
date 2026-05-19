import 'package:flutter/material.dart';
import 'materials_section_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class MaterialsScreen extends StatelessWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weeks = [
      {
        "title": "Semana 1",
        "count": 3,
      },
      {
        "title": "Semana 2",
        "count": 2,
      },
      {
        "title": "Semana 3",
        "count": 0,
      },
      {
        "title": "Semana 4",
        "count": 0,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Materiales del curso"),
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
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Repositorio de materiales",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Acceda a los recursos organizados por semanas.",
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Semanas del curso",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ...weeks.map(
                (week) => MaterialWeekFolder(
              title: week["title"] as String,
              count: week["count"] as int,
            ),
          ),
        ],
      ),
    );
  }
}

class MaterialWeekFolder extends StatelessWidget {
  final String title;
  final int count;

  const MaterialWeekFolder({
    super.key,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFB3123B).withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.folder_rounded,
            color: Color(0xFFB3123B),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          count == 0
              ? "Sin materiales aún"
              : "$count recursos disponibles",
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MaterialsSectionScreen(
                sectionTitle: title,
              ),
            ),
          );
        },
      ),
    );
  }
}