import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/support_ticket_model.dart';
import '../../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

class SupportScreen extends StatefulWidget {
  final AppUser user;

  const SupportScreen({super.key, required this.user});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  bool _isSubmitting = false;
  String? _selectedSubject;
  final List<XFile> _selectedPhotos = [];
  final ImagePicker _picker = ImagePicker();

  // Liste des sujets prédéfinis
  final List<String> _predefinedSubjects = [
    'Signaler un incident lors d\'une collecte',
    'Problème d\'enregistrement Mobile Money',
    'Bugs, lenteurs ou autres problèmes',
  ];

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un sujet'), backgroundColor: Colors.orange));
      return;
    }
    
    setState(() => _isSubmitting = true);
    try {
      final List<String> photoUrls = [];
      for (var photo in _selectedPhotos) {
        final bytes = await photo.readAsBytes();
        photoUrls.add('data:image/jpeg;base64,${base64Encode(bytes)}');
      }

      final docRef = FirebaseFirestore.instance.collection('support_tickets').doc();
      TicketStatus activeStatus = TicketStatus.open;
      String userMessage = _messageController.text.trim();

      // ── LOGIQUE D'AUTOMATISATION ──
      

      // Enregistrement du ticket pour historique / suivi admin
      final ticket = SupportTicket(
        id: docRef.id,
        userId: widget.user.id,
        subject: _selectedSubject!,
        message: userMessage,
        photoUrls: photoUrls,
        status: activeStatus,
        createdAt: DateTime.now(),
      );

      await docRef.set(ticket.toMap());
      
      if (mounted) {
        _messageController.clear();
        _newPasswordController.clear();
        _selectedPhotos.clear();
        setState(() => _selectedSubject = null);
        
        if (activeStatus == TicketStatus.closed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Votre mot de passe a été modifié avec succès !'), backgroundColor: Color(0xFF4CAF50), duration: Duration(seconds: 4)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Votre préoccupation a bien été envoyée. L\'équipe vous répondra sous peu.'), backgroundColor: Color(0xFF4CAF50)),
          );
        }
      }
    } on FirebaseAuthException catch (authEx) {
      if (mounted) {
        String msg = 'Erreur lors du changement de mot de passe.';
        if (authEx.code == 'requires-recent-login') {
          msg = 'Veuillez vous déconnecter et vous reconnecter avant de changer votre mot de passe (sécurité).';
        } else if (authEx.code == 'weak-password') {
          msg = 'Le mot de passe doit faire au moins 6 caractères.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showNewTicketModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // StatefulBuilder permet de rafraîchir uniquement la modale quand on change le dropdown
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Nouvelle requête', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Dropdown des sujets prédéfinis
                      DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Catégorie du problème',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _predefinedSubjects.map((String subject) {
                          return DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setModalState(() {
                            _selectedSubject = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Veuillez sélectionner une catégorie' : null,
                      ),
                      const SizedBox(height: 16),


                      TextFormField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          labelText: _selectedSubject == 'Changement de mot de passe' ? 'Note / Justificatif (Optionnel)' : 'Détails du problème',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        validator: (v) {
                          if (_selectedSubject != 'Changement de mot de passe' && (v == null || v.isEmpty)) {
                            return 'Veuillez décrire le problème';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Sélecteur de photos
                      const Text('Photos / Captures d\'écran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedPhotos.length + (_selectedPhotos.length < 3 ? 1 : 0),
                          itemBuilder: (ctx, idx) {
                            if (idx == _selectedPhotos.length) {
                              return GestureDetector(
                                onTap: () async {
                                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 20);
                                  if (image != null) {
                                    setModalState(() => _selectedPhotos.add(image));
                                  }
                                },
                                child: Container(
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: const Icon(Icons.add_a_photo, color: Colors.grey),
                                ),
                              );
                            }
                            final photo = _selectedPhotos[idx];
                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: kIsWeb ? NetworkImage(photo.path) : FileImage(io.File(photo.path)) as ImageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => setModalState(() => _selectedPhotos.removeAt(idx)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          _submitTicket().then((_) {
                            if (_selectedSubject == null && !_isSubmitting) Navigator.pop(context); // close only if success
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Soumettre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Client'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_tickets')
            .where('userId', isEqualTo: widget.user.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          // Triage local par date décroissante pour éviter l'erreur d'index composite Firestore
          final ticketsData = docs.map((doc) => SupportTicket.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
          ticketsData.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (ticketsData.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.support_agent_rounded, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune requête de support',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Si vous rencontrez un problème technique ou avez besoin d\'aide, contactez notre équipe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ticketsData.length,
            itemBuilder: (context, index) {
              final ticket = ticketsData[index];
              
              Color statusColor;
              String statusLabel;
              switch (ticket.status) {
                case TicketStatus.open:
                  statusColor = Colors.orange;
                  statusLabel = 'Ouvert';
                  break;
                case TicketStatus.inProgress:
                  statusColor = Colors.blue;
                  statusLabel = 'En cours';
                  break;
                case TicketStatus.closed:
                  statusColor = Colors.green;
                  statusLabel = 'Résolu / Fermé';
                  break;
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ticket.subject, 
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket.message, maxLines: 5, overflow: TextOverflow.ellipsis),
                        if (ticket.photoUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: ticket.photoUrls.length,
                              itemBuilder: (ctx, idx) => Container(
                                width: 60,
                                margin: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ticket.photoUrls[idx].startsWith('data:image')
                                    ? Image.memory(base64Decode(ticket.photoUrls[idx].split(',').last), fit: BoxFit.cover)
                                    : Image.network(ticket.photoUrls[idx], fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Soumis le ${ticket.createdAt.day.toString().padLeft(2,'0')}/${ticket.createdAt.month.toString().padLeft(2,'0')}/${ticket.createdAt.year}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewTicketModal,
        icon: const Icon(Icons.edit),
        label: const Text('Nouveau ticket', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
    );
  }
}
