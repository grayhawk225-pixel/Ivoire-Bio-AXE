import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../models/chat_message_model.dart';
import '../../services/firestore_service.dart';
import '../../services/connectivity_service.dart';

import 'support_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {

  final String requestId;
  final String otherPartyName;
  final String? otherPartyPhone;
  final AppUser currentUser;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.otherPartyName,
    this.otherPartyPhone,
    required this.currentUser,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickReplies = [
    'Je suis arrivé !',
    'Où se trouve le bac ?',
    'J\'ai un petit retard.',
    'Ok, bien reçu.',
    'La collecte est terminée.',
  ];

  @override
  void initState() {
    super.initState();
    // Marquer les messages comme lus dès l'ouverture
    _markAsRead();
  }

  void _markAsRead() {
    ref.read(firestoreServiceProvider).markChatMessagesAsRead(widget.requestId, widget.currentUser.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _callOtherParty() async {
    if (widget.otherPartyPhone == null || widget.otherPartyPhone!.isEmpty) return;
    final Uri url = Uri.parse('tel:${widget.otherPartyPhone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _sendMessage([String? text]) async {
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty) return;

    if (text == null) _messageController.clear();

    final message = ChatMessage(
      id: '',
      requestId: widget.requestId,
      senderId: widget.currentUser.id,
      senderName: widget.currentUser.restaurantName ?? (widget.currentUser.role == UserRole.collecteur ? 'Collecteur' : widget.currentUser.email.split('@')[0]),
      text: messageText,
      timestamp: DateTime.now(),
    );

    await ref.read(firestoreServiceProvider).sendChatMessage(message);
    
    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherPartyName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (widget.otherPartyPhone != null && widget.otherPartyPhone!.isNotEmpty)
              Text(widget.otherPartyPhone!, style: const TextStyle(fontSize: 11, color: Colors.white70))
            else
              const Text('Discussion en temps réel', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          if (widget.otherPartyPhone != null && widget.otherPartyPhone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_in_talk_rounded),
              onPressed: _callOtherParty,
              tooltip: 'Appeler',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'support') {
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => SupportScreen(user: widget.currentUser)));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'support',
                child: Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Besoin d\'aide ?'),
                  ],
                ),
              ),
            ],
          ),
          if (connectivity == ConnectivityStatus.isDisconnected)

            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.wifi_off, color: Colors.orangeAccent),
            ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ref.read(firestoreServiceProvider).getChatMessages(widget.requestId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Aucun message. Commencez la discussion !', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == widget.currentUser.id;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildQuickReplies(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickReplies.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(_quickReplies[index], style: const TextStyle(fontSize: 12)),
              onPressed: () => _sendMessage(_quickReplies[index]),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF4CAF50), width: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4CAF50) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(msg.senderName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(
              msg.text,
              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.timestamp),
              style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Écrivez un message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF4CAF50),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}
