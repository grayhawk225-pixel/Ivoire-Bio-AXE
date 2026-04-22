import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      builder: (ctx) => _WastePhotoSheet(type: type, userId: widget.user.id),
    );

  if (result == null) return; 
  await _sendAlert(type: result.type, photoUrls: result.photoUrls, description: result.description);
}

Future<void> _sendAlert({required WasteType type, required List<String> photoUrls, String? description}) async {
  if (photoUrls.isEmpty) return; 

  setState(() => _isLoading = true);
  final firestoreService = ref.read(firestoreServiceProvider);
  
  try {
    // Les photos sont déjà uploadées !
    debugPrint('✅ [Alert] Photos déjà uploadées: ${photoUrls.length}');
    
    // 2. Création de la requête de collecte
    debugPrint('⏳ [Alert] Création de la requête dans Firestore...');
    final request = WasteRequest(
      id: '',
      restaurateurId: widget.user.id,
      type: type,
      status: WasteStatus.pending,
      createdAt: DateTime.now(),
      location: widget.user.location ?? const GeoPoint(5.30966, -4.01266),
      preuvePhotosUrls: photoUrls,
      description: description,
    );
    await firestoreService.createWasteRequest(request);
    debugPrint('✅ [Alert] Requête créée.');

    // 3. Journalisation de l'activité
    debugPrint('⏳ [Alert] Journalisation de l\'activité...');
    await firestoreService.logActivity(Activity(
      id: '', 
      userId: widget.user.id, 
      type: ActivityType.collection, 
      status: ActivityStatus.pending, 
      title: 'Alerte Envoyée', 
      description: 'Demande de collecte (${type == WasteType.frais ? "Bac Frais" : "Bac Vert"})', 
      amount: 0, 
      timestamp: DateTime.now(),
      metadata: {
        'type': type.toString(),
        'photos_count': photoUrls.length.toString(),
        'description': description ?? '',
        'lat': (widget.user.location?.latitude ?? 5.30966).toString(),
        'lng': (widget.user.location?.longitude ?? -4.01266).toString(),
      }
    ));

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Votre alerte a été envoyée avec succès !'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      debugPrint('❌ [Alert] Échec de l\'envoi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        String errorMsg = e.toString();
        if (errorMsg.contains('timeout')) {
          errorMsg = "Le délai d'envoi a expiré. Votre connexion est peut-être trop faible.";
        } else if (errorMsg.contains('not-found')) {
          errorMsg = "Erreur de synchronisation serveur (Fichier non trouvé après upload).";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $errorMsg'), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
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
  final List<String> photoUrls;
  final String? description;

  _WasteActionResult({required this.type, required this.photoUrls, this.description});
}

class _WastePhotoSheet extends StatefulWidget {
  final WasteType type;
  final String userId;
  const _WastePhotoSheet({required this.type, required this.userId});

  @override
  State<_WastePhotoSheet> createState() => _WastePhotoSheetState();
}

class _WastePhotoSheetState extends State<_WastePhotoSheet> {
  final List<XFile> _selectedPhotos = [];
  final Map<String, Uint8List> _webPreviewBytes = {};
  final Map<String, String?> _uploadedUrls = {}; // Cache pour les URLs déjà uploadées
  final Map<String, bool> _uploadingStatus = {}; // État d'upload par fichier
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (_selectedPhotos.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 photos autorisées.')),
        );
        return;
      }
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 20);
      if (image != null) {
        setState(() {
          _selectedPhotos.add(image);
          _uploadingStatus[image.path] = true;
          if (kIsWeb) {
            image.readAsBytes().then((bytes) {
              setState(() => _webPreviewBytes[image.path] = bytes);
            });
          }
        });

        // Upload proactif en arrière-plan
        _startProactiveUpload(image);
      }
    } catch (e) {
      debugPrint('❌ [Picker] Erreur: $e');
    }
  }

  Future<void> _startProactiveUpload(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final String base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      if (mounted) {
        setState(() {
          _uploadedUrls[image.path] = base64Image;
          _uploadingStatus[image.path] = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [Base64Conversion] Erreur: $e');
      if (mounted) {
        setState(() => _uploadingStatus[image.path] = false);
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      final photo = _selectedPhotos.removeAt(index);
      _webPreviewBytes.remove(photo.path);
      _uploadedUrls.remove(photo.path);
      _uploadingStatus.remove(photo.path);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Envoyer une alerte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez jusqu\'à 3 photos et une description pour faciliter la collecte.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            
            // Grille de photos
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPhotos.length + (_selectedPhotos.length < 3 ? 1 : 0),
                itemBuilder: (ctx, index) {
                  if (index == _selectedPhotos.length) {
                    return GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: Colors.orange[400]),
                            const Text('Ajouter', style: TextStyle(fontSize: 12, color: Colors.orange)),
                          ],
                        ),
                      ),
                    );
                  }

                  final photo = _selectedPhotos[index];
                  return Stack(
                    children: [
                      Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey[200],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            kIsWeb 
                              ? (_webPreviewBytes[photo.path] != null 
                                  ? Image.memory(_webPreviewBytes[photo.path]!, fit: BoxFit.cover)
                                  : const Center(child: CircularProgressIndicator(strokeWidth: 2)))
                              : Image.file(io.File(photo.path), fit: BoxFit.cover),
                            if (_uploadingStatus[photo.path] == true)
                              Container(
                                color: Colors.black38,
                                child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              ),
                            if (_uploadedUrls[photo.path] != null)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 16,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            if (_selectedPhotos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Au moins une photo est obligatoire', style: TextStyle(color: Colors.red, fontSize: 11)),
              ),

            const SizedBox(height: 20),
            
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Description (ex: Bac plein, accessible par la rue...)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceButton(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 16),
                _buildSourceButton(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                onPressed: (_selectedPhotos.isEmpty || _uploadingStatus.values.any((v) => v)) 
                  ? null 
                  : () {
                      final urls = _selectedPhotos.map((p) => _uploadedUrls[p.path]).whereType<String>().toList();
                      Navigator.pop(context, _WasteActionResult(
                        type: widget.type, 
                        photoUrls: urls,
                        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50), 
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text('Confirmer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
