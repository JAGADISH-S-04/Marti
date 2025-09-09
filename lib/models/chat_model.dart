import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderType; // 'customer' or 'artisan'
  final String message;
  final String? imageUrl;
  final String? voiceUrl;
  final String? transcription;
  final Duration? voiceDuration;
  final DateTime timestamp;
  final bool isRead;
  final String? messageType; // 'text', 'image', 'voice', 'progress_update'

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.message,
    this.imageUrl,
    this.voiceUrl,
    this.transcription,
    this.voiceDuration,
    required this.timestamp,
    this.isRead = false,
    this.messageType = 'text',
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    Duration? voiceDuration;
    if (map['voiceDurationSeconds'] != null) {
      voiceDuration = Duration(seconds: map['voiceDurationSeconds'] as int);
    }

    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderType: map['senderType'] ?? '',
      message: map['message'] ?? '',
      imageUrl: map['imageUrl'],
      voiceUrl: map['voiceUrl'],
      transcription: map['transcription'],
      voiceDuration: voiceDuration,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      messageType: map['messageType'] ?? 'text',
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'message': message,
      'imageUrl': imageUrl,
      'voiceUrl': voiceUrl,
      'transcription': transcription,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'messageType': messageType,
    };

    if (voiceDuration != null) {
      map['voiceDurationSeconds'] = voiceDuration!.inSeconds;
    }

    return map;
  }
}