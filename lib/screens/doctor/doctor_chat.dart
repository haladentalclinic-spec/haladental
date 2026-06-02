import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';

// Inbox Screen (List of patients who have sent or received messages)
class DoctorChatInboxScreen extends StatefulWidget {
  const DoctorChatInboxScreen({super.key});

  @override
  State<DoctorChatInboxScreen> createState() => _DoctorChatInboxScreenState();
}

class _DoctorChatInboxScreenState extends State<DoctorChatInboxScreen> {
  final SupabaseService _db = SupabaseService();
  List<Map<String, dynamic>> _chatPartners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() => _isLoading = true);
    try {
      final partners = await _db.getChatPartners();
      setState(() {
        _chatPartners = partners;
      });
    } catch (e) {
      print('Error loading chat partners: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Messages Inbox'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInbox),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _chatPartners.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatPartners.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final partner = _chatPartners[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          child: Text(
                            partner['full_name']?.substring(0,1).toUpperCase() ?? 'P',
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          partner['full_name'] ?? 'Patient',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(partner['phone'] ?? 'No phone'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DoctorChatThreadScreen(patient: partner),
                            ),
                          ).then((_) => _loadInbox());
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_chat_read_outlined,
              size: 60,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Conversations Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Active chat threads with patients who message the clinic will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// Conversation Thread Screen
class DoctorChatThreadScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  const DoctorChatThreadScreen({super.key, required this.patient});

  @override
  State<DoctorChatThreadScreen> createState() => _DoctorChatThreadScreenState();
}

class _DoctorChatThreadScreenState extends State<DoctorChatThreadScreen> {
  final SupabaseService _db = SupabaseService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    
    // Poll for new messages every 3 seconds
    _poller = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final user = Provider.of<AuthProvider>(context, listen: false).authUser;
    if (user == null) return;

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final list = await _db.getMessages(user.id, widget.patient['id']);
      if (mounted) {
        setState(() {
          _messages = list;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error fetching message thread: $e');
    } finally {
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    
    try {
      await _db.sendMessage(
        receiverId: widget.patient['id'],
        messageText: text,
      );
      _scrollToBottom();
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).authUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.patient['full_name'] ?? 'Patient',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.patient['patient_code'] ?? 'Patient Account',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _messages.isEmpty
                    ? const Center(child: Text('No messages in this chat thread.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] == user?.id;
                          return _buildChatBubble(msg, isMe);
                        },
                      ),
          ),
          
          // composer bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type your reply...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? AppTheme.darkBg : Colors.grey.shade100,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe 
              ? AppTheme.primaryColor 
              : (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBorder : Colors.grey.shade200),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Text(
          msg['message'] ?? '',
          style: TextStyle(
            color: isMe 
                ? Colors.white 
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
