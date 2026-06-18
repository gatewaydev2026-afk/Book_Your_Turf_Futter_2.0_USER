// models/facebook_event_model.dart
class FacebookEventRequest {
  final String eventName;
  final Map<String, dynamic> parameters;
  final double? valueToSum;
  final String userId;
  final String deviceId;

  FacebookEventRequest({
    required this.eventName,
    required this.parameters,
    this.valueToSum,
    required this.userId,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'event_name': eventName,
      'parameters': parameters,
      'value_to_sum': valueToSum,
      'user_id': userId,
      'device_id': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  factory FacebookEventRequest.fromJson(Map<String, dynamic> json) {
    return FacebookEventRequest(
      eventName: json['event_name'],
      parameters: json['parameters'] ?? {},
      valueToSum: json['value_to_sum'],
      userId: json['user_id'] ?? '',
      deviceId: json['device_id'] ?? '',
    );
  }
}

class StoredFacebookEvent {
  final String id;
  final String eventName;
  final Map<String, dynamic> parameters;
  final double? valueToSum;
  final String userId;
  final String deviceId;
  final DateTime createdAt;
  bool isSynced;
  int retryCount;

  StoredFacebookEvent({
    required this.id,
    required this.eventName,
    required this.parameters,
    this.valueToSum,
    required this.userId,
    required this.deviceId,
    required this.createdAt,
    this.isSynced = false,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_name': eventName,
      'parameters': parameters,
      'value_to_sum': valueToSum,
      'user_id': userId,
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
      'retry_count': retryCount,
    };
  }

  factory StoredFacebookEvent.fromJson(Map<String, dynamic> json) {
    return StoredFacebookEvent(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      eventName: json['event_name'] ?? '',
      parameters: json['parameters'] ?? {},
      valueToSum: json['value_to_sum'],
      userId: json['user_id'] ?? '',
      deviceId: json['device_id'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isSynced: json['is_synced'] ?? false,
      retryCount: json['retry_count'] ?? 0,
    );
  }

  FacebookEventRequest toRequest() {
    return FacebookEventRequest(
      eventName: eventName,
      parameters: parameters,
      valueToSum: valueToSum,
      userId: userId,
      deviceId: deviceId,
    );
  }
}