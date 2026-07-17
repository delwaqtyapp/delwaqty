/// AI engine data types and provider-agnostic abstraction.

/// Result of a text analysis operation.
class AIResult {
  /// Creates an [AIResult] instance.
  const AIResult({
    required this.text,
    required this.confidence,
    this.entities = const [],
    this.metadata = const {},
  });

  /// The analyzed text output.
  final String text;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Extracted entities from the text.
  final List<Entity> entities;

  /// Additional metadata from the analysis.
  final Map<String, dynamic> metadata;
}

/// An entity extracted from text.
class Entity {
  /// Creates an [Entity] instance.
  const Entity({
    required this.text,
    required this.type,
    this.confidence = 1.0,
    this.startOffset,
    this.endOffset,
  });

  /// The entity text value.
  final String text;

  /// The type of entity (e.g., person, location, organization).
  final EntityType type;

  /// Confidence score for this entity.
  final double confidence;

  /// Start offset in the original text.
  final int? startOffset;

  /// End offset in the original text.
  final int? endOffset;
}

/// Types of entities that can be extracted.
enum EntityType {
  /// A person's name.
  person,

  /// A location or address.
  location,

  /// An organization name.
  organization,

  /// A date or time reference.
  date,

  /// A monetary value.
  money,

  /// A phone number.
  phone,

  /// An email address.
  email,

  /// A URL.
  url,

  /// A product name.
  product,

  /// A category or topic.
  category,

  /// Any other type of entity.
  other,
}

/// Classification result for content analysis.
class ClassificationResult {
  /// Creates a [ClassificationResult] instance.
  const ClassificationResult({
    required this.label,
    required this.confidence,
    this.alternatives = const [],
  });

  /// The primary classification label.
  final String label;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Alternative classifications with their scores.
  final List<ClassificationAlternative> alternatives;
}

/// An alternative classification suggestion.
class ClassificationAlternative {
  /// Creates a [ClassificationAlternative] instance.
  const ClassificationAlternative({
    required this.label,
    required this.confidence,
  });

  /// The classification label.
  final String label;

  /// Confidence score for this alternative.
  final double confidence;
}

/// A chat message for conversational AI.
class ChatMessage {
  /// Creates a [ChatMessage] instance.
  const ChatMessage({required this.role, required this.content});

  /// The role of the message sender.
  final ChatRole role;

  /// The message content.
  final String content;
}

/// Role of a chat message sender.
enum ChatRole {
  /// The user sending messages.
  user,

  /// The AI assistant responding.
  assistant,

  /// A system-level instruction.
  system,
}

/// Supported AI providers.
enum AIProvider {
  /// OpenAI (GPT models).
  openai,

  /// Google Gemini.
  gemini,

  /// Anthropic Claude.
  claude,

  /// Local on-device model.
  local,
}

/// Provider-agnostic AI abstraction interface.
///
/// Provides unified access to AI capabilities regardless of the underlying
/// provider (OpenAI, Gemini, Claude, or local models).
abstract interface class AIService {
  /// Analyzes the given [text] and returns structured results.
  Future<AIResult> analyzeText(String text, {String? task});

  /// Generates text based on the given [prompt].
  Future<String> generateText(
    String prompt, {
    int? maxTokens,
    double? temperature,
  });

  /// Classifies [content] into one of the provided [categories].
  Future<ClassificationResult> classifyContent(
    String content,
    List<String> categories,
  );

  /// Extracts named entities from the given [text].
  Future<List<Entity>> extractEntities(String text);

  /// Summarizes the given [text] to a maximum of [maxLength] characters.
  Future<String> summarize(String text, {int? maxLength});

  /// Translates [text] into the specified [targetLanguage].
  Future<String> translate(String text, String targetLanguage);

  /// Detects the language of the given [text].
  Future<String> detectLanguage(String text);

  /// Calculates a similarity score between [text1] and [text2].
  Future<double> similarityScore(String text1, String text2);

  /// Generates a vector embedding for the given [text].
  Future<List<double>> embed(String text);

  /// Sends a conversational chat request with the given [messages].
  Stream<String> chat(
    List<ChatMessage> messages, {
    String? systemPrompt,
    double? temperature,
  });

  /// Checks whether the AI service is currently available and reachable.
  Future<bool> isAvailable();

  /// Returns the identifier of the currently active AI provider.
  AIProvider getProvider();
}

/// Debug implementation of [AIService] that returns placeholder results.
class DebugAIService implements AIService {
  @override
  Future<AIResult> analyzeText(String text, {String? task}) async =>
      AIResult(text: text, confidence: 0.5);

  @override
  Future<String> generateText(
    String prompt, {
    int? maxTokens,
    double? temperature,
  }) async => 'Generated text for: $prompt';

  @override
  Future<ClassificationResult> classifyContent(
    String content,
    List<String> categories,
  ) async => ClassificationResult(
    label: categories.firstOrNull ?? 'unknown',
    confidence: 0.5,
  );

  @override
  Future<List<Entity>> extractEntities(String text) async => [];

  @override
  Future<String> summarize(String text, {int? maxLength}) async => text;

  @override
  Future<String> translate(String text, String targetLanguage) async => text;

  @override
  Future<String> detectLanguage(String text) async => 'en';

  @override
  Future<double> similarityScore(String text1, String text2) async => 0.0;

  @override
  Future<List<double>> embed(String text) async => [];

  @override
  Stream<String> chat(
    List<ChatMessage> messages, {
    String? systemPrompt,
    double? temperature,
  }) => Stream.value('Debug response');

  @override
  Future<bool> isAvailable() async => true;

  @override
  AIProvider getProvider() => AIProvider.local;
}
