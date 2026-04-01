import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';

  /// Send a chat message. [messages] is the full history in OpenAI format.
  /// [systemPrompt] is prepended if non-null (used for PDF scope).
  Future<String> sendChatMessage({
    required String apiKey,
    required List<Map<String, String>> messages,
    String? systemPrompt,
    String model = 'gpt-4o',
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': [
        if (systemPrompt != null && systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        ...messages,
      ],
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['choices'][0]['message']['content'] as String;
    } else {
      final error = jsonDecode(response.body);
      final message = error['error']?['message'] ?? 'Unknown error';
      throw Exception('OpenAI API error ${response.statusCode}: $message');
    }
  }

  /// Transcribe an audio file using Whisper.
  Future<String> transcribeAudio({
    required String apiKey,
    required String audioFilePath,
    String model = 'whisper-1',
    String language = 'en',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/audio/transcriptions'),
    );

    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = model;
    request.fields['language'] = language;
    request.fields['response_format'] = 'text';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        audioFilePath,
        filename: File(audioFilePath).uri.pathSegments.last,
      ),
    );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return body.trim();
    } else {
      Map<String, dynamic>? error;
      try {
        error = jsonDecode(body) as Map<String, dynamic>?;
      } catch (_) {}
      final message = error?['error']?['message'] ?? body;
      throw Exception('Whisper API error ${streamed.statusCode}: $message');
    }
  }

  /// Validate an API key by making a lightweight models list call.
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
