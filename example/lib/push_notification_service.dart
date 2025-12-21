// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:entrig/entrig.dart';
import 'package:entrig_chat_example/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static StreamController<dynamic> controller =
      StreamController<dynamic>.broadcast();

  static void init(BuildContext context) {
    Entrig.onNotificationOpened.listen((event) {
      handleNotification(context, event);
    });
  }

  static Future<void> handleNotification(
    context,
    NotificationEvent event,
  ) async {
    print('event is ${event.type}');
    print('event data is ${event.data}');
    switch (event.type) {
      // when a new user joined the group the current user created
      case 'new_member':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('New Member Joined'),
            content: Text(
              '${event.data?['users']?['name'] ?? 'Someone'} joined "${event.data?['groups']?['name'] ?? 'your group'}"!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to the group chat
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        groupId: event.data!['groups']['id'],
                        groupName: event.data!['groups']['name'],
                      ),
                    ),
                  );
                },
                child: const Text('View Group'),
              ),
            ],
          ),
        );
        break;

      // when a new message is sent by others in the group
      case 'new_message':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) {
              return ChatScreen(
                groupId: event.data!['groups']['id'],
                groupName: event.data!['groups']['name'],
              );
            },
          ),
        );

        break;

      // when new group created by others
      case 'new_group':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('New Group Created'),
            content: Text(
              'A new group "${event.data?['name'] ?? 'Unknown'}" has been created!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to the group
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        groupId: event.data!['id'],
                        groupName: event.data!['name'],
                      ),
                    ),
                  );
                },
                child: const Text('View'),
              ),
            ],
          ),
        );
        break;

      default:
    }
  }

  static Future<void> register() async {
    await Entrig.register(
      userId: Supabase.instance.client.auth.currentUser!.id,
    );
  }
}
