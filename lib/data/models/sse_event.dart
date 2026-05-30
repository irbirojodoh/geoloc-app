import 'notification.dart';

/// Parsed payload from the shared notifications SSE stream.
sealed class SseEvent {
  const SseEvent();
}

class NotificationSseEvent extends SseEvent {
  final AppNotification notification;

  const NotificationSseEvent(this.notification);
}

class DmSseEvent extends SseEvent {
  final Map<String, dynamic> json;
  final String type;

  const DmSseEvent({required this.json, required this.type});
}
