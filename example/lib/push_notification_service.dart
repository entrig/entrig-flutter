import 'package:entrig/entrig.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static Future<void> register() async {
    await Entrig.register(
      userId: Supabase.instance.client.auth.currentUser!.id,
    );
  }
}
