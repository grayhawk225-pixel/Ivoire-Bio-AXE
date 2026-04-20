import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/multi_account_service.dart';
import 'register_screen.dart';
import '../../main.dart'; // Import requis pour rootScaffoldMessengerKey


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService(FirebaseAuth.instance, FirebaseFirestore.instance);
      final userModel = await authService.signIn(email, password);
      
      if (userModel != null) {
        final account = SavedAccount(
          uid: userModel.id,
          email: email,
          password: password,
          role: userModel.role.name,
          identifier: userModel.restaurantName ?? userModel.email,
        );
        ref.read(multiAccountProvider.notifier).saveAccount(account);
        
        // Redirection automatique : Si l'écran a été poussé (ex: ajout de compte), on le ferme.
        // Sinon le AuthWrapper de main.dart rafraîchira l'écran d'accueil.
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Compte reconnu mais profil non trouvé dans la base de données.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Une erreur est survenue.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        message = 'Email ou mot de passe incorrect. Veuillez vérifier vos informations.';
      } else if (e.code == 'network-request-failed') {
        message = 'Erreur réseau. Vérifiez votre connexion internet.';
      } else if (e.code == 'user-disabled') {
        message = 'Ce compte a été désactivé.';
      } else {
        message = 'Erreur d\'authentification: ${e.message}';
      }
      
      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mot de passe oublié ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Saisissez votre adresse e-mail pour recevoir un lien de réinitialisation.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (emailCtrl.text.isEmpty) return;
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCtrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Email de réinitialisation envoyé ! Veuillez vérifier votre boîte mail.'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (ctx.mounted) {
                  rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
                }
              }

            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.eco_rounded,
                size: 80,
                color: Color(0xFF4CAF50),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ivoire Bio-Axe',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Zéro Déchet Organique',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              _buildTextField('Email', Icons.email, _emailController),
              const SizedBox(height: 16),
              _buildTextField('Mot de passe', Icons.lock, _passwordController, obscure: _obscurePassword, isPassword: true),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Mot de passe oublié ?', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text('Créer un compte'),
              ),
            ].animate(interval: 50.ms).fade(duration: 600.ms, curve: Curves.easeOut).slideY(begin: 0.2, curve: Curves.easeOutBack),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool obscure = false, bool isPassword = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.phone : (label.contains('Email') ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
