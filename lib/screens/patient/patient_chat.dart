import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';

class PatientChat extends StatefulWidget {
  const PatientChat({super.key});

  @override
  State<PatientChat> createState() => _PatientChatState();
}

class _PatientChatState extends State<PatientChat> {
  final SupabaseService _db = SupabaseService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _selectedDoctor;
  
  bool _loadingDoctors = true;
  bool _loadingMessages = false;
  Timer? _messagePoller;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    
    // Poll for new messages every 3 seconds to keep UI up to date
    _messagePoller = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_selectedDoctor != null) {
        _loadMessages(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _messagePoller?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _loadingDoctors = true);
    try {
      final doctorsList = await _db.getDoctors();
      setState(() {
        _doctors = doctorsList;
        if (_doctors.isNotEmpty) {
          _selectedDoctor = _doctors.first;
        }
      });
      if (_selectedDoctor != null) {
        await _loadMessages();
      }
    } catch (e) {
      print('Error loading doctors: $e');
    } finally {
      setState(() => _loadingDoctors = false);
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_selectedDoctor == null) return;
    final user = Provider.of<AuthProvider>(context, listen: false).authUser;
    if (user == null) return;

    if (!silent) {
      setState(() => _loadingMessages = true);
    }
    
    try {
      final chatList = await _db.getMessages(user.id, _selectedDoctor!['id']);
      if (mounted) {
        setState(() {
          _messages = chatList;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error fetching messages: $e');
    } finally {
      if (!silent && mounted) {
        setState(() => _loadingMessages = false);
      }
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedDoctor == null) return;

    _messageController.clear();
    
    try {
      await _db.sendMessage(
        receiverId: _selectedDoctor!['id'],
        messageText: text,
      );
      _scrollToBottom();
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
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

    if (_loadingDoctors) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (_doctors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No doctors are currently active in this clinic to chat with.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Horizontal Doctor Selector List
        Container(
          height: 90,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _doctors.length,
            itemBuilder: (context, index) {
              final doc = _doctors[index];
              final isSelected = _selectedDoctor?['id'] == doc['id'];
              
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ChoiceChip(
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        doc['full_name'] ?? 'Doctor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      Text(
                        'Dentist',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedDoctor = doc;
                      });
                      _loadMessages();
                    }
                  },
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: isDark ? AppTheme.darkBg : Colors.grey.shade100,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              );
            },
          ),
        ),

        // Message Thread Area
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _messages.isEmpty
                  ? _buildEmptyChat()
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

        // Message Composer Bar
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
                      hintText: 'Type your message...',
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
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 60,
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start a Conversation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask a question or request advice from your dentist.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
