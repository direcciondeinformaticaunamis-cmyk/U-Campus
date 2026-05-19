import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool biometricLogin = false;
  bool saveSession = true;
  bool canCheckBiometrics = false;

  String selectedLanguage = 'Español';

  final List<String> languages = [
    'Español',
    'Português',
    'English',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricsSupport();
  }

  Future<void> _checkBiometricsSupport() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      setState(() {
        canCheckBiometrics = canCheck;
      });
    } catch (e) {
      debugPrint("Error chequeando soporte biométrico: $e");
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      saveSession = prefs.getString('saved_username') != null;
      biometricLogin = prefs.getBool('use_biometrics') ?? false;
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('use_biometrics', biometricLogin);
    await prefs.setBool('notifications_enabled', notificationsEnabled);

    if (!saveSession) {
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajustes guardados correctamente'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      // ¡SOLUCIÓN RESPONSIVE! Envolvemos en SafeArea
      body: SafeArea(
        child: ListView(
          // Agregamos un padding extra abajo (40) para que el botón no se corte
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
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
                    'Preferencias de la app',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Configure la experiencia del aula virtual según sus necesidades.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Configuración general',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: _settingIcon(
                      Icons.notifications_rounded,
                      const Color(0xFFCE93D8),
                    ),
                    title: const Text(
                      'Notificaciones',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Recibir avisos y recordatorios'),
                    value: notificationsEnabled,
                    activeColor: const Color(0xFFB3123B),
                    onChanged: (value) {
                      setState(() {
                        notificationsEnabled = value;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: _settingIcon(
                      Icons.save_rounded,
                      const Color(0xFF7DB7FF),
                    ),
                    title: const Text(
                      'Guardar sesión',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Mantener la cuenta iniciada'),
                    value: saveSession,
                    activeColor: const Color(0xFFB3123B),
                    onChanged: (value) {
                      setState(() {
                        saveSession = value;
                      });
                    },
                  ),
                  if (canCheckBiometrics) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: _settingIcon(
                        Icons.fingerprint_rounded,
                        const Color(0xFFA5D6A7),
                      ),
                      title: const Text(
                        'Acceso biométrico',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Huella o reconocimiento facial'),
                      value: biometricLogin,
                      activeColor: const Color(0xFFB3123B),
                      onChanged: (value) {
                        setState(() {
                          biometricLogin = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Idioma',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: selectedLanguage,
                  decoration: InputDecoration(
                    labelText: 'Idioma de la aplicación',
                    prefixIcon: const Icon(Icons.language_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  items: languages.map((language) {
                    return DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedLanguage = value!;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Información y soporte',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: _settingIcon(
                      Icons.info_rounded,
                      const Color(0xFF7DB7FF),
                    ),
                    title: const Text(
                      'Versión de la app',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('UNAMIS Mobile v1.0.0'),
                    trailing:
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingIcon(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}