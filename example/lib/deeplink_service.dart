import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:entrig_chat_example/screens/chat_screen.dart';
import 'package:entrig_chat_example/supabase_table.dart';
import 'package:flutter/material.dart';

class DeeplinkService {
  static final _appLinks = AppLinks();
  static late GlobalKey<NavigatorState> _navigatorKey;
  static StreamSubscription<Uri>? _sub;

  static void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });

    _sub = _appLinks.uriLinkStream.listen(_handleUri);
  }

  static Future<void> handleDeeplink(String deeplink) async {
    final uri = Uri.tryParse(deeplink);
    if (uri != null) await _handleUri(uri);
  }

  // Handles: groupchat://chat/{groupId}
  static Future<void> _handleUri(Uri uri) async {
    if (uri.host == 'chat' && uri.pathSegments.isNotEmpty) {
      final groupId = uri.pathSegments.first;
      try {
        final group = await SupabaseTable.groups
            .select()
            .eq('id', groupId)
            .single();
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              groupId: group['id'] as String,
              groupName: group['name'] as String,
            ),
          ),
        );
      } catch (_) {}
    }
  }

  static void dispose() => _sub?.cancel();
}
