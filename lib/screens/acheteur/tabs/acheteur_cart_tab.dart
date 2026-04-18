import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../models/activity_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../services/fedapay_service.dart';
import '../../../data/location_data.dart';

class AcheteurCartTab extends ConsumerStatefulWidget {
  final AppUser user;
  const AcheteurCartTab({super.key, required this.user});

  @override
  ConsumerState<AcheteurCartTab> createState() => _AcheteurCartTabState();
}

class _AcheteurCartTabState extends ConsumerState<AcheteurCartTab> {
  bool _isProcessing = false;
  bool _isDelivery = false; // false = Retrait, true = Livraison
  
  // Champs d'adresse détaillés
  City? _selectedCity;
  String? _selectedCommune;
  final TextEditingController _quartierController = TextEditingController();
  final TextEditingController _rueController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Par défaut Abidjan
    _selectedCity = ivoryCoastCities.first;
    _selectedCommune = _selectedCity?.communes.first;
  }

  @override
  void dispose() {
    _quartierController.dispose();
    _rueController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _checkout() async {
    final cart = ref.read(cartProvider.notifier);
    final totalAmount = cart.totalAmount + (_isDelivery ? 1500 : 0);
    if (totalAmount <= 0) return;

    if (_isDelivery) {
      if (_selectedCity == null || _selectedCommune == null || _quartierController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir au moins la Ville, Commune et Quartier')),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);
    
    try {
      final fedaPay = FedaPayService();
      final success = await fedaPay.processPayment(
        context: context,
        amount: totalAmount.toInt(),
        description: 'Bio-Axe Shop : ${cart.state.length} articles',
        customerEmail: widget.user.email,
        customerName: widget.user.restaurantName ?? widget.user.email,
      );

      if (success) {
        final firestore = ref.read(firestoreServiceProvider);
        
        final addressSummary = _isDelivery 
          ? '${_selectedCity!.name}, ${_selectedCommune!}, ${_quartierController.text}, ${_rueController.text}'
          : 'Point Relais Bio-Axe';

        await firestore.logActivity(Activity(
          id: '',
          userId: widget.user.id,
          type: ActivityType.purchase,
          status: ActivityStatus.success,
          title: 'Commande Bio-Shop',
          description: 'Achat de ${cart.totalCount} produits bio.',
          amount: totalAmount,
          timestamp: DateTime.now(),
          metadata: {
            'Articles': cart.state.map((e) => '${e.quantity}x ${e.name}').join(', '),
            'Mode': _isDelivery ? 'Livraison' : 'Retrait',
            'Ville': _selectedCity?.name ?? '',
            'Commune': _selectedCommune ?? '',
            'Quartier': _quartierController.text,
            'Instructions': _instructionsController.text,
            'Adresse_Complete': addressSummary,
          }
        ));

        cart.clearCart();

        if (mounted) {
          _showSuccessDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 80),
            const SizedBox(height: 24),
            const Text('Succès !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Votre commande est en préparation.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalAmount = ref.watch(cartProvider.notifier).totalAmount;

    if (cartItems.isEmpty) return _buildEmptyCart();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 260),
          children: [
            const Text('Articles sélectionnés', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...cartItems.map((item) => _buildCartItemCard(item)),
            const SizedBox(height: 32),
            const Text('Mode de réception', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDeliveryToggle(),
            if (_isDelivery) ...[
              const SizedBox(height: 24),
              _buildDetailedAddressForm(),
            ],
          ],
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildOrderSummary(totalAmount),
        ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('Votre panier est vide', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(item.image, width: 50, height: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _qtyBtn(Icons.remove_rounded, () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4CAF50))),
                    ),
                    _qtyBtn(Icons.add_rounded, () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1)),
                    const Spacer(),
                    Text('${item.price} F', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.black26, size: 20),
            onPressed: () => ref.read(cartProvider.notifier).removeItem(item.id),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF4CAF50)),
      ),
    );
  }


  Widget _buildDeliveryToggle() {
    return Row(
      children: [
        Expanded(
          child: _toggleBtn(false, Icons.storefront, 'Retrait'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _toggleBtn(true, Icons.local_shipping, 'Livraison'),
        ),
      ],
    );
  }

  Widget _toggleBtn(bool val, IconData icon, String label) {
    final isSelected = _isDelivery == val;
    return GestureDetector(
      onTap: () => setState(() => _isDelivery = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedAddressForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adresse de Livraison', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
          const SizedBox(height: 16),
          // Ville
          DropdownButtonFormField<City>(
            value: _selectedCity,
            decoration: _inputDeco('Ville'),
            items: ivoryCoastCities.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (val) {
              setState(() {
                _selectedCity = val;
                _selectedCommune = val?.communes.first;
              });
            },
          ),
          const SizedBox(height: 12),
          // Commune
          DropdownButtonFormField<String>(
            value: _selectedCommune,
            decoration: _inputDeco('Commune'),
            items: _selectedCity?.communes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _selectedCommune = val),
          ),
          const SizedBox(height: 12),
          // Quartier
          TextField(controller: _quartierController, decoration: _inputDeco('Quartier', hint: 'ex: Riviera 3')),
          const SizedBox(height: 12),
          // Rue
          TextField(controller: _rueController, decoration: _inputDeco('Rue / N° Porte', hint: 'ex: Rue Ministre')),
          const SizedBox(height: 12),
          // Instructions
          TextField(
            controller: _instructionsController,
            maxLines: 2,
            decoration: _inputDeco('Instructions d\'arrivée', hint: 'ex: Près de la grande citerne...'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildOrderSummary(double total) {
    final finalTotal = total + (_isDelivery ? 1500 : 0);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Commande', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  Text('${finalTotal.toInt()} F', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isProcessing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Commander maintenant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
