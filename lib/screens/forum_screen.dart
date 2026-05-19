import 'package:flutter/material.dart';
import 'forum_detail_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class ForumScreen extends StatelessWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final forums = [
      {
        "title": "Foro de presentación",
        "desc": "Preséntese y conozca a sus compañeros",
      },
      {
        "title": "Foro Semana 1",
        "desc": "Discusión sobre números naturales",
      },
      {
        "title": "Foro Semana 2",
        "desc": "Resolución de ejercicios",
      },
      {
        "title": "Foro Semana 3",
        "desc": "Debate matemático",
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Foros del curso"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Espacios de discusión",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          ...forums.map(
                (forum) => ForumCard(
              title: forum["title"]!,
              desc: forum["desc"]!,
            ),
          ),
        ],
      ),
    );
  }
}

class ForumCard extends StatelessWidget {
  final String title;
  final String desc;

  const ForumCard({
    super.key,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.forum_rounded,
            color: Colors.deepPurple,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(desc),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ForumDetailScreen(
                forumTitle: title,
              ),
            ),
          );
        },
      ),
    );
  }
}