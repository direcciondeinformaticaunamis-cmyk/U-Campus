import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'participants_screen.dart';
import 'tasks_screen.dart';
import 'notices_screen.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class DashboardScreen extends StatelessWidget {
  final bool isTeacherView;
  final String userName;
  final String moodleToken;
  final int userId;

  const DashboardScreen({
    super.key,
    required this.isTeacherView,
    required this.userName,
    required this.userId,
    this.moodleToken = '',
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(userName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UNAMIS'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userName: userName,
                      isTeacherView: isTeacherView,
                      moodleToken: moodleToken,
                      userId: userId,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFFB3123B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(26),
            bottomRight: Radius.circular(26),
          ),
        ),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFB3123B),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Image.asset(
                      'assets/images/logo_unamis.png',
                      height: 42,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'UNAMIS\nAula Virtual',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _drawerItem(
              context,
              icon: Icons.home_rounded,
              title: 'Inicio',
              onTap: () => Navigator.pop(context),
            ),
            _drawerItem(
              context,
              icon: Icons.menu_book_rounded,
              title: 'Mis Cursos',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(
                      isTeacherView: isTeacherView,
                      userName: userName,
                      moodleToken: moodleToken,
                    ),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.assignment_rounded,
              title: 'Tareas',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TasksScreen(
                      moodleToken: moodleToken,
                    ),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.calendar_month_rounded,
              title: 'Calendario',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CalendarScreen(
                      moodleToken: moodleToken,
                    ),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.notifications_rounded,
              title: 'Avisos',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoticesScreen(
                      moodleToken: moodleToken,
                    ),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.people_alt_rounded,
              title: 'Participantes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ParticipantsScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.person_rounded,
              title: 'Mi perfil',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userName: userName,
                      isTeacherView: isTeacherView,
                      moodleToken: moodleToken,
                      userId: userId,
                    ),
                  ),
                );
              },
            ),
            _drawerItem(
              context,
              icon: Icons.settings_rounded,
              title: 'Ajustes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Spacer(),
            const Divider(),
            // ¡NUEVO! SafeArea para subir el botón en teléfonos con barra de gestos
            SafeArea(
              top: false,
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                        (route) => false,
                  );
                },
              ),
            ),
            const SizedBox(height: 24), // Un poco más de margen para que respire
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Center(
                child: Image.asset(
                  'assets/images/logo_unamis.png',
                  width: 320,
                  height: 320,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          ListView(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Hola, $userName! 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isTeacherView
                          ? 'Bienvenido al panel académico de UNAMIS'
                          : 'Bienvenido al Aula Virtual UNAMIS',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Accesos rápidos',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.08,
                children: [
                  DashboardCard(
                    icon: Icons.menu_book_rounded,
                    title: 'Mis Cursos',
                    color: const Color(0xFF7DB7FF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeScreen(
                            isTeacherView: isTeacherView,
                            userName: userName,
                            moodleToken: moodleToken,
                          ),
                        ),
                      );
                    },
                  ),
                  DashboardCard(
                    icon: Icons.assignment_rounded,
                    title: 'Tareas',
                    color: const Color(0xFFFFD180),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TasksScreen(
                            moodleToken: moodleToken,
                          ),
                        ),
                      );
                    },
                  ),
                  DashboardCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Calendario',
                    color: const Color(0xFF80DEEA),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CalendarScreen(
                            moodleToken: moodleToken,
                          ),
                        ),
                      );
                    },
                  ),
                  DashboardCard(
                    icon: Icons.notifications_rounded,
                    title: 'Avisos',
                    color: const Color(0xFFCE93D8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoticesScreen(
                            moodleToken: moodleToken,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/campus_virtual_banner.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 26),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFB3123B)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }

  String _getInitials(String text) {
    final parts = text.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.black87),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}