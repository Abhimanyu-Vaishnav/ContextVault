import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/snippet.dart';
import '../../services/database_service.dart';
import '../../core/utils/template_parser.dart';

class QuickSearchDialog extends StatefulWidget {
  const QuickSearchDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const QuickSearchDialog(),
    );
  }

  @override
  State<QuickSearchDialog> createState() => _QuickSearchDialogState();
}

class _QuickSearchDialogState extends State<QuickSearchDialog> {
  String _searchQuery = '';
  List<Snippet> _snippets = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSnippets();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSnippets() async {
    try {
      await DatabaseService.init();
      final loaded = await DatabaseService.getSnippets();
      if (mounted) {
        setState(() {
          _snippets = loaded;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyAndClose(Snippet snippet) async {
    HapticFeedback.heavyImpact();
    final textToCopy = await TemplateParser.parseTemplate(snippet.content);
    await Clipboard.setData(ClipboardData(text: textToCopy));
    await DatabaseService.markUsed(snippet);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ Copied to clipboard: "${snippet.title}"'),
          backgroundColor: const Color(0xFF238636),
          duration: const Duration(seconds: 2),
        ),
      );
      // Minimize app back to previous active application
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (mediaWidth * 0.9).clamp(280.0, 360.0);

    final filtered = _snippets.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).take(10).toList();

    return Dialog(
      backgroundColor: const Color(0xFF0D1117),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF30363D), width: 1.5),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF58A6FF), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Quick Access Vault',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF8B949E), size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search snippets...',
                hintStyle: const TextStyle(color: Color(0xFF484F58), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8B949E), size: 18),
                filled: true,
                fillColor: const Color(0xFF161B22),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Snippet List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching snippets found',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final snippet = filtered[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF30363D)),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  snippet.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  snippet.content,
                                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.content_copy, color: Color(0xFF58A6FF), size: 16),
                                onTap: () => _copyAndClose(snippet),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
