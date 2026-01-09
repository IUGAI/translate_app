import 'package:flutter/foundation.dart';
import '../services/translation_service.dart';
import '../services/speech_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? translation;

  ChatMessage({required this.text, this.isUser = true, this.translation});
}

class ChatSession {
  final String id;
  final DateTime date;
  final String fromLanguage;
  final String toLanguage;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.date,
    required this.fromLanguage,
    required this.toLanguage,
    required this.messages,
  });
}

class AppLanguage {
  final String name;
  final String sttCode;
  final String ttsCode;

  AppLanguage({
    required this.name,
    required this.sttCode,
    required this.ttsCode,
  });
}

class AppVoice {
  final String name;
  final String description;
  final double pitch;
  final double rate;
  final bool isMale;
  final String openaiVoice;

  AppVoice({
    required this.name,
    required this.description,
    required this.pitch,
    required this.rate,
    required this.isMale,
    required this.openaiVoice,
  });
}

class AppState extends ChangeNotifier {
  final TranslationService _translationService = TranslationService();
  final SpeechService _speechService = SpeechService();

  static final List<AppLanguage> supportedLanguages = [
    AppLanguage(name: "Russian", sttCode: "ru-RU", ttsCode: "ru-RU"),
    AppLanguage(name: "Korean", sttCode: "ko-KR", ttsCode: "ko-KR"),
    AppLanguage(name: "English", sttCode: "en-US", ttsCode: "en-US"),
    AppLanguage(name: "Vietnamese", sttCode: "vi-VN", ttsCode: "vi-VN"),
    AppLanguage(name: "Chinese", sttCode: "zh-CN", ttsCode: "zh-CN"),
  ];

  static final List<AppVoice> supportedVoices = [
    AppVoice(
      name: "Atlas",
      description: "Male, neutral, confident, natural",
      pitch: 0.75, // Deep
      rate: 0.5,
      isMale: true,
      openaiVoice: "onyx",
    ),
    AppVoice(
      name: "Luna",
      description: "Female, clear, lively, conversational",
      pitch: 1.25, // High & Lively
      rate: 0.55,
      isMale: false,
      openaiVoice: "nova",
    ),
    AppVoice(
      name: "Iris",
      description: "Female, kind, calm, soft, inviting",
      pitch: 0.85, // Lower/Softer female
      rate: 0.45, // Calm but not too slow
      isMale: false,
      openaiVoice: "shimmer",
    ),
  ];

  late AppLanguage _fromLanguage;
  late AppLanguage _toLanguage;
  late AppVoice selectedVoice;

  AppState() {
    _fromLanguage = supportedLanguages[0]; // Russian
    _toLanguage = supportedLanguages[1]; // Korean
    selectedVoice = supportedVoices[0]; // Atlas
  }

  void setVoice(AppVoice voice) {
    selectedVoice = voice;
    notifyListeners();

    // Instant preview
    _speechService.speak(
      "Hello, I am ${voice.name}. Your new conversational voice.",
      "en-US",
      () {},
      pitch: voice.pitch,
      rate: voice.rate,
      isMale: voice.isMale,
      openaiVoice: voice.openaiVoice,
    );
  }

  List<ChatMessage> messages = [];
  List<ChatSession> sessionHistory = [];

  // Mock account data
  String userPlan = "Pro";
  int requestLimit = 100;
  int usedRequests = 85;

  String get fromLanguage => _fromLanguage.name;
  String get fromLanguageCode => _fromLanguage.sttCode;
  String get fromTtsCode => _fromLanguage.ttsCode;
  String get toLanguage => _toLanguage.name;
  String get toLanguageCode => _toLanguage.sttCode;
  String get toTtsCode => _toLanguage.ttsCode;

  bool isListening = false;
  bool isSpeaking = false;
  bool isLoopActive = false;
  bool isVoiceMode = false;
  bool isMicMuted = false;
  String currentSpeech = "";

  bool get isApiKeySet => _translationService.isApiKeySet;

  void toggleMicMute() {
    isMicMuted = !isMicMuted;
    if (isMicMuted) {
      _speechService.stopListening();
      isListening = false;
    } else if (isVoiceMode && !isSpeaking) {
      _startListeningLoop();
    }
    notifyListeners();
  }

  void _handleLanguageChange() {
    if (isVoiceMode) {
      _speechService.stopListening();
      _speechService.stopSpeaking();
      isListening = false;
      isSpeaking = false;
      notifyListeners();
      // Restart loop with new languages
      Future.delayed(const Duration(milliseconds: 300), () {
        if (isVoiceMode) _startListeningLoop();
      });
    } else {
      notifyListeners();
    }
  }

  void swapLanguages() {
    final temp = _fromLanguage;
    _fromLanguage = _toLanguage;
    _toLanguage = temp;
    _handleLanguageChange();
  }

  void setFromLanguage(AppLanguage language) {
    _fromLanguage = language;
    _handleLanguageChange();
  }

  void setToLanguage(AppLanguage language) {
    _toLanguage = language;
    _handleLanguageChange();
  }

  void startNewSession() {
    if (messages.isNotEmpty) {
      saveCurrentSession();
    }
    messages = [];
    notifyListeners();
  }

  void saveCurrentSession() {
    if (messages.isEmpty) return;
    sessionHistory.insert(
      0,
      ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        fromLanguage: _fromLanguage.name,
        toLanguage: _toLanguage.name,
        messages: List.from(messages),
      ),
    );
  }

  void deleteSession(String id) {
    sessionHistory.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void updateLanguages(String from, String fromCode, String to, String toCode) {
    _fromLanguage = supportedLanguages.firstWhere(
      (l) => l.name == from,
      orElse: () => supportedLanguages[0],
    );
    _toLanguage = supportedLanguages.firstWhere(
      (l) => l.name == to,
      orElse: () => supportedLanguages[1],
    );
    notifyListeners();
  }

  bool _isSpeechInitialized = false;

  Future<void> _ensureSpeechInitialized() async {
    if (_isSpeechInitialized) return;
    bool available = await _speechService.initSpeech(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          isListening = false;
          notifyListeners();
        } else if (status == 'listening') {
          isListening = true;
          notifyListeners();
        }
      },
      onError: (error) {
        isListening = false;
        notifyListeners();
        if (isLoopActive && isVoiceMode) {
          Future.delayed(
            const Duration(milliseconds: 500),
            () => _startListeningLoop(),
          );
        }
      },
    );
    _isSpeechInitialized = available;
  }

  Future<void> toggleListening() async {
    if (isVoiceMode) {
      isVoiceMode = false;
      isLoopActive = false;
      _speechService.stopListening();
      _speechService.stopSpeaking();
      isListening = false;
      isSpeaking = false;
      notifyListeners();
    } else {
      isVoiceMode = true;
      isLoopActive = true;
      await _startListeningLoop();
    }
  }

  double soundLevel = 0.0;

  Future<void> _startListeningLoop() async {
    if (!isLoopActive || isSpeaking || !isVoiceMode || isMicMuted) return;

    await _ensureSpeechInitialized();
    if (_isSpeechInitialized) {
      currentSpeech = "";
      _speechService.startListening(
        localeId: fromLanguageCode,
        onPartialResult: (result) {
          currentSpeech = result;
        },
        onFinalResult: (result) async {
          currentSpeech = result;
          soundLevel = 0.0;
          notifyListeners();
          if (currentSpeech.isNotEmpty) {
            await _processSpeech(currentSpeech);
          } else if (isLoopActive && isVoiceMode) {
            _startListeningLoop();
          }
        },
        onSoundLevel: (level) {
          double normalized = (level + 2) / 12;
          if (normalized < 0) normalized = 0;
          if (normalized > 1) normalized = 1;

          soundLevel = soundLevel * 0.4 + normalized * 0.6;
          notifyListeners();
        },
      );
    }
  }

  Future<void> _processSpeech(String text) async {
    isSpeaking = true;
    notifyListeners();

    final userMsg = ChatMessage(text: text, isUser: true);
    messages.insert(0, userMsg);
    notifyListeners();

    try {
      final result = await _translationService.translate(
        text,
        fromLanguage,
        toLanguage,
      );

      final translation = result["translation"]!;
      final targetIndicator = result["toLanguage"]!;

      messages[0] = ChatMessage(
        text: text,
        isUser: true,
        translation: translation,
      );
      notifyListeners();

      String ttsLangCode = (targetIndicator == "A") ? fromTtsCode : toTtsCode;

      await _speechService.speak(
        translation,
        ttsLangCode,
        () {
          isSpeaking = false;
          swapLanguages();
          if (isLoopActive && isVoiceMode) {
            _startListeningLoop();
          }
        },
        pitch: selectedVoice.pitch,
        rate: selectedVoice.rate,
        isMale: selectedVoice.isMale,
        openaiVoice: selectedVoice.openaiVoice,
      );
    } catch (e) {
      isSpeaking = false;
      notifyListeners();
      if (isLoopActive && isVoiceMode) _startListeningLoop();
    }
  }
}
