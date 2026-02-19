class NotificationEvent {
  NotificationEvent({
    required this.title,
    required this.body,
    this.type,
    this.data,
  });

  String title;
  String body;
  String? type;
  Map? data;

  factory NotificationEvent.fromMap(Map eventData) {
    return NotificationEvent(
      title: eventData['title'] ?? '',
      body: eventData['body'] ?? '',
      type: eventData['type'],
      data: eventData['data'],
    );
  }
}
