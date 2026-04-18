import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../models/waste_request_model.dart';
import '../../models/activity_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../shared/profile_drawer.dart';
import '../shared/chat_screen.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/live_tracking_map.dart';

class RestaurateurHomeScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const RestaurateurHomeScreen({super.key, required this.user});

  @override
  ConsumerState<RestaurateurHomeScreen> createState() => _RestaurateurHomeScreenState();
}

class _RestaurateurHomeScreenState extends ConsumerState<RestaurateurHomeScreen> {
  bool _isLoading = false;
  final Map<String, bool> _showMap = {}; // Tracker pour afficher/masquer la carte par mission

  void _onBacTap(WasteType type) async {
    final result = await showModalBottomSheet<_WasteActionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WastePhotoSheet(type: type),
    );

    if (result == null) return; 
    await _sendAlert(type: result.type, photoFile: result.photoFile);
  }

  Future<void> _sendAlert({
    required WasteType type,
    File? photoFile,
  }) async {
    setState(() => _isLoading = true);
    final firestoreService = ref.read(firestoreServiceProvider);
    try {
      String? photoUrl;

      if (photoFile != null) {
        final storageService = StorageService();
        photoUrl = await storageService.uploadWastePhoto(
          file: photoFile,
          restaurateurId: widget.user.id,
        );
      }

      final request = WasteRequest(
        id: '',
        restaurateurId: widget.user.id,
        type: type,
        status: WasteStatus.pending,
        createdAt: DateTime.now(),
        location: widget.user.location ?? const GeoPoint(5.30966, -4.01266),
        preuvePhotoUrl: photoUrl,
      );

      await firestoreService.createWasteRequest(request);

      await firestoreService.logActivity(Activity(
        id: '', 
        userId: widget.user.id, 
        type: ActivityType.collection, 
        status: ActivityStatus.pending, 
        title: 'Alerte Envoyée', 
        description: 'Demande de collecte pour ${type == WasteType.frais ? "Bac Frais" : "Bac Vert"}', 
        amount: 0, 
        timestamp: DateTime.now(),
        metadata: {
          'Type': type == WasteType.frais ? 'Bac Frais' : 'Bac Vert',
          'Photo': photoUrl ?? 'Sans photo',
          'CreatedAt': DateTime.now().toIso8601String(),
          'LieuLat': (widget.user.location?.latitude ?? 5.30966).toString(),
          'LieuLng': (widget.user.location?.longitude ?? -4.01266).toString(),
        }
      ));


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Alerte envoyée !'), backgroundColor: const Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return Scaffold(
      drawer: ProfileDrawer(user: widget.user),
      appBar: AppBar(
        title: const Text('Ma Poubelle Bio'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Status des demandes en cours ---
                  StreamBuilder<List<WasteRequest>>(
                    stream: firestoreService.getRestaurateurRequests(widget.user.id),
                    builder: (context, snapshot) {
                      final requests = (snapshot.data ?? []).where((r) => r.status != WasteStatus.completed).toList();
                      if (requests.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vos collectes actives', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ...requests.map((req) {
                            final bool isAccepted = req.status == WasteStatus.accepted;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isAccepted ? const BorderSide(color: Color(0xFF4CAF50), width: 1.5) : BorderSide.none
                              ),
                              child: FutureBuilder<AppUser?>(
                                future: isAccepted && req.collecteurId != null 
                                  ? firestoreService.getUser(req.collecteurId!) 
                                  : Future.value(null),
                                builder: (context, userSnap) {
                                  final collector = userSnap.data;
                                  final String collectorName = collector?.email.split('@')[0] ?? 'Collecteur Bio-Axe';

                                  return Column(
                                    children: [
                                      ListTile(
                                        leading: Icon(
                                          req.status == WasteStatus.pending ? Icons.access_time_filled : Icons.local_shipping,
                                          color: req.status == WasteStatus.pending ? Colors.orange : Colors.green,
                                        ),
                                        title: Text(req.type == WasteType.frais ? 'Bac Frais (Élevage)' : 'Bac Vert (Compost)'),
                                        subtitle: Text(
                                          req.status == WasteStatus.pending 
                                            ? 'En attente...' 
                                            : 'En route : $collectorName'
                                        ),
                                        trailing: isAccepted 
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    _showMap[req.id] == true ? Icons.map : Icons.map_outlined,
                                                    color: _showMap[req.id] == true ? Colors.blue : Colors.grey,
                                                  ),
                                                  onPressed: () => setState(() => _showMap[req.id] = !(_showMap[req.id] ?? false)),
                                                  tooltip: 'Suivre le collecteur',
                                                ),
                                                StreamBuilder<int>(
                                                  stream: firestoreService.getUnreadChatCountStream(req.id, widget.user.id),
                                                  builder: (context, countSnap) {
                                                    final unreadCount = countSnap.data ?? 0;
                                                    return Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.chat_bubble, color: Color(0xFF4CAF50)),
                                                          onPressed: () {
                                                            Navigator.push(context, MaterialPageRoute(builder: (ctx) => ChatScreen(
                                                              requestId: req.id, 
                                                              otherPartyName: collectorName, 
                                                              otherPartyPhone: collector?.phoneNumber,
                                                              currentUser: widget.user
                                                            )));
                                                          },
                                                        ),
                                                        if (unreadCount > 0)
                                                          Positioned(
                                                            right: 8,
                                                            top: 8,
                                                            child: Container(
                                                              padding: const EdgeInsets.all(4),
                                                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                                              child: Text(
                                                                '$unreadCount',
                                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                                textAlign: TextAlign.center,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  }
                                                ),
                                              ],
                                            )
                                          : null,
                                      ),
                                      if (isAccepted && _showMap[req.id] == true && req.collecteurId != null && widget.user.location != null)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                          child: LiveTrackingMap(
                                            collectorId: req.collecteurId!,
                                            restaurantLocation: widget.user.location!,
                                          ),
                                        ),
                                    ],
                                  );
                                }
                              ),
                            );
                          }),
                          const Divider(height: 32),
                        ],
                      );
                    }
                  ),

                  
                  // --- Header Caméra ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.camera_alt_rounded, size: 48, color: Colors.white70),
                        SizedBox(height: 12),
                        Text('Collecte Flash', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 8),
                        Text(
                          'Envoyez une alerte avec photo pour être collecté en moins de 3h.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Boutons Bac ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          title: 'Bac Frais',
                          subtitle: 'Élevage',
                          icon: Icons.pets,
                          color: Colors.orange,
                          onTap: () => _onBacTap(WasteType.frais),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          title: 'Bac Vert',
                          subtitle: 'Compost',
                          icon: Icons.compost,
                          color: const Color(0xFF4CAF50),
                          onTap: () => _onBacTap(WasteType.vert),
                        ),
                      ),
                    ],
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _WasteActionResult {
  final WasteType type;
  final File? photoFile;
  _WasteActionResult({required this.type, this.photoFile});
}

class _WastePhotoSheet extends StatefulWidget {
  final WasteType type;
  const _WastePhotoSheet({required this.type});

  @override
  State<_WastePhotoSheet> createState() => _WastePhotoSheetState();
}

class _WastePhotoSheetState extends State<_WastePhotoSheet> {
  File? _selectedPhoto;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) setState(() => _selectedPhoto = File(image.path));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Prendre une photo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedPhoto != null 
                ? Image.file(_selectedPhoto!, fit: BoxFit.cover)
                : const Icon(Icons.camera_alt, size: 48, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _WasteActionResult(type: widget.type, photoFile: _selectedPhoto)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
                  child: const Text('Confirmer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
