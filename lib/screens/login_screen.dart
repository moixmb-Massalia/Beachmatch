import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/app_state.dart';
import 'signup_screen.dart';
import 'onboarding_screen.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isFocused = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final hasFocus = _emailFocusNode.hasFocus || _passwordFocusNode.hasFocus;
    if (hasFocus != _isFocused) {
      setState(() => _isFocused = hasFocus);
    }
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginSuccess(bool isNewUser) {
    if (!mounted) return;
    if (isNewUser) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );
    }
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
    final lang = _detectLang(context);

    final slogan = lang == 'pt'
        ? "Encontre seu parceiro sob o sol."
        : (lang == 'es'
            ? "Encuentra tu compañero bajo el sol."
            : (lang == 'it'
                ? "Trova il tuo compagno sotto il sole."
                : (lang == 'en' ? "Find your partner under the sun." : "Trouvez votre partenaire sous le soleil.")));

    final emailLabel = lang == 'pt'
        ? "E-mail"
        : (lang == 'es'
            ? "Correo electrónico"
            : (lang == 'it' ? "Indirizzo Email" : (lang == 'en' ? "Email Address" : "Adresse Email")));

    final passwordLabel = lang == 'pt'
        ? "Senha"
        : (lang == 'es' ? "Contraseña" : (lang == 'it' ? "Password" : (lang == 'en' ? "Password" : "Mot de passe")));

    final forgotPasswordLabel = lang == 'pt'
        ? "Esqueceu a senha?"
        : (lang == 'es'
            ? "¿Olvidaste tu contraseña?"
            : (lang == 'it' ? "Password dimenticata?" : (lang == 'en' ? "Forgot password?" : "Mot de passe oublié ?")));

    final forgotDialogTitle = lang == 'pt'
        ? "Recuperar senha"
        : (lang == 'es'
            ? "Recuperar contraseña"
            : (lang == 'it' ? "Password dimenticata" : (lang == 'en' ? "Reset Password" : "Mot de passe oublié")));

    final forgotDialogHint = lang == 'pt'
        ? "Seu endereço de e-mail"
        : (lang == 'es'
            ? "Tu correo electrónico"
            : (lang == 'it' ? "Il tuo indirizzo email" : (lang == 'en' ? "Your email address" : "Votre adresse email")));

    final cancelLabel = lang == 'pt'
        ? "Cancelar"
        : (lang == 'es' ? "Cancelar" : (lang == 'it' ? "Annulla" : (lang == 'en' ? "Cancel" : "Annuler")));

    final sendLabel = lang == 'pt'
        ? "Enviar"
        : (lang == 'es' ? "Enviar" : (lang == 'it' ? "Invia" : (lang == 'en' ? "Send" : "Envoyer")));

    final resetSentLabel = lang == 'pt'
        ? "E-mail de recuperação enviado!"
        : (lang == 'es'
            ? "¡Correo de restablecimiento enviado!"
            : (lang == 'it'
                ? "Email di ripristino inviata!"
                : (lang == 'en' ? "Password reset email sent!" : "Email de réinitialisation envoyé !")));

    final loginBtnLabel = lang == 'pt'
        ? "Entrar"
        : (lang == 'es' ? "Iniciar sesión" : (lang == 'it' ? "Accedi" : (lang == 'en' ? "Log In" : "Se connecter")));

    final orDivider = lang == 'pt'
        ? "OU"
        : (lang == 'es' ? "O" : (lang == 'it' ? "OPPURE" : (lang == 'en' ? "OR" : "OU")));

    final googleBtnLabel = lang == 'pt'
        ? "Continuar com o Google"
        : (lang == 'es'
            ? "Continuar con Google"
            : (lang == 'it' ? "Continua con Google" : (lang == 'en' ? "Continue with Google" : "Continuer avec Google")));

    final appleBtnLabel = lang == 'pt'
        ? "Continuar com a Apple"
        : (lang == 'es'
            ? "Continuar con Apple"
            : (lang == 'it' ? "Continua con Apple" : (lang == 'en' ? "Continue with Apple" : "Continuer avec Apple")));

    final guestBtnLabel = lang == 'pt'
        ? "Acesso Livre · Ver BeachScore & Resultados"
        : (lang == 'es'
            ? "Acceso Libre · Ver BeachScore y Resultados"
            : (lang == 'it'
                ? "Accesso Libero · Guarda BeachScore & Risultati"
                : (lang == 'en'
                    ? "Free Access · View BeachScore & Results"
                    : "Accès Libre · Voir BeachScore & Résultats")));

    final eulaNotice = lang == 'pt'
        ? "Ao entrar, você concorda com os Termos de Uso (EULA) e a Política de Privacidade do BeachMatch."
        : (lang == 'es'
            ? "Al iniciar sesión, aceptas las Condiciones de Uso (EULA) y la Política de Privacidad de BeachMatch."
            : (lang == 'it'
                ? "Accedendo, accetti i Termini di Utilizzo (EULA) e l'Informativa sulla Privacy di BeachMatch."
                : (lang == 'en'
                    ? "By signing in, you agree to BeachMatch Terms of Use (EULA) and Privacy Policy."
                    : "En vous connectant, vous acceptez les Conditions Générales d'Utilisation (CGU / EULA) et la Politique de Confidentialité de BeachMatch.")));

    final noAccountLabel = lang == 'pt'
        ? "Não tem uma conta? "
        : (lang == 'es'
            ? "¿No tienes cuenta? "
            : (lang == 'it' ? "Non hai un account? " : (lang == 'en' ? "Don't have an account? " : "Pas encore de compte ? ")));

    final signUpActionLabel = lang == 'pt'
        ? "Cadastre-se"
        : (lang == 'es' ? "Regístrate" : (lang == 'it' ? "Registrati" : (lang == 'en' ? "Sign Up" : "S'inscrire")));

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
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: _isFocused ? Colors.white.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: _isFocused ? AppColors.gold : Colors.white.withValues(alpha: 0.5),
                          width: _isFocused ? 2.0 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: _isFocused ? 0.25 : 0.1),
                            blurRadius: 30,
                            spreadRadius: -5,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo Placeholder
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.sports_tennis, size: 40, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "BeachMatch",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textMain,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            slogan,
                            style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),

                          // Email
                          TextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            decoration: InputDecoration(
                              labelText: emailLabel,
                              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: _isFocused ? Colors.white : Colors.white.withValues(alpha: 0.8),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: passwordLabel,
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, 
                                  color: AppColors.textMuted
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: _isFocused ? Colors.white : Colors.white.withValues(alpha: 0.8),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                          
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                final emailController = TextEditingController();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(forgotDialogTitle),
                                    content: TextField(
                                      controller: emailController,
                                      decoration: InputDecoration(hintText: forgotDialogHint),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: Text(cancelLabel)),
                                      ElevatedButton(
                                        onPressed: () async {
                                          if (emailController.text.isNotEmpty) {
                                            try {
                                              await context.read<AppState>().resetPassword(emailController.text);
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resetSentLabel)));
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                              }
                                            }
                                          }
                                        },
                                        child: Text(sendLabel),
                                      )
                                    ],
                                  ),
                                );
                              },
                              child: Text(forgotPasswordLabel, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Login Button
                          ElevatedButton(
                            onPressed: () async {
                              final email = _emailController.text.trim();
                              final password = _passwordController.text;
                              if (email.isEmpty || password.isEmpty) return;
                              
                              try {
                                bool isNewUser = await context.read<AppState>().loginWithEmail(email, password);
                                _onLoginSuccess(isNewUser);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 8,
                              shadowColor: AppColors.primary.withValues(alpha: 0.5),
                            ),
                            child: context.watch<AppState>().isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(loginBtnLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 24),
                          
                          // Or Divider
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.surfaceAlt)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(orDivider, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                              ),
                              const Expanded(child: Divider(color: AppColors.surfaceAlt)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Google Button
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                bool isNewUser = await context.read<AppState>().loginWithGoogle();
                                _onLoginSuccess(isNewUser);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.black87),
                            label: Text(googleBtnLabel, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.black12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Apple Button (Apple App Store Guideline 4.8)
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                bool isNewUser = await context.read<AppState>().loginWithApple();
                                _onLoginSuccess(isNewUser);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.apple, size: 28, color: Colors.white),
                            label: Text(appleBtnLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.black),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 🎾 Accès Libre / Invité (BeachScore & Tournois)
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MainNavigationScreen(initialIndex: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.scoreboard_rounded, color: AppColors.gold, size: 20),
                            label: Text(
                              guestBtnLabel,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.gold, width: 1.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // EULA / CGU Notice (Apple Guideline 1.2)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              eulaNotice,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 10, height: 1.3),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Sign Up link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(noAccountLabel, style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600)),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                                  );
                                },
                                child: Text(signUpActionLabel, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
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
    );
  }
}
