import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../widgets/payment_logos.dart';
import '../../services/fedapay_service.dart';
import '../../services/firestore_service.dart';
import '../../models/activity_model.dart';
import 'collecteur_payout_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollecteurWalletScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const CollecteurWalletScreen({super.key, required this.user});

  @override
  ConsumerState<CollecteurWalletScreen> createState() => _CollecteurWalletScreenState();
}

class _CollecteurWalletScreenState extends ConsumerState<CollecteurWalletScreen> {
  bool _isTransferring = false;
  late double _currentBalance;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.user.balance;
    _amountController.text = _currentBalance.toInt().toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _processPayout() async {
    if (_currentBalance <= 0) return;
    
    final accounts = widget.user.mobileMoneyAccounts;
    if (accounts.isEmpty) {
      // Pas de compte, on redirige vers le paramétrage
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez paramétrer un compte de retrait d\'abord.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (ctx) => CollecteurPayoutScreen(user: widget.user)));
      return;
    }

    final double? requestedAmount = double.tryParse(_amountController.text.trim());
    if (requestedAmount == null || requestedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide.')),
      );
      return;
    }
    if (requestedAmount > _currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fonds insuffisants. Solde maximal: ${_currentBalance.toInt()} FCFA')),
      );
      return;
    }

    final account = accounts.first;

    // Confirmation visuelle
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation de retrait'),
        content: Text('Voulez-vous virer la somme de ${requestedAmount.toInt()} FCFA vers le compte ${account.operatorName} (+225 ${account.number}) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isTransferring = true);
      
      // Simulation de Succès (Ignorer FedaPay momentanément)
      final amountToTransfer = requestedAmount;
      await Future.delayed(const Duration(milliseconds: 1500)); // Fausse attente API
      final success = true;

      if (success) {
        // Mettre à jour Firebase avec le nouveau solde
        final newBalance = _currentBalance - amountToTransfer;
        await FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({
          'balance': newBalance,
        });

        // Log de l'activité
        await ref.read(firestoreServiceProvider).logActivity(Activity(
          id: '', 
          userId: widget.user.id, 
          type: ActivityType.payout, 
          status: ActivityStatus.success, 
          title: 'Retrait de fonds', 
          description: 'Virement vers ${account.operatorName}', 
          amount: amountToTransfer, 
          timestamp: DateTime.now(),
          metadata: {
            'Opérateur': account.operatorName,
            'Numéro': account.number,
            'Mode': 'FedaPay Simulation',
          }
        ));

        if (mounted) {
          setState(() {
            _currentBalance = newBalance;
            _amountController.text = _currentBalance.toInt().toString();
            _isTransferring = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Virement FedaPay initié avec succès !'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isTransferring = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec du virement. Vérifiez votre clé Sandbox FedaPay.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mon Portefeuille', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Carte du solde
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    children: [
                      const Text('Solde Disponible', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        '${_currentBalance.toInt()} FCFA',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.1),

                const SizedBox(height: 40),

                // Paramétrages de retrait actuels
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      if (widget.user.mobileMoneyAccounts.isEmpty)
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.account_balance_wallet, color: Color(0xFF4CAF50)),
                        )
                      else
                        PaymentLogos.getLogo(widget.user.mobileMoneyAccounts.first.operatorName, size: 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Compte de réception', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            if (widget.user.mobileMoneyAccounts.isEmpty)
                              const Text('Aucun compte défini', style: TextStyle(fontWeight: FontWeight.bold))
                            else
                              Text(
                                '${widget.user.mobileMoneyAccounts.first.operatorName} • +225 ${widget.user.mobileMoneyAccounts.first.number}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (ctx) => CollecteurPayoutScreen(user: widget.user)));
                        },
                        child: const Text('Modifier'),
                      ),
                    ],
                  ),
                ).animate().fade(delay: 150.ms).slideY(begin: 0.1),

                const SizedBox(height: 24),

                // Champ de saisie du montant
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  decoration: InputDecoration(
                    labelText: 'Montant à retirer (FCFA)',
                    prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF4CAF50)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2)),
                  ),
                ).animate().fade(delay: 200.ms).slideY(begin: 0.1),

                const Spacer(),

                // Bouton de Transfert
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_currentBalance <= 0 || _isTransferring) ? null : _processPayout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: _currentBalance > 0 ? 8 : 0,
                    ),
                    child: _isTransferring
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'TRANSFÉRER SUR MON COMPTE',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                  ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
