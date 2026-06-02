import 'dart:math';

class StudySession {
  final String id;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  StudySession({
    required this.id,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
  });

  // Factory to create a session when it starts, before completion
  factory StudySession.start({
    required String description,
    required DateTime startTime,
  }) {
    return StudySession(
      id: generateUuid(),
      description: description,
      startTime: startTime,
      endTime: startTime, // placeholder until completed
      durationSeconds: 0,
    );
  }

  // Helper method to create a completed session from an existing start state
  StudySession complete(DateTime endTime) {
    return StudySession(
      id: id,
      description: description,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: endTime.difference(startTime).inSeconds,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_seconds': durationSeconds,
    };
  }

  // JSON deserialization
  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as String,
      description: json['description'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      durationSeconds: json['duration_seconds'] as int,
    );
  }

  // Generate a random UUID v4
  static String generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    
    // Set UUID v4 specific bits (version 4 and variant 1)
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 1

    final hex = values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
