import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../core/utils/template_parser.dart';

class QuickAccessService {
  static const MethodChannel _channel = MethodChannel('com.contextvault.app/quick_access');
  static bool _isNotificationActive = false;

  static bool isNotificationActive() => _isNotificationActive;

  static Future<bool> startQuickAccessNotification() async {
    try {
      final bool success = await _channel.invokeMethod('startQuickAccessNotification');
      if (success) _isNotificationActive = true;
      return success;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> stopQuickAccessNotification() async {
    try {
      final bool success = await _channel.invokeMethod('stopQuickAccessNotification');
      if (success) _isNotificationActive = false;
      return success;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> toggleNotification(bool enable) async {
    if (enable) {
      await startQuickAccessNotification();
    } else {
      await stopQuickAccessNotification();
    }
  }

  /// Dialog brought up when tapping the notification inside the app
  static Future<void> showQuickSearchDialog(BuildContext context) async {
    final snippets = await DatabaseService.getSnippets();
    if (!context.mounted) return;

    String searchQuery = '';
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = snippets.where((s) {
              if (searchQuery.trim().isEmpty) return true;
              return s.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  s.content.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF0D1117),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF30363D)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF58A6FF), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '⚡ Quick Access Search',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8B949E), size: 20),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (val) {
                        setDialogState(() => searchQuery = val);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search snippets...',
                        hintStyle: const TextStyle(color: Color(0xFF484F58), fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF8B949E), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF161B22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF30363D)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No snippets found', style: TextStyle(color: Color(0xFF8B949E))),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (c, idx) {
                                final snippet = filtered[idx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161B22),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF30363D)),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(
                                      snippet.title,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      snippet.content,
                                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(Icons.content_copy, color: Color(0xFF58A6FF), size: 16),
                                    onTap: () async {
                                      final parsed = await TemplateParser.parseTemplate(snippet.content);
                                      await Clipboard.setData(ClipboardData(text: parsed));
                                      await DatabaseService.markUsed(snippet);
                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Copied: "${snippet.title}"'),
                                            backgroundColor: const Color(0xFF238636),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
