import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/user_model.dart';

class CollecteurHomeScreen extends StatefulWidget {
  final AppUser user;
  const CollecteurHomeScreen({super.key, required this.user});

  @override
  State<CollecteurHomeScreen> createState() => _CollecteurHomeScreenState();
}

class _CollecteurHomeScreenState extends State<CollecteurHomeScreen> {
  // Coordonnées D'Abidjan par défaut
  final LatLng _abidjanCenter = const LatLng(5.30966, -4.01266);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missions de Collecte'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _abidjanCenter,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ivoirebioaxe.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _abidjanCenter,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Panel inférieur montrant les requêtes en attente
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 250,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, -4), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Alertes dans un rayon de 10km',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 2, // Mock 
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: index == 0 ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                index == 0 ? Icons.pets : Icons.compost,
                                color: index == 0 ? Colors.orange : Colors.green,
                              ),
                            ),
                            title: const Text('Restaurant La Ruche', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(index == 0 ? 'Bac Frais • à 2.4 km' : 'Bac Vert • à 4.1 km'),
                            trailing: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Accepter'),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
