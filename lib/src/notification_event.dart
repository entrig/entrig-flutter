class NotificationEvent {
  NotificationEvent({
    required this.title,
    required this.body,
    this.type,
    this.deeplink,
    this.data,
  });

  String title;
  String body;
  String? type;
  String? deeplink;
  Map? data;

  factory NotificationEvent.fromMap(Map eventData) {
    return NotificationEvent(
      title: eventData['title'] ?? '',
      body: eventData['body'] ?? '',
      type: eventData['type'],
      deeplink: eventData['deeplink'],
      data: eventData['data'],
    );
  }
}
