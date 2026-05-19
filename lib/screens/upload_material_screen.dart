import 'package:flutter/material.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class UploadMaterialScreen extends StatefulWidget {
  const UploadMaterialScreen({super.key});

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String selectedType = 'PDF';

  final List<String> materialTypes = [
    'PDF',
    'PPT',
    'Video',
    'Enlace',
    'Documento',
  ];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir material'),
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
                  'Nuevo recurso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Agregue material para que sus estudiantes puedan acceder desde la app.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Título del material',
                      hintText: 'Ej: Unidad 2 - Introducción',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Escriba una breve descripción del recurso',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 64),
                        child: Icon(Icons.description_rounded),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Tipo de material',
                      prefixIcon: const Icon(Icons.category_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    items: materialTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE4E4E8),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _getColorForType(selectedType).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _getIconForType(selectedType),
                            size: 34,
                            color: _getColorForType(selectedType),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Seleccionar archivo',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'PDF, presentaciones, documentos o enlaces',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selector de archivos próximamente'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.attach_file_rounded),
                          label: const Text('Adjuntar archivo'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _getColorForType(selectedType).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getIconForType(selectedType),
                      size: 34,
                      color: _getColorForType(selectedType),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Vista previa: $selectedType',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _previewText(selectedType),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingrese un título para el material'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Material "$title" publicado correctamente'),
                  ),
                );
              },
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Publicar material'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'PPT':
        return Icons.slideshow_rounded;
      case 'Video':
        return Icons.video_library_rounded;
      case 'Enlace':
        return Icons.link_rounded;
      case 'Documento':
        return Icons.description_rounded;
      default:
        return Icons.upload_file_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'PDF':
        return Colors.red;
      case 'PPT':
        return Colors.orange;
      case 'Video':
        return Colors.green;
      case 'Enlace':
        return Colors.blue;
      case 'Documento':
        return const Color(0xFFB3123B);
      default:
        return const Color(0xFFB3123B);
    }
  }

  String _previewText(String type) {
    switch (type) {
      case 'PDF':
        return 'Ideal para guías, apuntes y documentos de lectura.';
      case 'PPT':
        return 'Perfecto para presentaciones de clase y exposiciones.';
      case 'Video':
        return 'Útil para recursos audiovisuales y clases grabadas.';
      case 'Enlace':
        return 'Permite compartir bibliografía o recursos externos.';
      case 'Documento':
        return 'Apto para archivos de texto y materiales generales.';
      default:
        return 'Recurso listo para publicar en el aula virtual.';
    }
  }
}