// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class TranslationService {
//   final String _baseUrl = 'https://libretranslate.de';

//   Future<String> translate(String text, String targetLang) async {
//     final response = await http.post(
//       Uri.parse('$_baseUrl/translate'),
//       headers: {
//         'Content-Type': 'application/json',
//       },
//       body: jsonEncode({
//         'q': text,
//         'target': targetLang,
//         'source': 'auto', // Automatically detect the source language
//       }),
//     );

//     if (response.statusCode == 200) {
//       final responseData = json.decode(response.body);
//       return responseData['translatedText'];
//     } else {
//       throw Exception('Failed to translate text');
//     }
//   }
// }
