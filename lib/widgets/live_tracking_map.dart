import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class LiveTrackingMap extends ConsumerWidget {
  final String collectorId;
  final GeoPoint restaurantLocation;
  final double height;

  const LiveTrackingMap({
    super.key,
    required this.collectorId,
    required this.restaurantLocation,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return StreamBuilder<AppUser?>(
      stream: firestoreService.getUserStream(collectorId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement du suivi'));
        }

        final collector = snapshot.data;
        final collectorLocation = collector?.currentLocation;

        // Calcul de la distance si les deux positions sont disponibles
        String distanceText = 'Localisation en cours...';
        LatLng? collectorLatLng;
        if (collectorLocation != null) {
          collectorLatLng = LatLng(collectorLocation.latitude, collectorLocation.longitude);
          final distance = Geolocator.distanceBetween(
            restaurantLocation.latitude,
            restaurantLocation.longitude,
            collectorLocation.latitude,
            collectorLocation.longitude,
          );
          
          if (distance < 1000) {
            distanceText = 'Le collecteur est à ${distance.toStringAsFixed(0)} m';
          } else {
            distanceText = 'Le collecteur est à ${(distance / 1000).toStringAsFixed(1)} km';
          }
        }

        final restaurantLatLng = LatLng(restaurantLocation.latitude, restaurantLocation.longitude);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(distanceText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: collectorLatLng ?? restaurantLatLng,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      userAgentPackageName: 'com.ivoirebioaxe.app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Marqueur Restaurant
                        Marker(
                          point: restaurantLatLng,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.restaurant, color: Colors.blue, size: 30),
                        ),
                        // Marqueur Collecteur (si connu)
                        if (collectorLatLng != null)
                          Marker(
                            point: collectorLatLng,
                            width: 50,
                            height: 50,
                            child: const Column(
                              children: [
                                Icon(Icons.local_shipping, color: Colors.green, size: 30),
                                Icon(Icons.arrow_drop_down, color: Colors.green, size: 15),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
