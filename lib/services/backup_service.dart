import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/snippet.dart';
import 'database_service.dart';

enum ImportConflictStrategy { append, overwrite }

class BackupService {
  /// Export all database snippets as a formatted JSON string
  static Future<String> exportSnippetsJson() async {
    try {
      final snippets = await DatabaseService.getSnippets(query: '', category: 'All');
      final List<Map<String, dynamic>> jsonList = snippets.map((s) => s.toMap()).toList();
      final Map<String, dynamic> exportData = {
        'version': 1,
        'appName': 'ContextVault',
        'exportedAt': DateTime.now().toIso8601String(),
        'snippetCount': jsonList.length,
        'snippets': jsonList,
      };
      return const JsonEncoder.withIndent('  ').convert(exportData);
    } catch (e) {
      debugPrint('[BackupService] Export error: $e');
      rethrow;
    }
  }

  /// Import snippets from JSON string with conflict resolution strategy
  static Future<int> importSnippetsJson(
    String jsonString, {
    ImportConflictStrategy strategy = ImportConflictStrategy.append,
  }) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      if (!data.containsKey('snippets') || data['snippets'] is! List) {
        throw FormatException('Invalid ContextVault backup format.');
      }

      final List<dynamic> snippetList = data['snippets'];
      final List<Snippet> importedSnippets =
          snippetList.map((item) => Snippet.fromMap(item as Map<String, dynamic>)).toList();

      if (strategy == ImportConflictStrategy.overwrite) {
        final currentSnippets = await DatabaseService.getSnippets(query: '', category: 'All');
        for (var s in currentSnippets) {
          if (s.id != null) {
            await DatabaseService.deleteSnippet(s.id!);
          }
        }
      }

      int count = 0;
      for (var snippet in importedSnippets) {
        // Reset ID to create new auto-increment entries during append
        if (strategy == ImportConflictStrategy.append) {
          snippet.id = null;
        }
        await DatabaseService.saveSnippet(snippet);
        count++;
      }

      return count;
    } catch (e) {
      debugPrint('[BackupService] Import error: $e');
      rethrow;
    }
  }

  /// Seed database with 5 practical ready-to-use Starter Kit snippets
  static Future<void> seedStarterKit() async {
    try {
      final existingCount = await DatabaseService.getSnippetCount();
      if (existingCount > 0) return; // Only seed on empty install

      final starterSnippets = [
        Snippet(
          title: 'Client Meeting Follow-up',
          category: 'Work',
          content: 'Hi {input:Client_Name},\n\nThanks for speaking with us on {date} at {time}.\nNext Steps:\n1. {input:Action_Item_1}\n2. {input:Action_Item_2}\n\nBest regards,\n[Your Name]',
          isPinned: true,
        ),
        Snippet(
          title: 'Bug Report Template',
          category: 'Dev',
          content: '🐛 **[Bug]: {input:Summary}**\n\n**Environment:** {input:OS_Device}\n**Date:** {date} {time}\n\n**Steps to Reproduce:**\n1. {input:Step_1}\n\n**Logs / Clipboard:**\n{clipboard}',
          isPinned: true,
        ),
        Snippet(
          title: 'Quick Invoice Note',
          category: 'Templates',
          content: 'Invoice #{input:Invoice_Number}\nClient: {input:Client_Name}\nDate: {date}\nAmount: \${input:Amount}\nPayment Method: {input:Payment_Method}',
        ),
        Snippet(
          title: 'Quick Calendar Sync',
          category: 'Personal',
          content: 'Hey! Let\'s catch up on {date} around {time}. Does that work for you?',
        ),
        Snippet(
          title: 'Code Review Response',
          category: 'Dev',
          content: 'LGTM! Tested on {date} at {time}.\nNote: {input:Review_Note}',
        ),
      ];

      for (var snippet in starterSnippets) {
        await DatabaseService.saveSnippet(snippet);
      }
      debugPrint('[BackupService] Seeded 5 starter kit snippets.');
    } catch (e) {
      debugPrint('[BackupService] Seed error: $e');
    }
  }
}
