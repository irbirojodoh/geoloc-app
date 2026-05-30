import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../data/models/dm_conversation.dart';
import '../data/models/dm_message.dart';

/// Persists DM ciphertext and conversation metadata locally.
class DmLocalStorage {
  Box<Map>? _conversationsBox;
  Box<Map>? _messagesBox;

  Future<void> init() async {
    _conversationsBox ??=
        await Hive.openBox<Map>(AppConfig.dmConversationsBox);
    _messagesBox ??= await Hive.openBox<Map>(AppConfig.dmMessagesBox);
  }

  Future<void> clearAll() async {
    await init();
    await _conversationsBox!.clear();
    await _messagesBox!.clear();
  }

  Future<void> upsertConversation(DmConversation conversation) async {
    await init();
    await _conversationsBox!.put(
      conversation.conversationId,
      conversation.toJson(),
    );
  }

  Future<List<DmConversation>> getConversations() async {
    await init();
    final items = _conversationsBox!.values
        .map((raw) => DmConversation.fromLocalJson(Map<String, dynamic>.from(raw)))
        .toList();
    items.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return items;
  }

  Future<DmConversation?> getConversation(String conversationId) async {
    await init();
    final raw = _conversationsBox!.get(conversationId);
    if (raw == null) return null;
    return DmConversation.fromLocalJson(Map<String, dynamic>.from(raw));
  }

  Future<void> upsertMessage(DmMessage message) async {
    await init();
    await _messagesBox!.put(message.messageId, message.toLocalJson());
  }

  Future<void> removeConversation(String conversationId) async {
    await init();
    await _conversationsBox!.delete(conversationId);
    final toRemove = _messagesBox!.keys.where((key) {
      final raw = _messagesBox!.get(key);
      if (raw == null) return false;
      return Map<String, dynamic>.from(raw)['conversation_id'] == conversationId;
    }).toList();
    for (final key in toRemove) {
      await _messagesBox!.delete(key);
    }
  }

  Future<List<DmMessage>> getMessagesForConversation(String conversationId) async {
    await init();
    return _messagesBox!.values
        .map((raw) => DmMessage.fromLocalJson(Map<String, dynamic>.from(raw)))
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }
}
