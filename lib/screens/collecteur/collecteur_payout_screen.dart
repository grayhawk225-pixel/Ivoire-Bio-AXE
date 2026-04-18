import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../widgets/payment_logos.dart';

class CollecteurPayoutScreen extends StatefulWidget {
  final AppUser user;
  const CollecteurPayoutScreen({super.key, required this.user});

  @override
  State<CollecteurPayoutScreen> createState() => _CollecteurPayoutScreenState();
}

class _CollecteurPayoutScreenState extends State<CollecteurPayoutScreen> {
  final _numberController = TextEditingController();
  String? _selectedOperator;
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _operators = [
    {'name': 'Wave CI',       'color': Color(0xFF00BFFF), 'icon': Icons.waves,           'logo': 'https://play-lh.googleusercontent.com/I5GqK5fG49IeT4Z2cQ5B8S1l7P_S_SXYP8K_jQK_T3j5n8-U4eP_M9r9l31X9_P_W51p=w240'},
    {'name': 'MTN MoMo',      'color': Color(0xFFFFCC00), 'icon': Icons.phone_android,   'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/MTN_Logo.png/600px-MTN_Logo.png'},
    {'name': 'Orange Money',  'color': Color(0xFFFF6600), 'icon': Icons.circle,          'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Orange_logo.svg/600px-Orange_logo.svg.png'},
    {'name': 'Moov Money',    'color': Color(0xFF0099CC), 'icon': Icons.mobile_friendly, 'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Moov_Africa_logo.png/320px-Moov_Africa_logo.png'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.user.mobileMoneyAccounts.isNotEmpty) {
      _numberController.text = widget.user.mobileMoneyAccounts.first.number;
      _selectedOperator = widget.user.mobileMoneyAccounts.first.operatorName;
    }
  }

  Future<void> _save() async {
    if (_selectedOperator == null || _numberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un opérateur et entrer votre numéro'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    
    final updatedList = List<MobileMoneyAccount>.from(widget.user.mobileMoneyAccounts);
    if (updatedList.isNotEmpty) {
      updatedList[0] = MobileMoneyAccount(number: _numberController.text.trim(), operatorName: _selectedOperator!);
    } else {
      updatedList.add(MobileMoneyAccount(number: _numberController.text.trim(), operatorName: _selectedOperator!));
    }

    await FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({
      'mobileMoneyAccounts': updatedList.map((e) => e.toMap()).toList(),
    });
    
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Compte de virement mis à jour : $_selectedOperator ${_numberController.text}'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Compte de Virement', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white, size: 36),
                  SizedBox(height: 12),
                  Text('Compte de réception', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 4),
                  Text('Votre salaire sera automatiquement viré sur ce numéro après chaque collecte validée.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Choisissez votre opérateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5),
              itemCount: _operators.length,
              itemBuilder: (ctx, i) {
                final op = _operators[i];
                final isSelected = _selectedOperator == op['name'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedOperator = op['name'] as String),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? (op['color'] as Color).withOpacity(0.15) : Colors.white,
                      border: Border.all(color: isSelected ? op['color'] as Color : Colors.grey[300]!, width: isSelected ? 2 : 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PaymentLogos.getLogo(op['name'] as String, size: 40),
                        const SizedBox(width: 8),
                        Text(op['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? op['color'] as Color : Colors.black87)),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Numéro Mobile Money', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'Ex: 07 XX XX XX XX',
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF4CAF50)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.user.mobileMoneyAccounts.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text('Actuel : ${widget.user.mobileMoneyAccounts.first.operatorName} • ${widget.user.mobileMoneyAccounts.first.number}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ]),
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer ce compte de virement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
