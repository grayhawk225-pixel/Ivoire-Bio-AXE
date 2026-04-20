import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/multi_account_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/email_service.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.restaurateur;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Controllers communs
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();


  // Controllers Restaurateur
  final _restaurantNameController = TextEditingController();

  // Controllers Collecteur
  String? _vehicleType;
  final _idCardController = TextEditingController(); // Numéro CNI provisoire

  // Controllers Acheteur
  String? _profession;
  final _deliveryAddressController = TextEditingController();

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Enregistrement de la position GPS (Obligatoire pour les métiers du terrain/restaurateur)
        Position? position;
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception("Veuillez activer la localisation GPS (Indispensable pour l'itinéraire de collecte).");
        }
        
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception("L'autorisation GPS est refusée.");
          }
        }
        
        if (permission == LocationPermission.deniedForever) {
          throw Exception("L'autorisation GPS est définitivement refusée dans les paramètres.");
        }
        
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

        final appUser = AppUser(
          id: '', // Sera rempli par Firebase Auth
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          role: _selectedRole,
          createdAt: DateTime.now(),
          phoneNumber: _phoneController.text.trim(),
          location: GeoPoint(position.latitude, position.longitude),
          restaurantName: _selectedRole == UserRole.restaurateur ? _restaurantNameController.text : null,
          vehicleType: _selectedRole == UserRole.collecteur ? _vehicleType : null,
          idCardUrl: _selectedRole == UserRole.collecteur ? _idCardController.text : null,
          profession: _selectedRole == UserRole.acheteur ? _profession : null,
          deliveryAddress: _selectedRole == UserRole.acheteur ? _deliveryAddressController.text : null,
        );


        final authService = AuthService(FirebaseAuth.instance, FirebaseFirestore.instance);
        
        // 1. Création du compte Email/Password
        final newUser = await authService.register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          appUser,
          sendEmailVerification: true, // Toujours demander par email
        );

        if (newUser != null) {
          
          final account = SavedAccount(
            uid: newUser.id,
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            role: newUser.role.name,
            identifier: newUser.restaurantName ?? newUser.email,
          );
          ref.read(multiAccountProvider.notifier).saveAccount(account);

          // Déclenchement automatique de l'envoi de l'e-mail de bienvenue en arrière-plan
          EmailService.sendWelcomeEmail(
            toEmail: _emailController.text.trim(),
            role: _selectedRole.toString().split('.').last,
          );

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inscription réussie ! Vérifiez votre email.'),
              backgroundColor: Colors.green,
            ),
          );

          // Retour à l'AuthWrapper pour afficher l'écran de vérification
          if (mounted) Navigator.of(context).pop();
        }
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        String errorMessage = 'Une erreur est survenue lors de l\'inscription.';
        if (e.code == 'weak-password') {
          errorMessage = 'Erreur : Le mot de passe est trop faible (6 caractères minimum).';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'Erreur : Cet email est déjà utilisé par un autre compte.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Erreur : Le format de l\'email est invalide.';
        } else {
          errorMessage = 'Erreur: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez corriger les erreurs dans le formulaire.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Fonctions SMS retirées

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Créer un compte', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRoleSelector(),
                const SizedBox(height: 32),
                
                // Informations communes
                const Text('Informations Générales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTextField('Nom Complet', Icons.person, _fullNameController),
                const SizedBox(height: 16),
                _buildTextField('Email', Icons.email, _emailController),
                const SizedBox(height: 16),
                _buildTextField('Mot de passe', Icons.lock, _passwordController, obscure: _obscurePassword, isPassword: true),
                const SizedBox(height: 16),
                
                // Champ Téléphone sans bouton Vérifier
                _buildTextField('Numéro de Téléphone', Icons.phone, _phoneController, isNumber: true, prefixText: '+225 '),

                const SizedBox(height: 24),


                
                // Champs Spécifiques selon le rôle
                if (_selectedRole == UserRole.restaurateur) ..._buildRestaurateurFields(),
                if (_selectedRole == UserRole.collecteur) ..._buildCollecteurFields(),
                if (_selectedRole == UserRole.acheteur) ..._buildAcheteurFields(),

                const SizedBox(height: 48),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'S\'inscrire',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
              ].animate(interval: 50.ms).fade(duration: 500.ms).slideY(begin: 0.15, curve: Curves.easeOutBack),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Je suis un :', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roleButton('Générateur', Icons.restaurant, UserRole.restaurateur),
            _roleButton('Collecteur', Icons.delivery_dining, UserRole.collecteur),
            _roleButton('Acheteur', Icons.eco, UserRole.acheteur),
          ],
        ),
      ],
    );
  }

  Widget _roleButton(String title, IconData icon, UserRole role) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? const Color(0xFF4CAF50) : Colors.grey),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF4CAF50) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRestaurateurFields() {
    return [
      const Text('Informations Restaurant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _buildTextField('Nom du Restaurant', Icons.store, _restaurantNameController),
    ];
  }

  List<Widget> _buildCollecteurFields() {
    return [
      const Text('Logistique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Type de véhicule',
          prefixIcon: const Icon(Icons.two_wheeler, color: Color(0xFF4CAF50)),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        value: _vehicleType,
        items: ['Tricycle', 'Wottro', 'Camionnette'].map((val) {
          return DropdownMenuItem(value: val, child: Text(val));
        }).toList(),
        onChanged: (val) => setState(() => _vehicleType = val),
      ),
      const SizedBox(height: 16),
      _buildTextField('Numéro Pièce Identité', Icons.badge, _idCardController),
    ];
  }

  List<Widget> _buildAcheteurFields() {
    return [
      const Text('Informations Acheteur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Profession',
          prefixIcon: const Icon(Icons.work, color: Color(0xFF4CAF50)),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        value: _profession,
        items: ['Éleveur', 'Jardinier / Agriculteur'].map((val) {
          return DropdownMenuItem(value: val, child: Text(val));
        }).toList(),
        onChanged: (val) => setState(() => _profession = val),
      ),
      const SizedBox(height: 16),
      _buildTextField('Adresse de livraison par défaut', Icons.location_on, _deliveryAddressController),
    ];
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool obscure = false, bool isNumber = false, bool isPassword = false, bool enabled = true, String? prefixText}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.phone : (label.contains('Email') ? TextInputType.emailAddress : TextInputType.text),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Ce champ est requis';
        if (label.contains('Email') && !value.contains('@')) return 'Veuillez entrer un email valide';
        if (isPassword && value.length < 6) return 'Le mot de passe doit faire au moins 6 caractères';
        if (isNumber && label.contains('Téléphone')) {
          String phoneRaw = value.replaceAll(' ', '');
          if (phoneRaw.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phoneRaw)) {
            return 'Entrez exactement 10 chiffres';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
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
