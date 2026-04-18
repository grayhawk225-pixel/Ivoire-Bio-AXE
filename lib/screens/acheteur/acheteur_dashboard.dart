import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../shared/profile_drawer.dart';
import '../../widgets/offline_banner.dart';
import 'tabs/acheteur_shop_tab.dart';
import 'tabs/acheteur_cart_tab.dart';
import '../../providers/cart_provider.dart';

class AcheteurDashboard extends ConsumerStatefulWidget {
  final AppUser user;
  const AcheteurDashboard({super.key, required this.user});

  @override
  ConsumerState<AcheteurDashboard> createState() => _AcheteurDashboardState();
}

class _AcheteurDashboardState extends ConsumerState<AcheteurDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      AcheteurShopTab(user: widget.user),
      AcheteurCartTab(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartProvider.notifier).totalCount;

    return Scaffold(
      drawer: ProfileDrawer(user: widget.user),
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'Boutique Bio-Axe' : 'Mon Panier',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF4CAF50),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.shopping_basket),
                  if (cartCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Panier',
            ),
          ],
        ),
      ),
    );
  }
}
