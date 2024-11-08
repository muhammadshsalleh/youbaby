import 'package:flutter/material.dart';
import 'package:youbaby/charity_page.dart';
import 'package:youbaby/community_page.dart';

 // Helper function to limit the text to 50 characters
  String limitText(String text, {int maxChars = 70}) {
    if (text.length <= maxChars) {
      return text;
    } else {
      return text.substring(0, maxChars) + '...'; // Append ellipsis if truncated
    }
  }

  // Function to limit words (for content)
  String limitWords(String content, {int maxWords = 100}) {
    List<String> words = content.split(' ');
    if (words.length <= maxWords) {
      return content;
    } else {
      return words.take(maxWords).join(' ') + '...'; // Append ellipsis if truncated
    }
  }