import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dashboard_screen.dart';
import '../config.dart'; // ¡NUEVO! Importamos la configuración centralizada

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final LocalAuthentication auth = LocalAuthentication();

  bool obscurePassword = true;
  bool rememberMe = true;
  bool isLoading = false;
  bool canCheckBiometrics = false;
  bool userEnabledBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    userController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    bool canCheck = false;
    try {
      canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e) {
      debugPrint("Error chequeando biometría: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    final enabledInSettings = prefs.getBool('use_biometrics') ?? false;

    if (mounted) {
      setState(() {
        canCheckBiometrics = canCheck;
        userEnabledBiometrics = enabledInSettings;
      });
    }

    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_username');
    final savedPass = prefs.getString('saved_password');

    if (savedUser != null && savedPass != null) {
      setState(() {
        rememberMe = true;
      });

      if (!(canCheckBiometrics && userEnabledBiometrics)) {
        setState(() {
          userController.text = savedUser;
          passwordController.text = savedPass;
        });
      }
    } else {
      setState(() {
        rememberMe = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_username');
    final savedPass = prefs.getString('saved_password');

    if (savedUser == null || savedPass == null || savedUser.isEmpty || savedPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero inicie sesión manualmente marcando "Recordar sesión"'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Inicie sesión con su biometría para acceder a UNAMIS',
      );
    } catch (e) {
      debugPrint("Error al autenticar: $e");
      return;
    }

    if (authenticated) {
      _executeLogin(savedUser, savedPass);
    }
  }

  Future<void> _login() async {
    final user = userController.text.trim();
    final pass = passwordController.text.trim();
    _executeLogin(user, pass);
  }

  Future<void> _executeLogin(String user, String pass) async {
    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete usuario y contraseña'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${AppConfig.apiUrl}/login');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': user,
          'password': pass,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['token'] != null) {
        final fullName =
        (data['user']?['fullname'] ?? user).toString().replaceAll(',', '').trim();

        final userId = data['user']?['userid'] ?? 0;

        final prefs = await SharedPreferences.getInstance();

        final String privateToken = (data['privatetoken'] ?? '').toString();
        if (privateToken.isNotEmpty) {
          await prefs.setString('moodle_private_token', privateToken);
        }

        if (rememberMe) {
          await prefs.setString('saved_username', user);
          await prefs.setString('saved_password', pass);
        } else {
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
        }

        // --- INICIO DE LA VALIDACIÓN DINÁMICA DE ROL (ESTIRAMIENTO INFALIBLE) ---
        bool isTeacher = false;
        try {
          // 1. Consultamos los cursos del usuario
          final coursesUrl = Uri.parse('${AppConfig.apiUrl}/my-courses?token=${data['token']}');
          final coursesResponse = await http.get(coursesUrl);

          if (coursesResponse.statusCode == 200) {
            final List<dynamic> coursesData = jsonDecode(coursesResponse.body);

            for (var course in coursesData) {
              final courseId = course['id'];

              // 2. ¡EL TRUCO! Le preguntamos a la lista de participantes (que sabemos que SÍ funciona)
              final partUrl = Uri.parse('${AppConfig.apiUrl}/course-participants?token=${data['token']}&courseid=$courseId');
              final partResponse = await http.get(partUrl);

              if (partResponse.statusCode == 200) {
                final List<dynamic> participants = jsonDecode(partResponse.body);

                for (var p in participants) {
                  // Si el ID del participante coincide con el del usuario que está entrando...
                  if (p['id'].toString() == userId.toString()) {
                    final rolesStr = (p['roles'] ?? '').toString().toLowerCase();

                    // Verificamos si en este curso tiene rol docente
                    if (rolesStr.contains('teacher') ||
                        rolesStr.contains('docente') ||
                        rolesStr.contains('profesor') ||
                        rolesStr.contains('editingteacher')) {
                      isTeacher = true;
                      break; // ¡Bingo! Encontramos que es profe, detenemos la búsqueda de este alumno
                    }
                  }
                }
              }

              if (isTeacher) break; // Si ya sabemos que es profe, detenemos la búsqueda en los demás cursos para que el login sea rápido
            }
          }
        } catch (e) {
          debugPrint("Error verificando participantes para el rol: $e");
        }
        // --- FIN DE LA VALIDACIÓN DINÁMICA ---

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              isTeacherView: isTeacher,
              userName: fullName.isEmpty ? user : fullName,
              moodleToken: data['token'].toString(),
              userId: userId,
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (data['error'] ?? 'Usuario o contraseña incorrectos').toString(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB3123B),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7FA),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/images/logo_unamis.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'UNIVERSIDAD\nNACIONAL DE MISIONES',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'UNAMIS',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: userController,
                        decoration: InputDecoration(
                          labelText: 'Nombre de usuario',
                          prefixIcon: const Icon(Icons.person_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: rememberMe,
                            activeColor: const Color(0xFFB3123B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (value) {
                              setState(() {
                                rememberMe = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Recordar sesión',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _login,
                              icon: isLoading
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(Icons.login_rounded),
                              label: Text(isLoading ? 'Accediendo...' : 'Acceder'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 17),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          if (canCheckBiometrics && userEnabledBiometrics) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 54,
                              child: OutlinedButton(
                                onPressed: isLoading ? null : _authenticateWithBiometrics,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Icon(Icons.fingerprint_rounded, size: 28),
                              ),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Recuperación de contraseña próximamente disponible',
                              ),
                            ),
                          );
                        },
                        child: const Text('¿Olvidó su contraseña?'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}