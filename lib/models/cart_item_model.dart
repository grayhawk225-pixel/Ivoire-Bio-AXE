class CartItem {
  final String id;
  final String name;
  final int price;
  final String weight;
  final String image;
  final int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.weight,
    required this.image,
    this.quantity = 1,
  });

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      name: name,
      price: price,
      weight: weight,
      image: image,
      quantity: quantity ?? this.quantity,
    );
  }

  double get totalPrice => (price * quantity).toDouble();
}
