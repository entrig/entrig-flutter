import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'entrig_method_channel.dart';

abstract class EntrigPlatform extends PlatformInterface {
  EntrigPlatform() : super(token: _token);

  static final Object _token = Object();

  static EntrigPlatform _instance = EntrigNotificationChannel();

  static EntrigPlatform get instance => _instance;

  static set instance(EntrigPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> init({
    required String apiKey,
    bool handlePermission = true,
    bool showForegroundNotification = true,
  }) {
    throw UnimplementedError('init() has not been implemented.');
  }

  Future<String?> register(String userId) {
    throw UnimplementedError('register() has not been implemented.');
  }

  Future<bool> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  Future<bool> unregister() {
    throw UnimplementedError('unregister() has not been implemented.');
  }
}
