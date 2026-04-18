import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../models/activity_model.dart';
import '../../services/firestore_service.dart';

class PremiumHistoryScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const PremiumHistoryScreen({super.key, required this.user});

  @override
  ConsumerState<PremiumHistoryScreen> createState() => _PremiumHistoryScreenState();
}

class _PremiumHistoryScreenState extends ConsumerState<PremiumHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Stream<List<Activity>> _activitiesStream;
  String _timeFilter = 'Tous';
  final List<String> _timeOptions = ['Tous', '24h', '7j', '30j'];

  @override
  void initState() {
    super.initState();
    // Nombre d'onglets dépend du rôle
    int tabCount = 1;
    if (widget.user.role == UserRole.collecteur) tabCount = 2;
    if (widget.user.role == UserRole.restaurateur) tabCount = 2;
    
    _tabController = TabController(length: tabCount, vsync: this);
    _activitiesStream = ref.read(firestoreServiceProvider).getUserActivities(widget.user.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Activity> _applyTimeFilter(List<Activity> acts) {
    if (_timeFilter == 'Tous') return acts;
    final now = DateTime.now();
    final cutoff = _timeFilter == '24h' 
        ? now.subtract(const Duration(hours: 24)) 
        : _timeFilter == '7j' 
            ? now.subtract(const Duration(days: 7)) 
            : now.subtract(const Duration(days: 30));
    
    return acts.where((a) => a.timestamp.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Thème sombre "Enterprise"
    const bgColor = Color(0xFF1A1B2E);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(

        title: const Text('MON HISTORIQUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16)),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(() {}))
        ],
        bottom: widget.user.role != UserRole.acheteur ? TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CAF50),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _getTabsByRole(),
        ) : null,
      ),
      body: StreamBuilder<List<Activity>>(
        stream: _activitiesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildError(snapshot.error.toString());
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
          }

          final allActivities = snapshot.data ?? [];
          final filtered = _applyTimeFilter(allActivities);

          return Column(
            children: [
              // ── Filtres Temporels ────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: _timeOptions.map((t) {
                    final sel = _timeFilter == t;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _timeFilter = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? const Color(0xFF4CAF50) : Colors.white12),
                          ),
                          child: Text(t, style: TextStyle(color: sel ? const Color(0xFF4CAF50) : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── En-tête Stats ─────────────────────────────────────────
              _buildStatsHeaderByRole(allActivities),

              // ── Liste d'Activités ─────────────────────────────────────
              Expanded(
                child: widget.user.role == UserRole.acheteur 
                  ? _buildActivityList(filtered)
                  : TabBarView(
                      controller: _tabController,
                      children: _getTabViewsByRole(filtered),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _getTabsByRole() {
    if (widget.user.role == UserRole.collecteur) {
      return const [Tab(text: 'Collectes'), Tab(text: 'Retraits')];
    }
    if (widget.user.role == UserRole.restaurateur) {
      return const [Tab(text: 'Demandes'), Tab(text: 'Terminées')];
    }
    return [];
  }

  List<Widget> _getTabViewsByRole(List<Activity> activities) {
    if (widget.user.role == UserRole.collecteur) {
      return [
        _buildActivityList(activities.where((a) => a.type == ActivityType.collection).toList()),
        _buildActivityList(activities.where((a) => a.type == ActivityType.payout).toList()),
      ];
    }
    if (widget.user.role == UserRole.restaurateur) {
      return [
        _buildActivityList(activities.where((a) => a.type == ActivityType.collection && a.status == ActivityStatus.pending).toList()),
        _buildActivityList(activities.where((a) => a.type == ActivityType.collection && a.status == ActivityStatus.success).toList()),
      ];
    }
    return [ _buildActivityList(activities) ];
  }

  Widget _buildStatsHeaderByRole(List<Activity> all) {
    final role = widget.user.role;
    
    // Calculs communs
    final successCollections = all.where((a) => a.type == ActivityType.collection && a.status == ActivityStatus.success).toList();
    final payouts = all.where((a) => a.type == ActivityType.payout).toList();
    final purchases = all.where((a) => a.type == ActivityType.purchase).toList();

    List<StatModel> stats = [];

    if (role == UserRole.collecteur) {
      final totalGains = successCollections.fold<double>(0, (s, a) => s + a.amount);
      final totalPayoutsValue = payouts.fold<double>(0, (s, a) => s + (a.status == ActivityStatus.success ? a.amount : 0));
      stats = [
        StatModel(label: 'Total Gains', value: '${totalGains.toInt()} F', icon: Icons.savings_rounded, color: Colors.greenAccent),
        StatModel(label: 'Collectes', value: '${successCollections.length}', icon: Icons.local_shipping_rounded, color: Colors.blueAccent),
        StatModel(label: 'Déjà Retiré', value: '${totalPayoutsValue.toInt()} F', icon: Icons.account_balance_wallet_rounded, color: Colors.orangeAccent),
      ];
    } else if (role == UserRole.restaurateur) {
      final totalRequested = all.where((a) => a.type == ActivityType.collection).length;
      stats = [
        StatModel(label: 'Demandes', value: '$totalRequested', icon: Icons.notifications_active_rounded, color: Colors.orangeAccent),
        StatModel(label: 'Terminées', value: '${successCollections.length}', icon: Icons.check_circle_rounded, color: Colors.greenAccent),
        StatModel(label: 'Bacs Traités', value: '${(successCollections.length * 1.5).toStringAsFixed(1)} m³', icon: Icons.delete_sweep_rounded, color: Colors.blueAccent),
      ];
    } else {
      final totalSpent = purchases.fold<double>(0, (s, a) => s + a.amount);
      stats = [
        StatModel(label: 'Dépensé', value: '${totalSpent.toInt()} F', icon: Icons.payments_rounded, color: Colors.lightBlueAccent),
        StatModel(label: 'Commandes', value: '${purchases.length}', icon: Icons.shopping_bag_rounded, color: Colors.greenAccent),
        StatModel(label: 'Articles', value: '${purchases.length * 2}', icon: Icons.inventory_2_rounded, color: Colors.orangeAccent),
      ];
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252642),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: stats.map((s) => _statItem(s)).toList(),
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _statItem(StatModel stat) {
    return Column(
      children: [
        Icon(stat.icon, color: stat.color.withValues(alpha: 0.7), size: 20),
        const SizedBox(height: 8),
        Text(stat.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        Text(stat.label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildActivityList(List<Activity> activities) {
    if (activities.isEmpty) {
      return const Center(child: Text('Aucune activité sur cette période', style: TextStyle(color: Colors.white24)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: activities.length,
      itemBuilder: (ctx, i) {
        final activity = activities[i];
        return _buildActivityRow(activity, i);
      },
    );
  }

  Widget _buildActivityRow(Activity activity, int index) {
    Color statusColor;
    String statusLabel;
    switch (activity.status) {
      case ActivityStatus.success: statusColor = Colors.greenAccent; statusLabel = 'Réussi'; break;
      case ActivityStatus.pending: statusColor = Colors.orangeAccent; statusLabel = 'En cours'; break;
      case ActivityStatus.failed: statusColor = Colors.redAccent; statusLabel = 'Échoué'; break;
      case ActivityStatus.cancelled: statusColor = Colors.grey; statusLabel = 'Annulé'; break;
    }

    return InkWell(
      onTap: () => _showReceipt(activity, statusColor),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.03))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(_getIconByType(activity.type), color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(DateFormat('dd MMM à HH:mm').format(activity.timestamp), style: const TextStyle(color: Colors.white30, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  activity.amount > 0 ? '${activity.amount.toInt()} F' : '-',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(statusLabel, style: TextStyle(color: statusColor.withValues(alpha: 0.5), fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 40).ms).fade(duration: 300.ms).slideX(begin: 0.05);
  }

  IconData _getIconByType(ActivityType type) {
    switch (type) {
      case ActivityType.collection: return Icons.local_shipping_rounded;
      case ActivityType.purchase: return Icons.shopping_bag_rounded;
      case ActivityType.payout: return Icons.account_balance_wallet_rounded;
    }
  }

  void _showReceipt(Activity activity, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF252642),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('REÇU DÉTAILLÉ', style: TextStyle(color: Colors.white38, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Icon(_getIconByType(activity.type), size: 48, color: color),
            const SizedBox(height: 16),
            Text('${activity.amount.toInt()} FCFA', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(activity.title, style: TextStyle(color: color.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            _receiptRow('ID Transaction', activity.id.toUpperCase().substring(0, 12), Colors.white70),
            _receiptRow('Date', DateFormat('dd/MM/yyyy HH:mm').format(activity.timestamp), Colors.white70),
            _receiptRow('Statut', activity.status.name.toUpperCase(), color),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            ...activity.metadata.entries.map((e) => _receiptRow(e.key, e.value.toString(), Colors.white54)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.2),
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withValues(alpha: 0.3))),
                ),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 12)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class StatModel {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  StatModel({required this.label, required this.value, required this.icon, required this.color});
}
