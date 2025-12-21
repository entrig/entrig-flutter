import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_table.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, String> _userNames = {};
  bool _isLoading = true;
  SupabaseStreamBuilder? _messageStream;

  @override
  void initState() {
    super.initState();
    _joinGroup();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _joinGroup() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Check if already a participant
      final existing = await SupabaseTable.groupMembers
          .select()
          .eq('group_id', widget.groupId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        await SupabaseTable.groupMembers.insert({
          'group_id': widget.groupId,
          'user_id': userId,
        });
      }
    } catch (e) {
      debugPrint('Error joining group: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      final data = await SupabaseTable.messages
          .select('*, users!inner(name)')
          .eq('group_id', widget.groupId)
          .order('created_at');

      final messages = List<Map<String, dynamic>>.from(data);

      // Extract user names
      final names = <String, String>{};
      for (var msg in messages) {
        if (msg['users'] != null) {
          names[msg['user_id']] = msg['users']['name'];
        }
      }

      if (mounted) {
        setState(() {
          _userNames = names;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      }
    }
  }

  void _subscribeToMessages() {
    _messageStream = SupabaseTable.messages
        .stream(primaryKey: ['id'])
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: false);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _messageController.clear();

    try {
      await SupabaseTable.messages.insert({
        'content': content,
        'user_id': userId,
        'group_id': widget.groupId,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
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
    final currentUserId = _supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName),
            // Text(
            //   '${_profileNames.length} members',
            //   style: const TextStyle(fontSize: 12),
            // ),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: _messageStream,
        builder: (context, snap) {
          List<Map<String, dynamic>> messages = snap.data ?? [];
          return Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet\nBe the first to send a message!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message['user_id'] == currentUserId;
                          final senderName =
                              _userNames[message['user_id']] ?? 'Unknown';

                          return Padding(
                            padding: EdgeInsets.only(
                              left: isMe ? 60 : 8,
                              right: isMe ? 8 : 60,
                              bottom: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      bottom: 4,
                                    ),
                                    child: Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.blue[600]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(isMe ? 18 : 4),
                                      topRight: Radius.circular(isMe ? 4 : 18),
                                      bottomLeft: const Radius.circular(18),
                                      bottomRight: const Radius.circular(18),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    message['content'],
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isMe
                                          ? Colors.white
                                          : Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
