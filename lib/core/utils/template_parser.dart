import 'package:flutter/services.dart';

class TemplateParser {
  static List<String> extractVariables(String template) {
    final regex = RegExp(r'\{input:([a-zA-Z0-9_]+)\}');
    final matches = regex.allMatches(template);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  static List<String> extractListVariables(String template) {
    final regex = RegExp(r'\{list:([a-zA-Z0-9_]+)\}');
    final matches = regex.allMatches(template);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  static Future<String> parseTemplate(
    String template, {
    Map<String, String> userInputs = const {},
    Map<String, List<String>> userLists = const {},
  }) async {
    String parsed = template;
    final now = DateTime.now();

    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    parsed = parsed.replaceAll('{date}', formattedDate);

    final formattedTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    parsed = parsed.replaceAll('{time}', formattedTime);

    if (parsed.contains('{clipboard}')) {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final clipText = clipboardData?.text ?? '';
      parsed = parsed.replaceAll('{clipboard}', clipText);
    }

    userInputs.forEach((key, value) {
      parsed = parsed.replaceAll('{input:$key}', value);
    });

    userLists.forEach((key, items) {
      final validItems = items.where((i) => i.trim().isNotEmpty).toList();
      if (validItems.isEmpty) {
        parsed = parsed.replaceAll('{list:$key}', '');
      } else {
        final formattedList = validItems
            .asMap()
            .entries
            .map((entry) => "${entry.key + 1}. ${entry.value.trim()}")
            .join('\n');
        parsed = parsed.replaceAll('{list:$key}', formattedList);
      }
    });

    return parsed;
  }
}
