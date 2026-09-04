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
          title: 'Quick Client Proposal',
          category: 'Work',
          content: 'Hi {input:ClientName}, here is the breakdown for {input:ProjectScope}. We can wrap this up by {date}. Let me know if you\'re ready to proceed!',
          isPinned: true,
        ),
        Snippet(
          title: 'Bug Report Triage',
          category: 'Dev',
          content: '[BUG-{date}] Issue: {input:IssueSummary}\nReproducible: Yes\nReported at: {time}\nSystem Note: {clipboard}',
          isPinned: true,
        ),
        Snippet(
          title: 'Current Timestamp',
          category: 'Personal',
          content: 'Logged at {date} - {time}',
        ),
        Snippet(
          title: 'Clipboard Quote',
          category: 'Work',
          content: '> {clipboard}',
        ),
        Snippet(
          title: 'Meeting Note',
          category: 'Work',
          content: 'Follow-up regarding our discussion on {date}.',
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
