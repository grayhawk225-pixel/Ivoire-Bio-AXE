import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/waste_request_model.dart';
import '../../models/activity_model.dart';
import '../shared/profile_drawer.dart';
import '../shared/chat_screen.dart';
import '../../widgets/offline_banner.dart';
import 'collecteur_wallet_screen.dart';
import '../../services/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollecteurHomeScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const CollecteurHomeScreen({super.key, required this.user});

  @override
  ConsumerState<CollecteurHomeScreen> createState() => _CollecteurHomeScreenState();
}

class _CollecteurHomeScreenState extends ConsumerState<CollecteurHomeScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Position>? _positionSubscription;
  final LatLng _abidjanCenter = const LatLng(5.30966, -4.01266);
  late TabController _tabController;

  // Alertes "nouvelle mission" vues pour la première fois — pour l'animation pulse
  final Set<String> _seenRequests = {};

  // ── Streams stables ─────────────────────────────────────────────
  // Déclarés UNE SEULE FOIS dans initState pour éviter le bug
  // de flash/reset causé par la recréation de stream à chaque rebuild du parent.
  late final Stream<List<WasteRequest>> _pendingStream;
  late final Stream<List<WasteRequest>> _activeStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pendingCountStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _activeCountStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startTracking();

    final uid = widget.user.id;
    final db = FirebaseFirestore.instance;

    // Missions en attente : tri côté client pour éviter l'index composite Firestore
    _pendingStream = db.collection('waste_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
          final docs = s.docs.map((d) => WasteRequest.fromMap(d.data(), d.id)).toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });

    // Ma mission en cours
    _activeStream = db.collection('waste_requests')
        .where('status', isEqualTo: 'accepted')
        .where('collecteurId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => WasteRequest.fromMap(d.data(), d.id)).toList());

    // Compteurs pour les badges d'onglet
    _pendingCountStream = db.collection('waste_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    _activeCountStream = db.collection('waste_requests')
        .where('status', isEqualTo: 'accepted')
        .where('collecteurId', isEqualTo: uid)
        .snapshots();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50),
    ).listen((Position position) {
      ref.read(firestoreServiceProvider).updateCollectorLocation(
        widget.user.id, position.latitude, position.longitude);
    });
  }

  void _acceptMission(WasteRequest request) async {
    try {
      // 1. Vérifier si le collecteur a déjà une mission en cours
      final activeMissions = await FirebaseFirestore.instance
          .collection('waste_requests')
          .where('collecteurId', isEqualTo: widget.user.id)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (activeMissions.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Une seule mission ne peut être acceptée à la fois. Veuillez terminer votre mission en cours.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await ref.read(firestoreServiceProvider).updateWasteRequestStatus(
        request.id, WasteStatus.accepted, collecteurId: widget.user.id);

      await ref.read(firestoreServiceProvider).logActivity(Activity(
        id: '',
        userId: widget.user.id,
        type: ActivityType.collection,
        status: ActivityStatus.pending,
        title: 'Mission Acceptée',
        description: 'Collecte prévue pour ${request.type == WasteType.frais ? "Bac Frais" : "Bac Vert"}',
        amount: 0,
        timestamp: DateTime.now(),
        metadata: {
          'RequestID': request.id,
          'Type': request.type == WasteType.frais ? 'Bac Frais' : 'Bac Vert',
          'AcceptedAt': DateTime.now().toIso8601String(),
          'LieuLat': request.location.latitude.toString(),
          'LieuLng': request.location.longitude.toString(),
        },
      ));
      // Basculer vers l'onglet "En cours" automatiquement
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _completeMission(WasteRequest request) async {
    // Dialogue de confirmation avant de valider
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50)),
            SizedBox(width: 10),
            Text('Valider la collecte ?'),
          ],
        ),
        content: const Text('En validant, cette mission sera archivée dans votre historique et 500 F seront crédités à votre solde.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
            child: const Text('Confirmer & Valider'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(firestoreServiceProvider).updateWasteRequestStatus(request.id, WasteStatus.completed);

      final newBalance = widget.user.balance + 500;
      await FirebaseFirestore.instance.collection('users').doc(widget.user.id).update({'balance': newBalance});

      final completedAt = DateTime.now();
      // Calculer la durée depuis la création de la demande
      final duration = completedAt.difference(request.createdAt);
      final durationStr = duration.inMinutes < 60
          ? '${duration.inMinutes} min'
          : '${duration.inHours}h ${duration.inMinutes % 60}min';

      // 1. Log pour le Collecteur (Déjà présent)
      await ref.read(firestoreServiceProvider).logActivity(Activity(
        id: '',
        userId: widget.user.id,
        type: ActivityType.collection,
        status: ActivityStatus.success,
        title: 'Mission Terminée ✅',
        description: 'Collecte réalisée avec succès. Gain : +500 FCFA',
        amount: 500,
        timestamp: completedAt,
        metadata: {
          'RequestID': request.id,
          'Type': request.type == WasteType.frais ? 'Bac Frais' : 'Bac Vert',
          'Gain': '500 FCFA',
          'Durée': durationStr,
          'CompletedAt': completedAt.toIso8601String(),
          'CreatedAt': request.createdAt.toIso8601String(),
          'LieuLat': request.location.latitude.toString(),
          'LieuLng': request.location.longitude.toString(),
        },
      ));

      // 2. Log pour le Restaurateur (Nouveau)
      await ref.read(firestoreServiceProvider).logActivity(Activity(
        id: '',
        userId: request.restaurateurId, // On log pour le restaurateur
        type: ActivityType.collection,
        status: ActivityStatus.success,
        title: 'Collecte Terminée ✓',
        description: 'Votre dechet (${request.type == WasteType.frais ? "Bac Frais" : "Bac Vert"}) a été collecté.',
        amount: 0,
        timestamp: completedAt,
        metadata: {
          'RequestID': request.id,
          'Type': request.type == WasteType.frais ? 'Bac Frais' : 'Bac Vert',
          'CollecteurID': widget.user.id,
          'Durée': durationStr,
          'CompletedAt': completedAt.toIso8601String(),
        },
      ));


      if (mounted) {
        // Retour à l'onglet "Alertes" après validation
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFF1565C0),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mission archivée !', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('+500 F crédités sur votre solde.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ProfileDrawer(user: widget.user),
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Tableau de Bord Collecteur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => CollecteurWalletScreen(user: widget.user))),
            icon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
            label: Text('${widget.user.balance.toInt()} F', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            _buildTabWithBadge('🔔 Alertes', true),
            _buildTabWithBadge('🚛 En cours', false),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAlertsTab(),   // Onglet 1 : missions en attente
                _buildActiveTab(),   // Onglet 2 : mission acceptée par ce collecteur
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabWithBadge(String label, bool isPending) {
    final stream = isPending ? _pendingCountStream : _activeCountStream;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────
  // Onglet 1 : Toutes les alertes "pending"
  // ───────────────────────────────────────────────
  Widget _buildAlertsTab() {
    return StreamBuilder<List<WasteRequest>>(
      stream: _pendingStream, // ✅ Stream stable, créé une seule fois dans initState
      builder: (context, snapshot) {
        // État de connexion initiale
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
        }

        // Erreur Firestore (ex: index manquant)
        if (snapshot.hasError) {
          return Center(child: Text('Erreur de chargement: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Aucune alerte active', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Les nouvelles missions apparaîtront ici en temps réel.', style: TextStyle(color: Colors.grey[400], fontSize: 13), textAlign: TextAlign.center),
              ],
            ).animate().fade(duration: 500.ms),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final req = items[i];
            final isNew = !_seenRequests.contains(req.id);
            if (isNew) _seenRequests.add(req.id);
            return _buildAlertCard(req, isNew: isNew).animate(delay: (i * 80).ms).slideY(begin: 0.2).fade();
          },
        );
      },
    );
  }

  // ───────────────────────────────────────────────
  // Onglet 2 : Mission en cours (acceptée par MOI)
  // ───────────────────────────────────────────────
  Widget _buildActiveTab() {
    return StreamBuilder<List<WasteRequest>>(
      stream: _activeStream, // ✅ Stream stable, créé une seule fois dans initState
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
        }
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Aucune mission en cours', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Acceptez une alerte pour démarrer une collecte.', style: TextStyle(color: Colors.grey[400], fontSize: 13), textAlign: TextAlign.center),
              ],
            ).animate().fade(duration: 500.ms),
          );
        }

        // Une seule mission active à la fois
        final req = items.first;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildActiveMissionCard(req).animate().slideY(begin: -0.1).fade(),
        );
      },
    );
  }

  // ───────────────────────────────────────────────
  // Carte Alerte — Mission en attente
  // ───────────────────────────────────────────────
  Widget _buildAlertCard(WasteRequest req, {bool isNew = false}) {
    final isFrais = req.type == WasteType.frais;
    final color = isFrais ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    final bgColor = isFrais ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);
    final icon = isFrais ? Icons.water_drop_rounded : Icons.eco_rounded;
    final typeLabel = isFrais ? 'Bac Frais (Déchets humides)' : 'Bac Vert (Déchets secs/verts)';
    final timeAgo = _timeAgo(req.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          // En-tête de l'alerte
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('NOUVELLE ALERTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.8)),
                          if (isNew) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                              child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ).animate(onPlay: (ctrl) => ctrl.repeat(reverse: true)).fade(duration: 600.ms),
                          ],
                        ],
                      ),
                      Text(typeLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ),
                Text(timeAgo, style: TextStyle(fontSize: 12, color: color.withOpacity(0.7), fontStyle: FontStyle.italic)),
              ],
            ),
          ),

          // Corps de la carte
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text('Demande reçue à ${DateFormat('HH:mm').format(req.createdAt)}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      'Lat: ${req.location.latitude.toStringAsFixed(4)}, Lng: ${req.location.longitude.toStringAsFixed(4)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Bouton Itinéraire
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: const Text('Itinéraire'),
                        onPressed: () async {
                          final url = 'https://www.google.com/maps/dir/?api=1&destination=${req.location.latitude},${req.location.longitude}';
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bouton Accepter → Étape 1
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.local_shipping_rounded, size: 20),
                        label: const Text('Je pars collecter !', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _acceptMission(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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

  // ───────────────────────────────────────────────
  // Carte Mission Active — En cours
  // ───────────────────────────────────────────────
  Widget _buildActiveMissionCard(WasteRequest req) {
    final isFrais = req.type == WasteType.frais;
    final color = isFrais ? const Color(0xFFE65100) : const Color(0xFF1565C0);
    final icon = isFrais ? Icons.water_drop_rounded : Icons.eco_rounded;

    return Column(
      children: [
        // ── Indicateur d'étapes ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
          ),
          child: Row(
            children: [
              // Étape 1 - Complétée
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF2E7D32),
                      child: const Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                    const SizedBox(height: 4),
                    const Text('Étape 1', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    const Text('Acceptée', style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32))),
                  ],
                ),
              ),
              // Trait de progression
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(height: 3, color: Colors.grey.shade200),
                    Container(height: 3, color: const Color(0xFFFF8F00), width: 30),
                    const Positioned(
                      right: 0,
                      child: Icon(Icons.local_shipping_rounded, color: Color(0xFFFF8F00), size: 20),
                    ),
                  ],
                ),
              ),
              // Étape 2 - En attente
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFFF8F00),
                      child: const Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    const Text('Étape 2', style: TextStyle(fontSize: 10, color: Color(0xFFFF8F00), fontWeight: FontWeight.bold)),
                    const Text('Valider', style: TextStyle(fontSize: 11, color: Color(0xFFFF8F00))),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Carte statut mission
        // Carte statut mission + Carte + Actions (Tout ce qui dépend du Restaurateur)
        FutureBuilder<AppUser?>(
          future: ref.read(firestoreServiceProvider).getUser(req.restaurateurId),
          builder: (context, restauSnap) {
            final restaurateur = restauSnap.data;
            final String restauName = restaurateur?.restaurantName ?? (restaurateur?.email.split('@')[0] ?? 'Restaurateur');
            final String restauPhone = restaurateur?.phoneNumber ?? 'N/A';

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: Icon(icon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MISSION EN COURS', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              Text(restauName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                            child: const Row(
                              children: [
                                Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                                SizedBox(width: 4),
                                Text('En route', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            _infoRow(Icons.phone_iphone_rounded, 'Contact', restauPhone),
                            const Divider(color: Colors.white24, height: 16),
                            _infoRow(Icons.category_rounded, 'Bac', req.type == WasteType.frais ? 'Bac Frais' : 'Bac Vert'),
                            const Divider(color: Colors.white24, height: 16),
                            _infoRow(Icons.schedule_rounded, 'Début', DateFormat('HH:mm').format(req.createdAt)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Mini carte
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(req.location.latitude, req.location.longitude),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', userAgentPackageName: 'com.ivoirebioaxe.app'),
                        MarkerLayer(markers: [
                          Marker(
                            point: LatLng(req.location.latitude, req.location.longitude),
                            width: 50, height: 50,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: const Text('Itinéraire'),
                        onPressed: () async {
                          final url = 'https://www.google.com/maps/dir/?api=1&destination=${req.location.latitude},${req.location.longitude}';
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.task_alt_rounded, size: 22),
                        label: const Text("J'ai collecté ✓", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        onPressed: () => _completeMission(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
        ),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFFF8F00), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Allez collecter les déchets, puis revenez cliquer sur "J\'ai collecté" pour valider et recevoir vos 500 FCFA.',
                  style: TextStyle(color: Color(0xFF5D4037), fontSize: 12),
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text('$label : ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return DateFormat('dd/MM').format(dt);
  }
}
