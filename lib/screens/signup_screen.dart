import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import 'onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _detectLang(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.currentLocale != null) {
      final code = appState.currentLocale!.languageCode.toLowerCase();
      if (['pt', 'it', 'es', 'fr', 'en'].contains(code)) return code;
    }
    final devLocale = Localizations.maybeLocaleOf(context) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    final devLang = devLocale.languageCode.toLowerCase();
    if (['pt', 'it', 'es', 'fr', 'en'].contains(devLang)) return devLang;
    return 'en';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AppState>().isLoading;
    final lang = _detectLang(context);

    final title = lang == 'pt'
        ? "Criar uma conta"
        : (lang == 'es'
            ? "Crear una cuenta"
            : (lang == 'it'
                ? "Crea un account"
                : (lang == 'en' ? "Create an Account" : "Créer un compte")));

    final subtitle = lang == 'pt'
        ? "Junte-se à comunidade oficial BeachMatch."
        : (lang == 'es'
            ? "Únete a la comunidad oficial BeachMatch."
            : (lang == 'it'
                ? "Unisciti alla community ufficiale BeachMatch."
                : (lang == 'en'
                    ? "Join the official BeachMatch community."
                    : "Rejoignez la communauté officielle BeachMatch.")));

    final nameLabel = lang == 'pt'
        ? "Nome completo"
        : (lang == 'es'
            ? "Nombre completo"
            : (lang == 'it' ? "Nome completo" : (lang == 'en' ? "Full Name" : "Nom complet")));

    final emailLabel = lang == 'pt'
        ? "E-mail"
        : (lang == 'es'
            ? "Correo electrónico"
            : (lang == 'it' ? "Indirizzo Email" : (lang == 'en' ? "Email Address" : "Adresse Email")));

    final passwordLabel = lang == 'pt'
        ? "Senha"
        : (lang == 'es' ? "Contraseña" : (lang == 'it' ? "Password" : (lang == 'en' ? "Password" : "Mot de passe")));

    final emptyFieldsMsg = lang == 'pt'
        ? "Por favor, preencha todos os campos"
        : (lang == 'es'
            ? "Por favor, completa todos los campos"
            : (lang == 'it'
                ? "Compila tutti i campi"
                : (lang == 'en' ? "Please fill in all fields" : "Veuillez remplir tous les champs")));

    final submitLabel = lang == 'pt'
        ? "Cadastre-se"
        : (lang == 'es'
            ? "Registrarse"
            : (lang == 'it' ? "Registrati" : (lang == 'en' ? "Sign Up" : "S'inscrire")));

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/beach_sunset_players_1785052273648.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1080,
            ),
          ),
          // Dark Overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(28.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1B29).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.sports_tennis, color: AppColors.gold, size: 28),
                                    const SizedBox(width: 10),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                                const SizedBox(height: 24),

                                // Name
                                _buildTextField(nameLabel, Icons.person_outline, _nameController),
                                const SizedBox(height: 16),

                                // Email
                                _buildTextField(emailLabel, Icons.email_outlined, _emailController, keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: 16),

                                // Password
                                _buildTextField(passwordLabel, Icons.lock_outline, _passwordController, isPassword: true),
                                const SizedBox(height: 28),

                                // Signup Button
                                ElevatedButton(
                                  onPressed: isLoading ? null : () async {
                                    final name = _nameController.text.trim();
                                    final email = _emailController.text.trim();
                                    final password = _passwordController.text;

                                    if (name.isEmpty || email.isEmpty || password.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(emptyFieldsMsg)),
                                      );
                                      return;
                                    }

                                    try {
                                      bool success = await context.read<AppState>().signUpWithEmail(name, email, password);
                                      if (success && context.mounted) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.coral,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 4,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(submitLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }
}
