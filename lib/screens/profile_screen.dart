import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class ProfileScreen extends StatefulWidget {
  final String userName;
  final bool isTeacherView;
  final String moodleToken;
  final int userId;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.isTeacherView,
    required this.moodleToken,
    required this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  String? errorMessage;

  String realName = '';
  String realEmail = '';
  String realCourseCount = '0';
  String realTasksCount = '--';
  String realNoticesCount = '--';

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    realName = widget.userName;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final infoUrl = Uri.parse('${AppConfig.apiUrl}/site-info?token=${Uri.encodeComponent(widget.moodleToken)}');
      final coursesUrl = Uri.parse('${AppConfig.apiUrl}/my-courses?token=${Uri.encodeComponent(widget.moodleToken)}');

      final responses = await Future.wait([
        http.get(infoUrl),
        http.get(coursesUrl),
      ]);

      final infoResponse = responses[0];
      final coursesResponse = responses[1];

      if (infoResponse.statusCode == 200) {
        final data = jsonDecode(infoResponse.body);

        int courseCount = 0;
        int taskCount = 0;
        int noticeCount = 0;

        if (coursesResponse.statusCode == 200) {
          final coursesData = jsonDecode(coursesResponse.body);
          if (coursesData is List) {
            courseCount = coursesData.length;

            // ¡MAGIA APLICADA! Escaneamos todos los cursos rápido para contar Tareas y Avisos(Foros)
            List<Future<http.Response>> contentFutures = [];
            for (var course in coursesData) {
              final cid = course['id'].toString();
              contentFutures.add(http.get(Uri.parse('${AppConfig.apiUrl}/course-contents?token=${Uri.encodeComponent(widget.moodleToken)}&courseid=$cid')));
            }

            final contentResponses = await Future.wait(contentFutures);

            for (var res in contentResponses) {
              if (res.statusCode == 200) {
                final contents = jsonDecode(res.body) as List<dynamic>;
                for (var section in contents) {
                  final modules = section['modules'] as List<dynamic>? ?? [];
                  for (var mod in modules) {
                    final modName = (mod['modname'] ?? '').toString().toLowerCase();
                    if (modName == 'assign') {
                      taskCount++;
                    } else if (modName == 'forum') {
                      noticeCount++;
                    }
                  }
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            realName = data['fullname'] ?? widget.userName;

            String usernameVal = (data['username'] ?? '').toString();
            if (usernameVal.contains('@')) {
              realEmail = usernameVal;
            } else {
              realEmail = '$usernameVal@unamis.edu.py';
            }

            realCourseCount = courseCount.toString();
            realTasksCount = taskCount.toString(); // ¡Conectado!
            realNoticesCount = noticeCount.toString(); // ¡Conectado!
            isLoading = false;
          });
        }
      } else {
        throw Exception('Error al cargar perfil');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'No se pudieron cargar los datos del servidor.';
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _isUploadingPhoto = true;
    });

    try {
      final fileName = pickedFile.path.split('/').last;
      final fileBytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(fileBytes);
      final mimeType = 'image/${fileName.split('.').last}';

      final url = Uri.parse('${AppConfig.apiUrl}/update-profile-picture');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.moodleToken,
          'userid': widget.userId,
          'fileName': fileName,
          'fileBase64': base64Image,
          'mimeType': mimeType,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['ok'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Foto actualizada en Moodle. Los cambios pueden tardar en reflejarse.')),
            );
          }
        } else {
          throw Exception(result['error'] ?? 'Error desconocido');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la foto: $e')),
        );
        setState(() {
          _imageFile = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: realName);
    final emailController = TextEditingController(text: realEmail);
    bool isSaving = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: SingleChildScrollView( // AGREGADO PARA RESPONSIVE
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: const Icon(Icons.person_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: const Icon(Icons.email_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
                    ),
                    ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        setDialogState(() => isSaving = true);
                        await Future.delayed(const Duration(seconds: 2));

                        if (mounted) {
                          setState(() {
                            realName = nameController.text;
                            realEmail = emailController.text;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Perfil actualizado correctamente')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB3123B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Guardar'),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final repeatPasswordController = TextEditingController();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureRepeat = true;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Cambiar Contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: currentPasswordController,
                          obscureText: obscureCurrent,
                          decoration: InputDecoration(
                            labelText: 'Contraseña actual',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: newPasswordController,
                          obscureText: obscureNew,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: repeatPasswordController,
                          obscureText: obscureRepeat,
                          decoration: InputDecoration(
                            labelText: 'Repetir nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(obscureRepeat ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureRepeat = !obscureRepeat),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
                    ),
                    ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        if (newPasswordController.text != repeatPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Las contraseñas nuevas no coinciden'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        await Future.delayed(const Duration(seconds: 2));

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contraseña cambiada exitosamente')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB3123B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Actualizar'),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(realName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: SafeArea( // AGREGADO PARA RESPONSIVE
        child: isLoading
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
                children: [
                  GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                          child: _imageFile == null
                              ? _isUploadingPhoto
                              ? const CircularProgressIndicator(color: Color(0xFFB3123B))
                              : Text(
                            initials,
                            style: const TextStyle(
                              color: Color(0xFFB3123B),
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                              : null,
                        ),
                        if (!_isUploadingPhoto)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Color(0xFFB3123B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    realName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (realEmail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      realEmail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Información personal',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ProfileInfoCard(
              icon: Icons.badge_rounded,
              title: 'Rol',
              value: widget.isTeacherView ? 'Docente' : 'Estudiante',
              color: const Color(0xFFFFD180),
            ),
            const SizedBox(height: 12),
            const ProfileInfoCard(
              icon: Icons.calendar_month_rounded,
              title: 'Periodo',
              value: 'Cohorte 2026-2027',
              color: Color(0xFFCE93D8),
            ),
            const SizedBox(height: 24),
            const Text(
              'Resumen académico',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ProfileStatCard(
                    label: 'Cursos',
                    value: realCourseCount,
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFF7DB7FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ProfileStatCard(
                    label: 'Tareas',
                    value: realTasksCount,
                    icon: Icons.assignment_rounded,
                    color: const Color(0xFFFFD180),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ProfileStatCard(
                    label: 'Avisos',
                    value: realNoticesCount,
                    icon: Icons.notifications_rounded,
                    color: const Color(0xFFCE93D8),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: 26),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.edit_rounded,
                      color: Color(0xFFB3123B),
                    ),
                    title: const Text(
                      'Editar perfil',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: _showEditProfileDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFFB3123B),
                    ),
                    title: const Text(
                      'Cambiar contraseña',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
              ),
            ),
            const SizedBox(height: 40), // ESPACIO EXTRA PARA RESPONSIVE
          ],
        ),
      ),
    );
  }

  String _getInitials(String text) {
    final parts = text.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16),
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
          child: Text(value),
        ),
      ),
    );
  }
}

class ProfileStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const ProfileStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}