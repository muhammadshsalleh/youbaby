import 'package:flutter/material.dart';
// import 'translation_service.dart';

class LanguageSettingsPage extends StatefulWidget {
  // final Function(Locale) onLocaleChanged;

  // LanguageSettingsPage({required this.onLocaleChanged});

  @override
  _LanguageSettingsPageState createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  // State variable to store the selected language
  String? _selectedLanguage = 'English';

  // final TranslationService _translationService = TranslationService();
  String translatedText = ''; // Store the translated text

  // void _translate(String text, String targetLang) async {
  //   try {
  //     String translation =
  //         await _translationService.translate(text, targetLang);
  //     setState(() {
  //       translatedText = translation;
  //     });
  //   } catch (e) {
  //     print(e); // Handle any errors here
  //   }
  // }     

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Language Settings",
            style: TextStyle(
              color: Color(0xFFEBE0D0),
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Language:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFA81B60),
              ),
            ),
            SizedBox(height: 16),

            // Radio button for English
            RadioListTile<String>(
              title: const Text('English'),
              value: 'English',
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value;
                });
                // _translate('Help & Support', 'en'); // Example usage
                // widget.onLocaleChanged(Locale('en')); // Set locale to English
              },
            ),

            // Radio button for Bahasa Melayu
            RadioListTile<String>(
              title: const Text('Bahasa Melayu'),
              value: 'Bahasa Melayu',
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                setState(() {
                  _selectedLanguage = value;
                });
                // _translate('Help & Support', 'ms'); // Example usage
                // widget.onLocaleChanged(Locale('ms')); // Set locale to Malay
              },
            ), // end radiobtn bm

            SizedBox(height: 20),
            // Display the translated text
            Text(translatedText),
          ],
        ),
      ),
    );
  }
}
