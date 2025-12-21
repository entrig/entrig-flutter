import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTable {
  static final _supabase = Supabase.instance.client;

  static final users = _supabase.from('users');
  static final messages = _supabase.from('messages');
  static final groups = _supabase.from('groups');
  static final groupMembers = _supabase.from('group_members');
}

class User {
  User({required this.name, required this.id});
  String id;
  String name;
}

class Message {
  Message({required this.content, required this.userId, required this.groupId});

  String content;
  String userId;
  String groupId;
}

class Group {
  Group({required this.name, required this.createdBY});

  String name;
  String createdBY;
}

class GroupMember {
  GroupMember({required this.groupId, required this.userId});
  String groupId;
  String userId;
}
