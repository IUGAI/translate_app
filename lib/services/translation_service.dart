import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import '../config/env.dart';

class TranslationService {
  TranslationService() {
    OpenAI.apiKey = Env.openaiApiKey;
  }

  bool get isApiKeySet => Env.openaiApiKey.isNotEmpty;

  Future<Map<String, String>> translate(
    String text,
    String lang1,
    String lang2,
  ) async {
    if (!isApiKeySet) {
      throw Exception('OpenAI API key is not set');
    }

    try {
      final chatCompletion = await OpenAI.instance.chat.create(
        model: "gpt-4o-mini",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                "Ты — профессиональный синхронный переводчик высшего класса. Твоя роль — 'теневой интерпретатор'.\n\n"
                "ЗАДАЧА:\n"
                "Мгновенно переводи живую разговорную речь между Языком A и Язык B.\n"
                "Язык A: $lang1, Язык B: $lang2.\n\n"
                "ФИЛОСОФИЯ ПЕРЕВОДА:\n"
                "- НИКОГДА не переводи дословно. Переводи СМЫСЛ и ЭМОЦИЮ.\n"
                "- Используй живой, современный разговорный язык. Если в оригинале есть сленг, вежливость или идиома — подбери эквивалент на целевом языке.\n"
                "- При переводе на КОРЕЙСКИЙ: используй стиль ХА-Ё-ЧЕ (해요체). Это вежливый, но дружелюбный разговорный стиль. Избегай чрезмерно официального 'Sumnida'.\n"
                "- Добавляй естественные корейские частицы и окончания (например, ~네요, ~죠, ~군요), чтобы речь звучала как у носителя.\n"
                "- При переводе на РУССКИЙ: сочетай естественность и краткость.\n"
                "- Перевод должен звучать так, будто человек изначально говорит на этом языке.\n\n"
                "ТЕХНИЧЕСКИЕ ПРАВИЛА:\n"
                "- СТРОГО ЗАПРЕЩЕНО: пояснения, кавычки, названия языков, знаки '(...)' или '---'.\n"
                "- Перевод предназначен для немедленного ГОЛОСОВОГО озвучивания.\n"
                "- Ответ должен быть ТОЛЬКО в формате JSON: {\"translation\": \"...\", \"toLanguage\": \"A\" или \"B\"}.\n"
                "- toLanguage — это КУДА ты перевел (A или B).",
              ),
            ],
            role: OpenAIChatMessageRole.system,
          ),
          OpenAIChatCompletionChoiceMessageModel(
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(text),
            ],
            role: OpenAIChatMessageRole.user,
          ),
        ],
      );

      final content =
          chatCompletion.choices.first.message.content?.first.text ?? "{}";
      final Map<String, dynamic> data = jsonDecode(content);

      return {
        "translation": data["translation"]?.toString() ?? "Error",
        "toLanguage": data["toLanguage"]?.toString() ?? "B",
      };
    } catch (e) {
      return {"translation": "Error: $e", "toLanguage": lang2};
    }
  }
}
