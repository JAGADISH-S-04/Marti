import 'package:flutter/foundation.dart';
import 'gemini_image_service.dart';
import 'gemini_image_uploader.dart';

/// Multi-turn conversational image editing manager
/// 
/// This class enables the powerful conversational editing capabilities
/// of Gemini 2.5 Flash Image Preview (nano-banana) that were impossible
/// with Firebase AI SDK v2.2.0.
/// 
/// Features:
/// - Multi-turn editing conversations
/// - Context preservation across edits
/// - Edit history tracking and rollback
/// - Iterative refinement workflows
/// - Collaborative editing sessions
/// - Smart prompt enhancement based on context
class GeminiConversationalEditor {
  final GeminiImageService _geminiService;
  
  // Conversation state
  final List<EditingTurn> _editHistory = [];
  ProcessedImage? _currentImage;
  String? _sessionId;
  Map<String, dynamic> _sessionMetadata = {};
  
  // Configuration
  final int maxHistoryLength;
  final bool enableSmartPrompts;
  final bool preserveAllVersions;
  
  GeminiConversationalEditor(
    this._geminiService, {
    this.maxHistoryLength = 10,
    this.enableSmartPrompts = true,
    this.preserveAllVersions = false,
  }) {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  /// Start a new editing conversation with an initial image
  Future<ConversationResult> startConversation({
    required ProcessedImage initialImage,
    String? initialPrompt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('💬 Starting new conversation session: $_sessionId');
      
      _currentImage = initialImage;
      _editHistory.clear();
      _sessionMetadata = metadata ?? {};
      
      // Create initial turn
      final initialTurn = EditingTurn(
        turnNumber: 1,
        prompt: initialPrompt ?? 'Initial image loaded',
        inputImage: initialImage,
        timestamp: DateTime.now(),
        turnType: TurnType.initial,
      );
      
      ConversationResult result;
      
      if (initialPrompt != null) {
        // Apply initial enhancement/edit
        final editResult = await _geminiService.editImage(
          sourceImageBytes: initialImage.bytes,
          editPrompt: _enhancePrompt(initialPrompt, context: 'initial_edit'),
          mode: EditingMode.enhance,
        );
        
        final processedOutput = await GeminiImageUploader.uploadFromBytes(
          editResult.primaryImage,
          mimeType: editResult.primaryMimeType,
          filename: 'conversation_turn_1.${_getExtensionFromMime(editResult.primaryMimeType)}',
        );
        
        initialTurn.outputImage = processedOutput;
        initialTurn.geminiResult = editResult;
        
        _currentImage = processedOutput;
        
        result = ConversationResult(
          success: true,
          currentImage: processedOutput,
          lastEdit: initialTurn,
          conversationLength: 1,
          sessionId: _sessionId!,
        );
      } else {
        result = ConversationResult(
          success: true,
          currentImage: initialImage,
          lastEdit: initialTurn,
          conversationLength: 1,
          sessionId: _sessionId!,
        );
      }
      
      _editHistory.add(initialTurn);
      
      debugPrint('✅ Conversation started successfully');
      return result;
    } catch (e) {
      debugPrint('❌ Error starting conversation: $e');
      rethrow;
    }
  }
  
  /// Continue the conversation with a new editing instruction
  Future<ConversationResult> continueConversation(String prompt) async {
    try {
      if (_currentImage == null) {
        throw ConversationException('No active conversation. Call startConversation first.');
      }
      
      final turnNumber = _editHistory.length + 1;
      debugPrint('💬 Conversation turn $turnNumber: $prompt');
      
      // Create enhanced prompt with context
      final contextualPrompt = _buildContextualPrompt(prompt);
      
      // Perform the edit
      final editResult = await _geminiService.continueConversationalEdit(
        currentImageBytes: _currentImage!.bytes,
        followUpPrompt: contextualPrompt,
        mimeType: _currentImage!.mimeType,
      );
      
      // Process the output image
      final processedOutput = await GeminiImageUploader.uploadFromBytes(
        editResult.primaryImage,
        mimeType: editResult.primaryMimeType,
        filename: 'conversation_turn_$turnNumber.${_getExtensionFromMime(editResult.primaryMimeType)}',
      );
      
      // Create editing turn record
      final turn = EditingTurn(
        turnNumber: turnNumber,
        prompt: prompt,
        contextualPrompt: contextualPrompt,
        inputImage: _currentImage!,
        outputImage: processedOutput,
        geminiResult: editResult,
        timestamp: DateTime.now(),
        turnType: TurnType.edit,
      );
      
      // Update conversation state
      _editHistory.add(turn);
      _currentImage = processedOutput;
      
      // Manage history length
      if (_editHistory.length > maxHistoryLength) {
        final removed = _editHistory.removeAt(0);
        debugPrint('🗑️ Removed old turn from history: ${removed.turnNumber}');
      }
      
      debugPrint('✅ Conversation continued successfully');
      
      return ConversationResult(
        success: true,
        currentImage: processedOutput,
        lastEdit: turn,
        conversationLength: _editHistory.length,
        sessionId: _sessionId!,
      );
    } catch (e) {
      debugPrint('❌ Error continuing conversation: $e');
      rethrow;
    }
  }
  
  /// Undo the last edit and return to previous version
  Future<ConversationResult> undoLastEdit() async {
    try {
      if (_editHistory.length <= 1) {
        throw ConversationException('Cannot undo - no previous edits available');
      }
      
      debugPrint('↶ Undoing last edit');
      
      // Remove the last turn
      final removedTurn = _editHistory.removeLast();
      final previousTurn = _editHistory.last;
      
      // Restore previous image
      _currentImage = previousTurn.outputImage ?? previousTurn.inputImage;
      
      debugPrint('✅ Edit undone, returned to turn ${previousTurn.turnNumber}');
      
      return ConversationResult(
        success: true,
        currentImage: _currentImage!,
        lastEdit: previousTurn,
        conversationLength: _editHistory.length,
        sessionId: _sessionId!,
        undoPerformed: true,
        undoneEdit: removedTurn,
      );
    } catch (e) {
      debugPrint('❌ Error undoing edit: $e');
      rethrow;
    }
  }
  
  /// Go back to a specific turn in the conversation
  Future<ConversationResult> goToTurn(int turnNumber) async {
    try {
      if (turnNumber < 1 || turnNumber > _editHistory.length) {
        throw ConversationException('Invalid turn number: $turnNumber');
      }
      
      debugPrint('🎯 Going to turn $turnNumber');
      
      final targetTurn = _editHistory[turnNumber - 1];
      _currentImage = targetTurn.outputImage ?? targetTurn.inputImage;
      
      // Remove all turns after the target
      if (turnNumber < _editHistory.length) {
        final removedTurns = _editHistory.sublist(turnNumber);
        _editHistory.removeRange(turnNumber, _editHistory.length);
        debugPrint('🗑️ Removed ${removedTurns.length} turns after turn $turnNumber');
      }
      
      return ConversationResult(
        success: true,
        currentImage: _currentImage!,
        lastEdit: targetTurn,
        conversationLength: _editHistory.length,
        sessionId: _sessionId!,
      );
    } catch (e) {
      debugPrint('❌ Error going to turn: $e');
      rethrow;
    }
  }
  
  /// Create a branch from the current state
  Future<ConversationResult> branchConversation(String branchPrompt) async {
    try {
      debugPrint('🌿 Creating conversation branch');
      
      if (_currentImage == null) {
        throw ConversationException('No active conversation to branch from');
      }
      
      // Save current state for potential rollback (if needed)
      // final originalHistory = List<EditingTurn>.from(_editHistory);
      // final originalImage = _currentImage!;
      
      // Create branch metadata
      final branchMetadata = {
        'branch_point': _editHistory.length,
        'branch_timestamp': DateTime.now().toIso8601String(),
        'original_session': _sessionId,
      };
      
      // Start new branch session
      final branchSessionId = '${_sessionId}_branch_${DateTime.now().millisecondsSinceEpoch}';
      _sessionId = branchSessionId;
      _sessionMetadata.addAll(branchMetadata);
      
      // Continue with branch edit
      final result = await continueConversation(branchPrompt);
      
      debugPrint('✅ Conversation branch created: $branchSessionId');
      
      return result.copyWith(
        sessionId: branchSessionId,
        isBranch: true,
        branchMetadata: branchMetadata,
      );
    } catch (e) {
      debugPrint('❌ Error creating branch: $e');
      rethrow;
    }
  }
  
  /// Get conversation summary and statistics
  ConversationSummary getConversationSummary() {
    final totalEdits = _editHistory.where((t) => t.turnType == TurnType.edit).length;
    final totalEnhancements = _editHistory.where((t) => t.turnType == TurnType.enhance).length;
    
    return ConversationSummary(
      sessionId: _sessionId!,
      totalTurns: _editHistory.length,
      totalEdits: totalEdits,
      totalEnhancements: totalEnhancements,
      conversationDuration: _editHistory.isNotEmpty 
          ? DateTime.now().difference(_editHistory.first.timestamp)
          : Duration.zero,
      currentImageSize: _currentImage?.processedSize ?? 0,
      totalPromptLength: _editHistory.fold(0, (sum, turn) => sum + turn.prompt.length),
      metadata: _sessionMetadata,
    );
  }
  
  /// Export conversation history
  List<Map<String, dynamic>> exportHistory() {
    return _editHistory.map((turn) => turn.toJson()).toList();
  }
  
  /// Get all image versions from the conversation
  List<ProcessedImage> getAllVersions() {
    final versions = <ProcessedImage>[];
    
    for (final turn in _editHistory) {
      if (turn.outputImage != null) {
        versions.add(turn.outputImage!);
      }
    }
    
    return versions;
  }
  
  /// Clear conversation and reset state
  void clearConversation() {
    _editHistory.clear();
    _currentImage = null;
    _sessionMetadata.clear();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('🧹 Conversation cleared');
  }
  
  // Private helper methods
  
  String _buildContextualPrompt(String userPrompt) {
    if (!enableSmartPrompts || _editHistory.isEmpty) {
      return userPrompt;
    }
    
    // Build context from recent edits
    final recentTurns = _editHistory.reversed.take(3).toList();
    final contextLines = <String>[];
    
    contextLines.add('Previous editing context:');
    for (int i = 0; i < recentTurns.length; i++) {
      final turn = recentTurns[i];
      contextLines.add('${i + 1}. ${turn.prompt}');
    }
    
    contextLines.add('');
    contextLines.add('Current edit request: $userPrompt');
    contextLines.add('');
    contextLines.add('Apply this edit while maintaining consistency with the previous modifications and the overall artistic vision.');
    
    return contextLines.join('\n');
  }
  
  String _enhancePrompt(String basePrompt, {String? context}) {
    if (!enableSmartPrompts) return basePrompt;
    
    final enhancements = <String>[];
    
    switch (context) {
      case 'initial_edit':
        enhancements.add('This is the initial enhancement of the uploaded image.');
        break;
      case 'follow_up':
        enhancements.add('This is a follow-up edit building on previous modifications.');
        break;
    }
    
    enhancements.add('Ensure high quality, professional results.');
    enhancements.add('Maintain consistency in style, lighting, and composition.');
    
    return '$basePrompt\n\n${enhancements.join(' ')}';
  }
  
  String _getExtensionFromMime(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
        return 'jpg';
      case 'image/webp':
        return 'webp';
      default:
        return 'png';
    }
  }
}

/// Represents a single turn in the editing conversation
class EditingTurn {
  final int turnNumber;
  final String prompt;
  final String? contextualPrompt;
  final ProcessedImage inputImage;
  ProcessedImage? outputImage;
  ImageGenerationResult? geminiResult;
  final DateTime timestamp;
  final TurnType turnType;
  final Map<String, dynamic> metadata;
  
  EditingTurn({
    required this.turnNumber,
    required this.prompt,
    this.contextualPrompt,
    required this.inputImage,
    this.outputImage,
    this.geminiResult,
    required this.timestamp,
    required this.turnType,
    this.metadata = const {},
  });
  
  Duration get processingTime {
    return geminiResult != null 
        ? geminiResult!.timestamp.difference(timestamp)
        : Duration.zero;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'turn_number': turnNumber,
      'prompt': prompt,
      'contextual_prompt': contextualPrompt,
      'timestamp': timestamp.toIso8601String(),
      'turn_type': turnType.toString(),
      'processing_time_ms': processingTime.inMilliseconds,
      'input_image_size': inputImage.processedSize,
      'output_image_size': outputImage?.processedSize,
      'metadata': metadata,
    };
  }
  
  @override
  String toString() {
    return 'EditingTurn(#$turnNumber: $prompt)';
  }
}

/// Types of editing turns
enum TurnType {
  initial,    // Initial image load
  edit,       // Standard edit operation
  enhance,    // Enhancement operation
  style,      // Style transfer
  compose,    // Multi-image composition
}

/// Result of a conversation operation
class ConversationResult {
  final bool success;
  final ProcessedImage currentImage;
  final EditingTurn lastEdit;
  final int conversationLength;
  final String sessionId;
  final bool undoPerformed;
  final EditingTurn? undoneEdit;
  final bool isBranch;
  final Map<String, dynamic>? branchMetadata;
  final String? error;
  
  const ConversationResult({
    required this.success,
    required this.currentImage,
    required this.lastEdit,
    required this.conversationLength,
    required this.sessionId,
    this.undoPerformed = false,
    this.undoneEdit,
    this.isBranch = false,
    this.branchMetadata,
    this.error,
  });
  
  ConversationResult copyWith({
    bool? success,
    ProcessedImage? currentImage,
    EditingTurn? lastEdit,
    int? conversationLength,
    String? sessionId,
    bool? undoPerformed,
    EditingTurn? undoneEdit,
    bool? isBranch,
    Map<String, dynamic>? branchMetadata,
    String? error,
  }) {
    return ConversationResult(
      success: success ?? this.success,
      currentImage: currentImage ?? this.currentImage,
      lastEdit: lastEdit ?? this.lastEdit,
      conversationLength: conversationLength ?? this.conversationLength,
      sessionId: sessionId ?? this.sessionId,
      undoPerformed: undoPerformed ?? this.undoPerformed,
      undoneEdit: undoneEdit ?? this.undoneEdit,
      isBranch: isBranch ?? this.isBranch,
      branchMetadata: branchMetadata ?? this.branchMetadata,
      error: error ?? this.error,
    );
  }
  
  @override
  String toString() {
    return 'ConversationResult(session: $sessionId, turns: $conversationLength, success: $success)';
  }
}

/// Summary of conversation statistics
class ConversationSummary {
  final String sessionId;
  final int totalTurns;
  final int totalEdits;
  final int totalEnhancements;
  final Duration conversationDuration;
  final int currentImageSize;
  final int totalPromptLength;
  final Map<String, dynamic> metadata;
  
  const ConversationSummary({
    required this.sessionId,
    required this.totalTurns,
    required this.totalEdits,
    required this.totalEnhancements,
    required this.conversationDuration,
    required this.currentImageSize,
    required this.totalPromptLength,
    required this.metadata,
  });
  
  @override
  String toString() {
    return 'ConversationSummary(turns: $totalTurns, duration: ${conversationDuration.inMinutes}min)';
  }
}

/// Custom exception for conversation operations
class ConversationException implements Exception {
  final String message;
  final String? details;
  
  const ConversationException(this.message, [this.details]);
  
  @override
  String toString() {
    return 'ConversationException: $message${details != null ? '\nDetails: $details' : ''}';
  }
}