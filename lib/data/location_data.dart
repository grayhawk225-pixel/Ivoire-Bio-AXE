class City {
  final String name;
  final List<String> communes;

  const City({required this.name, required this.communes});
}

const List<City> ivoryCoastCities = [
  City(
    name: 'Abidjan',
    communes: [
      'Cocody',
      'Plateau',
      'Marcory',
      'Yopougon',
      'Abobo',
      'Koumassi',
      'Treichville',
      'Adjamé',
      'Port-Bouët',
      'Riviera',
      'Bingerville',
      'Anyama',
    ],
  ),
  City(
    name: 'Yamoussoukro',
    communes: ['Centre-Ville', 'Dioulabougou', 'Morofé', 'Assabou'],
  ),
  City(
    name: 'Bouaké',
    communes: ['Centre', 'Koko', 'Nimbo', 'Air France', 'Broukro'],
  ),
  City(
    name: 'San-Pedro',
    communes: ['Centre', 'Bardot', 'Cité', 'Balmer'],
  ),
  City(
    name: 'Daloa',
    communes: ['Centre-Ville', 'Lobou', 'Abattoir'],
  ),
];
