import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../widgets/payment_logos.dart';
import '../../services/auth_service.dart';
import '../../services/multi_account_service.dart';
import '../auth/login_screen.dart';
import 'support_screen.dart';
import 'options_screen.dart';
import 'premium_history_screen.dart';


class ProfileDrawer extends ConsumerStatefulWidget {
  final AppUser user;
  const ProfileDrawer({super.key, required this.user});

  @override
  ConsumerState<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends ConsumerState<ProfileDrawer> {
  // Opérateurs disponibles en Côte d'Ivoire
  static const List<Map<String, dynamic>> _operators = [
    {'name': 'Wave CI',      'color': Color(0xFF00BFFF), 'icon': Icons.waves},
    {'name': 'Orange Money', 'color': Color(0xFFFF6600), 'icon': Icons.circle},
    {'name': 'MTN MoMo',     'color': Color(0xFFFFCC00), 'icon': Icons.phone_android},
    {'name': 'Moov Money',   'color': Color(0xFF0099CC), 'icon': Icons.mobile_friendly},
  ];

  late TextEditingController _numberController;
  String? _selectedOperator;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _showOtherAccounts = false;
  
  late List<MobileMoneyAccount> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = List.from(widget.user.mobileMoneyAccounts);
    _numberController = TextEditingController();
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.restaurateur: return 'Générateur';
      case UserRole.collecteur:   return 'Collecteur';
      case UserRole.acheteur:     return 'Acheteur';
      case UserRole.admin:        return 'Administrateur';
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.restaurateur: return Colors.orange;
      case UserRole.collecteur:   return const Color(0xFF4CAF50);
      case UserRole.acheteur:     return Colors.blue;
      case UserRole.admin:        return Colors.purple;
    }
  }

  Future<void> _savePaymentInfo() async {
    final number = _numberController.text.trim();
    if (number.isEmpty || _selectedOperator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un numéro et choisir un opérateur.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final raw = number.replaceAll(' ', '');
    if (raw.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le numéro doit contenir exactement 10 chiffres.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_accounts.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez atteint la limite de 4 numéros.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newAccount = MobileMoneyAccount(number: raw, operatorName: _selectedOperator!);
      final updatedList = List<MobileMoneyAccount>.from(_accounts)..add(newAccount);

      await FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({
        'mobileMoneyAccounts': updatedList.map((e) => e.toMap()).toList(),
      });
      
      if (mounted) {
        setState(() {
          _accounts = updatedList;
          _isEditing = false;
          _numberController.clear();
          _selectedOperator = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Numéro ajouté avec succès !'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePaymentInfo(int index) async {
    setState(() => _isSaving = true);
    try {
      final updatedList = List<MobileMoneyAccount>.from(_accounts)..removeAt(index);
      await FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({
        'mobileMoneyAccounts': updatedList.map((e) => e.toMap()).toList(),
      });
      
      if (mounted) {
        setState(() => _accounts = updatedList);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro supprimé avec succès.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  void _signOut() async {
    Navigator.of(context).pop();
    await FirebaseAuth.instance.signOut();
  }

  void _switchAccount(SavedAccount account) async {
    setState(() => _isSaving = true); // Recycle _isSaving variable for a loading state
    try {
      final authService = ref.read(authServiceProvider);
      await FirebaseAuth.instance.signOut();
      await authService.signIn(account.email, account.password);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur basculement: $e')));
      }
    }
  }

  void _addNewAccount() {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user.role;
    final roleColor = _roleColor(role);

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── En-tête du profil ─────────────────────────────────────────
            InkWell(
              onTap: () {
                setState(() => _showOtherAccounts = !_showOtherAccounts);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [roleColor, roleColor.withOpacity(0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    child: const Icon(Icons.person_rounded, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.user.email,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _roleLabel(role),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Icon(
                        _showOtherAccounts ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),

            // ── Reste de la page défilable ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showOtherAccounts) ...[
                      _buildMultiAccountSection(),
                      const Divider(height: 1),
                    ],
                    
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Comptes de Paiement',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                          child: Text('${_accounts.length}/4', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Numéros Mobile Money pour vos opérations.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    if (!_isEditing) ...[
                      if (_accounts.isEmpty) 
                        _buildNoNumberBanner()
                      else 
                        ..._accounts.asMap().entries.map((e) => _buildSavedNumberCard(e.value, e.key, roleColor)).toList(),

                      const SizedBox(height: 12),
                      
                      if (_accounts.length < 4) 
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter un numéro'),
                          onPressed: () => setState(() => _isEditing = true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: roleColor,
                            side: BorderSide(color: roleColor),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ],

                    if (_isEditing) ...[
                      const Text('Opérateur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _operators.map((op) {
                          final isSelected = _selectedOperator == op['name'];
                          final opColor = op['color'] as Color;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedOperator = op['name'] as String),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? opColor.withOpacity(0.12) : Colors.grey[100],
                                border: Border.all(
                                  color: isSelected ? opColor : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PaymentLogos.getLogo(op['name'] as String, size: 24),
                                  const SizedBox(width: 6),
                                  Text(
                                    op['name'] as String,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? opColor : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      const Text('Numéro de téléphone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _numberController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Ex: 07 XX XX XX XX',
                          prefixText: '+225 ',
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFF4CAF50)),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => setState(() {
                                _isEditing = false;
                                _numberController.clear();
                                _selectedOperator = null;
                              }),
                              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: _isSaving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save_rounded, size: 18),
                              label: Text(_isSaving ? '...' : 'Enregistrer'),
                              onPressed: _isSaving ? null : _savePaymentInfo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: roleColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ), // Fin du padding pour les paramètres de paiement
                    
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.settings_suggest_rounded, color: Colors.blue),
                        title: const Text('Options & Paramètres', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Sécurité, adresse et collectes', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => OptionsScreen(user: widget.user)));
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        hoverColor: Colors.blue.withOpacity(0.05),
                      ),
                    ),

                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF4CAF50)),
                        title: const Text('Support Client', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Contactez notre équipe', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => SupportScreen(user: widget.user)));
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        hoverColor: Colors.green.withOpacity(0.05),
                      ),
                    ),

                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.history_rounded, color: Colors.orange),
                        title: const Text('Mon Historique', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Toutes vos activités', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PremiumHistoryScreen(user: widget.user)));

                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        hoverColor: Colors.orange.withOpacity(0.05),
                      ),
                    ),

                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: ListTile(
                        leading: const Icon(Icons.logout_rounded, color: Colors.red),
                        title: const Text('Se déconnecter', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Fermer la session actuelle', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        onTap: _signOut,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        hoverColor: Colors.red.withOpacity(0.05),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ].animate(interval: 30.ms).fade(duration: 400.ms, curve: Curves.easeOutQuad).slideX(begin: -0.1),
        ),
      ),
    );
  }

  Widget _buildMultiAccountSection() {
    final accounts = ref.watch(multiAccountProvider).where((acc) => acc.uid != widget.user.id).toList();

    return Container(
      color: Colors.grey[50], // Léger fond pour se détacher
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mes Autres Comptes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          ...accounts.map((acc) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[200],
                  child: Text(acc.email[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
                ),
                title: Text(acc.identifier, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('${acc.role} • ${acc.email}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.swap_horiz, size: 20, color: Colors.grey),
                onTap: () => _switchAccount(acc),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.transparent,
              child: Icon(Icons.add_circle_outline, color: _roleColor(widget.user.role), size: 24),
            ),
            title: Text('Ajouter un compte existant', style: TextStyle(fontSize: 14, color: _roleColor(widget.user.role), fontWeight: FontWeight.w600)),
            onTap: _addNewAccount,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedNumberCard(MobileMoneyAccount account, int index, Color roleColor) {
    final opData = _operators.firstWhere(
      (op) => op['name'] == account.operatorName,
      orElse: () => {'color': roleColor, 'icon': Icons.phone},
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (opData['color'] as Color).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (opData['color'] as Color).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          PaymentLogos.getLogo(opData['name'] as String, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.operatorName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: opData['color'] as Color, fontSize: 13),
                ),
                Text('+225 ${account.number}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (index == 0) // Indicateur de "Principal" pour le premier compte
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(4)),
              child: const Text('Principal', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _deletePaymentInfo(index),
            tooltip: 'Supprimer ce numéro',
          ),
        ],
      ),
    );
  }

  Widget _buildNoNumberBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber[700], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aucun numéro enregistré. Ajoutez-en un pour accélérer vos opérations.',
              style: TextStyle(color: Colors.amber[800], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
