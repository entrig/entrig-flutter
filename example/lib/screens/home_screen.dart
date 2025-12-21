// ignore_for_file: use_build_context_synchronously

import 'package:entrig_chat_example/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_table.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _groups = [];
  Set<String> _joinedGroupIds = {};
  bool _isLoading = true;
  String? _userName;

  @override
  void initState() {
    PushNotificationService.init(context);
    super.initState();
    _loadUserAndGroups();
  }

  Future<void> _loadUserAndGroups() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final userData = await SupabaseTable.users
            .select()
            .eq('id', userId)
            .single();
        _userName = userData['name'];
      }

      await _loadGroups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Load all groups
      final data = await SupabaseTable.groups.select().order('created_at');

      // Load user's joined groups
      if (userId != null) {
        final participantData = await SupabaseTable.groupMembers
            .select('group_id')
            .eq('user_id', userId);

        final joinedIds = participantData
            .map((p) => p['group_id'] as String)
            .toSet();

        if (mounted) {
          setState(() {
            _groups = List<Map<String, dynamic>>.from(data);
            _joinedGroupIds = joinedIds;
          });
        }
      } else {
        if (mounted) {
          setState(() => _groups = List<Map<String, dynamic>>.from(data));
        }
      }
    } catch (e) {
      print('error is $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading groups: $e')));
      }
    }
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) return;

        // Insert group
        final groupData = await SupabaseTable.groups
            .insert({'name': result.trim(), 'created_by': userId})
            .select()
            .single();

        // Add creator as participant
        await SupabaseTable.groupMembers.insert({
          'group_id': groupData['id'],
          'user_id': userId,
        });

        await _loadGroups();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
        }
      }
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> group) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final groupId = group['id'];
    final isJoined = _joinedGroupIds.contains(groupId);

    if (!isJoined) {
      // Show join confirmation
      final shouldJoin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Join Group'),
          content: Text('Do you want to join "${group['name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Join'),
            ),
          ],
        ),
      );

      if (shouldJoin != true) return;

      try {
        // Add user to group members
        await SupabaseTable.groupMembers.insert({
          'group_id': groupId,
          'user_id': userId,
        });

        setState(() {
          _joinedGroupIds.add(groupId);
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChatScreen(groupId: groupId, groupName: group['name']),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error joining group: $e')));
        }
      }
    } else {
      // Already joined, just navigate
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(groupId: groupId, groupName: group['name']),
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userName != null ? 'Hi, $_userName!' : 'Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await PushNotificationService.register();

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Token Registered")));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_add, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No groups yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _createGroup,
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Group'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadGroups,
              child: ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  final isOwner =
                      group['created_by'] == _supabase.auth.currentUser?.id;
                  final isJoined = _joinedGroupIds.contains(group['id']);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isJoined ? Colors.blue : Colors.grey,
                        child: Text(
                          group['name'][0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(
                        group['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: isJoined
                          ? Text(
                              isOwner ? 'Owner' : 'Joined',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: Icon(
                        isJoined ? Icons.arrow_forward_ios : Icons.login,
                        size: 16,
                      ),
                      onTap: () => _joinGroup(group),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.add),
      ),
    );
  }
}
