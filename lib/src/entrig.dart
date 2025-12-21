import 'dart:async';
import 'package:entrig/src/auto_register_with_supabase_auth.dart';
import 'package:entrig/src/entrig_method_channel.dart';
import 'package:entrig/src/notification_event.dart';
import 'entrig_platform_interface.dart';

class Entrig {
  static Stream<NotificationEvent> get onNotificationOpened =>
      EntrigNotificationChannel.onNotificationOpened.stream;

  static Stream<NotificationEvent> get foregroundNotifications =>
      EntrigNotificationChannel.foregroundNotifications.stream;

  static Future<String?> register({required String userId}) {
    return EntrigPlatform.instance.register(userId);
  }

  static Future<bool> unregister() {
    return EntrigPlatform.instance.unregister();
  }

  static Future init({
    required String apiKey,
    AutoRegisterWithSupabaseAuth? autoRegisterWithSupabaseAuth,
    bool handlePermission = true,
  }) {
    return EntrigPlatform.instance.init(
      apiKey: apiKey,
      autoRegisterWithSupabaseAuth: autoRegisterWithSupabaseAuth,
      handlePermission: handlePermission,
    );
  }

  static Future<bool> requestPermission() {
    return EntrigPlatform.instance.requestPermission();
  }

  static void dispose() {
    EntrigNotificationChannel.dispose();
  }
}
