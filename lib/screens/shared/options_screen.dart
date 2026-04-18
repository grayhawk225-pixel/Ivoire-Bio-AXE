import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OptionsScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const OptionsScreen({super.key, required this.user});

  @override
  ConsumerState<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends ConsumerState<OptionsScreen> {
  // Identity & Contact Controllers
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _cityController;
  late TextEditingController _communeController;
  late TextEditingController _addressController;
  late TextEditingController _bioController;
  
  // Specific Controllers
  late TextEditingController _vehicleTypeController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _professionController;

  // Security Controllers
  final _currentPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  final _emailResetController = TextEditingController();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _altPhoneController = TextEditingController(text: widget.user.alternativePhone);
    _cityController = TextEditingController(text: widget.user.city);
    _communeController = TextEditingController(text: widget.user.commune);
    _addressController = TextEditingController(text: widget.user.deliveryAddress ?? '');
    _bioController = TextEditingController(text: widget.user.bio);
    
    _vehicleTypeController = TextEditingController(text: widget.user.vehicleType ?? '');
    _emergencyContactController = TextEditingController(text: widget.user.emergencyContact ?? '');
    _professionController = TextEditingController(text: widget.user.profession ?? '');
    
    _emailResetController.text = widget.user.email;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _altPhoneController.dispose();
    _cityController.dispose();
    _communeController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _vehicleTypeController.dispose();
    _emergencyContactController.dispose();
    _professionController.dispose();
    _currentPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    _emailResetController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() => _isProcessing = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      
      final updatedUser = widget.user.copyWith(
        phoneNumber: _phoneController.text.trim(),
        alternativePhone: _altPhoneController.text.trim(),
        city: _cityController.text.trim(),
        commune: _communeController.text.trim(),
        deliveryAddress: _addressController.text.trim(),
        bio: _bioController.text.trim(),
        vehicleType: widget.user.role == UserRole.collecteur ? _vehicleTypeController.text.trim() : null,
        emergencyContact: widget.user.role == UserRole.collecteur ? _emergencyContactController.text.trim() : null,
        profession: widget.user.role == UserRole.acheteur ? _professionController.text.trim() : null,
      );

      await firestoreService.updateUser(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Profil mis à jour sur le cloud !'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la mise à jour : $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updatePassword() async {
    final current = _currentPwdController.text;
    final newP = _newPwdController.text;
    final confirm = _confirmPwdController.text;

    if (newP != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: Colors.orange));
      return;
    }
    if (newP.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum 6 caractères'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final auth = FirebaseAuth.instance;
      AuthCredential credential = EmailAuthProvider.credential(email: widget.user.email, password: current);
      await auth.currentUser!.reauthenticateWithCredential(credential);
      await auth.currentUser!.updatePassword(newP);
      
      if (mounted) {
        _currentPwdController.clear();
        _newPwdController.clear();
        _confirmPwdController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Mot de passe modifié !'), backgroundColor: Colors.green));
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Erreur de sécurité";
      if (e.code == 'wrong-password') msg = "Mot de passe actuel incorrect";
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4CAF50);
    const bgColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Profil & Paramètres', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── SECTION : INFORMATIONS PERSONNELLES ──────────────────
                _buildSectionTitle('Informations Personnelles', Icons.person_outline_rounded),
                _buildCard(
                  child: Column(
                    children: [
                      // Champs NON MODIFIABLES
                      _buildReadOnlyField('Nom Complet', widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Non renseigné', Icons.badge_outlined),
                      const Divider(height: 24),
                      _buildReadOnlyField('Email de connexion', widget.user.email, Icons.alternate_email_rounded),
                      const Divider(height: 24),
                      _buildReadOnlyField('Rôle sur la plateforme', widget.user.role.name.toUpperCase(), Icons.admin_panel_settings_outlined),
                      
                      if (widget.user.role == UserRole.restaurateur) ...[
                        const Divider(height: 24),
                        _buildReadOnlyField('Nom de l\'établissement', widget.user.restaurantName ?? 'Inconnu', Icons.restaurant_rounded),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Champs MODIFIABLES
                      _buildEditableField('Numéro de téléphone', _phoneController, Icons.phone_iphone_rounded, TextInputType.phone),
                      _buildEditableField('Numéro alternatif', _altPhoneController, Icons.phone_callback_rounded, TextInputType.phone),
                      _buildEditableField('Ville', _cityController, Icons.location_city_rounded, TextInputType.text),
                      _buildEditableField('Commune', _communeController, Icons.map_outlined, TextInputType.text),
                      _buildEditableField('Adresse précise / Repères', _addressController, Icons.pin_drop_outlined, TextInputType.text),
                      
                      if (widget.user.role == UserRole.collecteur) ...[
                        _buildEditableField('Type de véhicule', _vehicleTypeController, Icons.delivery_dining_rounded, TextInputType.text),
                        _buildEditableField('Contact d\'urgence', _emergencyContactController, Icons.contact_emergency_rounded, TextInputType.phone),
                      ],
                      
                      if (widget.user.role == UserRole.acheteur) ...[
                        _buildEditableField('Ma profession', _professionController, Icons.work_outline_rounded, TextInputType.text),
                      ],

                      const SizedBox(height: 12),

                      _buildEditableField('Ma présentation / Bio', _bioController, Icons.description_outlined, TextInputType.multiline, maxLines: 2),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Enregistrer le profil', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ─── SECTION : SÉCURITÉ ────────────────────────────────────
                _buildSectionTitle('Sécurité du Compte', Icons.lock_outline_rounded),
                _buildCard(
                  child: Column(
                    children: [
                      _buildPasswordField(_currentPwdController, 'Mot de passe actuel'),
                      const SizedBox(height: 12),
                      _buildPasswordField(_newPwdController, 'Nouveau mot de passe'),
                      const SizedBox(height: 12),
                      _buildPasswordField(_confirmPwdController, 'Confirmer le nouveau'),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isProcessing ? null : _updatePassword,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: const BorderSide(color: primaryColor),
                            foregroundColor: primaryColor,
                          ),
                          child: const Text('Changer mon mot de passe', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ─── SECTION : DANGER ZONE ───────────────────────────────
                Center(
                  child: TextButton.icon(
                    onPressed: _isProcessing ? null : _showDeleteDialog,
                    icon: const Icon(Icons.no_accounts_rounded, color: Colors.black38, size: 20),
                    label: const Text('Supprimer mon compte définitivement', style: TextStyle(color: Colors.black38, fontSize: 13, decoration: TextDecoration.underline)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isProcessing)
            Container(color: Colors.white60, child: const Center(child: CircularProgressIndicator(color: primaryColor))),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: Colors.black38),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Icon(Icons.lock_rounded, size: 14, color: Colors.black12),
      ],
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, IconData icon, TextInputType keyboard, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: const Color(0xFF4CAF50)),
              hintText: 'Entrez ${label.toLowerCase()}',
              filled: true,
              fillColor: const Color(0xFFF1F3F4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
        prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18, color: Colors.black38),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Attention'),
        content: const Text('Cette action supprimera toutes vos données sur Ivoire Bio-Axe. Continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
