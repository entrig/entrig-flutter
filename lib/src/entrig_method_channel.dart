import 'dart:async';
import 'package:entrig/src/notification_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'entrig_platform_interface.dart';

class EntrigNotificationChannel extends EntrigPlatform {
  static NotificationEvent? _initialNotification;
  static bool _initialNotificationEmitted = false;

  static final StreamController<NotificationEvent> onNotificationOpened =
      StreamController<NotificationEvent>.broadcast(
        onListen: () {
          if (_initialNotification != null && !_initialNotificationEmitted) {
            onNotificationOpened.add(_initialNotification!);
            _initialNotificationEmitted = true;
          }
        },
      );

  static final StreamController<NotificationEvent> foregroundNotifications =
      StreamController<NotificationEvent>.broadcast();

  @visibleForTesting
  final methodChannel = const MethodChannel('com.entrig.plugin.notifications');

  @override
  Future<void> init({
    required String apiKey,
    bool handlePermission = true,
    bool showForegroundNotification = true,
  }) async {
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    handler();
    await methodChannel.invokeMethod<bool>('init', {
      'apiKey': apiKey,
      'handlePermission': handlePermission,
      'showForegroundNotification': showForegroundNotification,
    });
  }

  @override
  Future<String?> register(userId) async {
    try {
      final token = await methodChannel.invokeMethod<String>('register', {
        "userId": userId,
      });
      return token;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'requestPermission',
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> unregister() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('unregister');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> handler() async {
    // Check for initial notification and store it
    try {
      final result = await methodChannel.invokeMethod<Map>(
        'getInitialNotification',
      );
      if (result != null) {
        _initialNotification = NotificationEvent.fromMap(
          result.cast<String, dynamic>(),
        );
      }
    } catch (e) {
      // Initial notification not available
    }

    methodChannel.setMethodCallHandler((call) async {
      print('>>>>>>> event ${call.method} ${call.arguments}');
      switch (call.method) {
        case 'notifications#onClick':
          onNotificationOpened.add(NotificationEvent.fromMap(call.arguments));

          break;

        case 'notifications#onForeground':
          foregroundNotifications.add(
            NotificationEvent.fromMap(call.arguments),
          );

          break;
        default:
      }
    });
  }

  /// Dispose method for cleanup - call this when you no longer need the plugin
  static void dispose() {
    if (!onNotificationOpened.isClosed) {
      onNotificationOpened.close();
    }
    if (!foregroundNotifications.isClosed) {
      foregroundNotifications.close();
    }
  }
}
