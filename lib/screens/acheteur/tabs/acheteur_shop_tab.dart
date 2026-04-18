import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/product_service.dart';

class AcheteurShopTab extends ConsumerStatefulWidget {
  final AppUser user;
  const AcheteurShopTab({super.key, required this.user});

  @override
  ConsumerState<AcheteurShopTab> createState() => _AcheteurShopTabState();
}

class _AcheteurShopTabState extends ConsumerState<AcheteurShopTab> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _localQuantities = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialiser les quantités par défaut pour tous les produits
    for (var p in ProductService.products) {
      _localQuantities[p.id] = 1;
    }
  }

  void _updateLocalQuantity(String id, int delta) {
    setState(() {
      int current = _localQuantities[id] ?? 1;
      int next = current + delta;
      if (next >= 1 && next <= 20) {
        _localQuantities[id] = next;
      }
    });
  }

  void _addToCart(CartItem item) {
    final quantity = _localQuantities[item.id] ?? 1;
    ref.read(cartProvider.notifier).addItem(item.copyWith(quantity: quantity));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $quantity x ${item.name} ajoutés'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = ProductService.searchProducts(_searchQuery);

    return Column(
      children: [
        _buildSearchSection(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_searchQuery.isEmpty) ...[
                  _buildHeroBanner(),
                  const SizedBox(height: 32),
                ],
                Text(
                  _searchQuery.isEmpty ? 'Découvrir nos produits' : 'Résultats pour "$_searchQuery"',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (filteredProducts.isEmpty)
                  _buildNoResults()
                else
                  ...filteredProducts.map((p) => _buildProductCard(p)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      color: const Color(0xFF4CAF50),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Rechercher un engrais, compost...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF4CAF50)),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              })
            : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Aucun produit trouvé', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1599023414167-a2999e80fcd4?auto=format&fit=crop&q=80&w=1000'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Le meilleur pour vos plantes', style: TextStyle(color: Colors.white70, fontSize: 14)),
          SizedBox(height: 8),
          Text(
            'Compost de Qualité\nProfessionnelle',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(CartItem item) {
    final qty = _localQuantities[item.id] ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(item.image, height: 160, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${item.price} F', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50), fontSize: 18)),
                  ],
                ),
                Text(item.weight, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          _qtyBtn(Icons.remove, () => _updateLocalQuantity(item.id, -1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          _qtyBtn(Icons.add, () => _updateLocalQuantity(item.id, 1)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _addToCart(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Ajouter au panier'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
