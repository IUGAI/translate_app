import 'dart:io';
import 'dart:convert';
import '../config/env.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  static const String _openaiApiKey = Env.openaiApiKey;

  Future<bool> initSpeech({
    required Function(String) onStatus,
    required Function(dynamic) onError,
  }) async {
    return await _speech.initialize(onStatus: onStatus, onError: onError);
  }

  void startListening({
    required String localeId,
    required Function(String) onPartialResult,
    required Function(String) onFinalResult,
    required Function(double) onSoundLevel,
  }) async {
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onFinalResult(result.recognizedWords);
        } else {
          onPartialResult(result.recognizedWords);
        }
      },
      onSoundLevelChange: onSoundLevel,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: localeId,
    );
  }

  void stopListening() async {
    await _speech.stop();
  }

  List<dynamic>? _cachedVoices;

  Future<void> speak(
    String text,
    String languageCode,
    VoidCallback onComplete, {
    double pitch = 1.0,
    double rate = 0.5,
    bool isMale = false,
    String? openaiVoice,
  }) async {
    // 1. Try OpenAI TTS first for premium quality
    if (openaiVoice != null) {
      try {
        final directory = await getTemporaryDirectory();
        final fileName = "speech_${DateTime.now().millisecondsSinceEpoch}.mp3";
        final filePath = "${directory.path}/$fileName";

        debugPrint("TTS: Direct Neural Synthesis [$openaiVoice] -> $filePath");

        final response = await http.post(
          Uri.parse("https://api.openai.com/v1/audio/speech"),
          headers: {
            "Authorization": "Bearer $_openaiApiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": "tts-1",
            "input": text,
            "voice": openaiVoice,
            "speed":
                rate * 2.0, // Scale 0.5 (standard) to 1.0 (OpenAI standard)
          }),
        );

        if (response.statusCode == 200) {
          final audioFile = File(filePath);
          await audioFile.writeAsBytes(response.bodyBytes);

          debugPrint(
            "TTS: Neural Synthesis successful. Playing from $filePath",
          );

          _player.onPlayerComplete.listen((_) {
            onComplete();
          });

          await _player.stop();
          await _player.play(DeviceFileSource(filePath));
          return; // Success
        } else {
          throw Exception(
            "OpenAI API error: ${response.statusCode} - ${response.body}",
          );
        }
      } catch (e) {
        debugPrint("TTS CRITICAL ERROR (Neural): $e");
        debugPrint("TTS: Falling back to System Voices...");
      }
    }

    await _tts.stop();
    await _tts.setLanguage(languageCode);

    // Try to find a matching system voice for the gender
    try {
      if (_cachedVoices == null) {
        _cachedVoices = await _tts.getVoices;
      }

      if (_cachedVoices != null) {
        final searchLang = languageCode
            .toLowerCase()
            .split('-')[0]
            .split('_')[0];
        final localeVoices = _cachedVoices!.where((v) {
          final String vLang = v["locale"].toString().toLowerCase();
          return vLang.contains(searchLang);
        }).toList();

        debugPrint(
          "TTS: Found ${localeVoices.length} voices for $languageCode",
        );

        if (localeVoices.isNotEmpty) {
          // Improved gender detection patterns
          bool isVoiceMale(String name) {
            final n = name.toLowerCase();
            return n.contains("male") ||
                n.contains("yuri") ||
                n.contains("alex") ||
                n.contains("daniel") ||
                n.contains("min-ho") ||
                n.contains("sergey") ||
                n.contains("paul") ||
                n.contains("james") ||
                n.contains("mike");
          }

          bool isVoiceFemale(String name) {
            final n = name.toLowerCase();
            return n.contains("female") ||
                n.contains("milena") ||
                n.contains("samantha") ||
                n.contains("yuna") ||
                n.contains("victoria") ||
                n.contains("anna") ||
                n.contains("elana") ||
                n.contains("kyung-hwa");
          }

          // Priority: 1. Enhanced/Premium/Siri, 2. Gender Match, 3. Defaults
          bool isPremium(String name) {
            final n = name.toLowerCase();
            return n.contains("enhanced") ||
                n.contains("premium") ||
                n.contains("siri");
          }

          final premiumVoices = localeVoices
              .where((v) => isPremium(v["name"].toString()))
              .toList();
          final candidateVoices = premiumVoices.isNotEmpty
              ? premiumVoices
              : localeVoices;

          final genderMatch = candidateVoices.firstWhere((v) {
            final String name = v["name"].toString().toLowerCase();
            final String gender = v["gender"]?.toString().toLowerCase() ?? "";

            if (isMale) {
              if (gender == "male" || isVoiceMale(name)) return true;
            } else {
              if (gender == "female" || isVoiceFemale(name)) return true;
            }
            return false;
          }, orElse: () => candidateVoices.first);

          final String selectedName = genderMatch["name"]
              .toString()
              .toLowerCase();
          bool systemIsMale =
              isVoiceMale(selectedName) ||
              (genderMatch["gender"]?.toString().toLowerCase() == "male");

          if (isMale && !systemIsMale) {
            pitch = pitch * 0.7;
          } else if (!isMale && systemIsMale) {
            pitch = pitch * 1.3;
          }

          debugPrint(
            "TTS: Selecting voice ${genderMatch["name"]} (Premium: ${isPremium(genderMatch["name"].toString())})",
          );
          await _tts.setVoice({
            "name": genderMatch["name"],
            "locale": genderMatch["locale"],
          });
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      debugPrint("Error selecting system voice: $e");
    }

    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);

    _tts.setCompletionHandler(() {
      onComplete();
    });

    debugPrint("TTS: Speaking '$text' in $languageCode with pitch $pitch");
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _player.stop();
  }

  bool get isListening => _speech.isListening;
}
