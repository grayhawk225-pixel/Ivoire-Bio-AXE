import '../models/cart_item_model.dart';

class ProductService {
  static final List<CartItem> products = [
    CartItem(
      id: 'p1',
      name: 'Bio-Compost Premium',
      price: 2500,
      weight: 'Sac de 25kg',
      image: 'https://images.unsplash.com/photo-1599023414167-a2999e80fcd4?auto=format&fit=crop&q=80&w=500',
    ),
    CartItem(
      id: 'p2',
      name: 'Fertilisant Liquide',
      price: 4500,
      weight: 'Bidon de 5L',
      image: 'https://images.unsplash.com/photo-1585314062340-f1a5a7c9328d?auto=format&fit=crop&q=80&w=500',
    ),
    CartItem(
      id: 'p3',
      name: 'Terreau Fertile',
      price: 3500,
      weight: 'Sac de 15kg',
      image: 'https://images.unsplash.com/photo-1523301343968-3a1ec458c532?auto=format&fit=crop&q=80&w=500',
    ),
    CartItem(
      id: 'p4',
      name: 'Activateur de Compost',
      price: 5000,
      weight: 'Boîte de 1kg',
      image: 'https://images.unsplash.com/photo-1592610192415-849547d21d6e?auto=format&fit=crop&q=80&w=500',
    ),
    CartItem(
      id: 'p5',
      name: 'Bio-Char Pur',
      price: 6000,
      weight: 'Sac de 10kg',
      image: 'https://images.unsplash.com/photo-1549416878-b9ca35c2d47b?auto=format&fit=crop&q=80&w=500',
    ),
    CartItem(
      id: 'p6',
      name: 'Kit Potager Bio',
      price: 15000,
      weight: 'Kit Complet',
      image: 'https://images.unsplash.com/photo-1416870262648-fb63f25b682b?auto=format&fit=crop&q=80&w=500',
    ),
  ];

  static List<CartItem> searchProducts(String query) {
    if (query.isEmpty) return products;
    return products.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
  }
}
