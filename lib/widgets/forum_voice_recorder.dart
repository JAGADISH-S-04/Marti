import 'package:flutter/material.dart';
import 'dart:io';
import '../widgets/CI_chat_voice_recorder.dart';

/// A wrapper around ChatVoiceRecorder specifically for forum posts and comments
class ForumVoiceRecorder extends StatelessWidget {
  final Function(File, String?, Duration) onVoiceRecorded;
  final Color? primaryColor;
  final Color? accentColor;
  final String? targetLanguage;

  const ForumVoiceRecorder({
    Key? key,
    required this.onVoiceRecorded,
    this.primaryColor,
    this.accentColor,
    this.targetLanguage = 'auto',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChatVoiceRecorder(
      onVoiceRecorded: onVoiceRecorded,
      primaryColor: primaryColor ?? const Color(0xFF8B4513),
      accentColor: accentColor ?? const Color(0xFFDAA520),
      targetLanguage: targetLanguage ?? 'auto',
    );
  }
}
