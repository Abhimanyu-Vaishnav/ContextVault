import 'package:flutter/material.dart';
import '../../models/snippet.dart';
import '../../services/database_service.dart';
import '../paywall/paywall_sheet.dart';
import '../../services/revenue_cat_service.dart';

class SnippetEditorSheet extends StatefulWidget {
  final Snippet? snippet;

  const SnippetEditorSheet({super.key, this.snippet});

  @override
  State<SnippetEditorSheet> createState() => _SnippetEditorSheetState();
}

class _SnippetEditorSheetState extends State<SnippetEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.snippet?.title ?? '');
    _contentController = TextEditingController(
      text: widget.snippet?.content ?? '',
    );
    _isPinned = widget.snippet?.isPinned ?? false;
  }

  void _insertTag(String tag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final newText = text.replaceRange(
      selection.start == -1 ? text.length : selection.start,
      selection.end == -1 ? text.length : selection.end,
      tag,
    );
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset:
            (selection.start == -1 ? text.length : selection.start) +
            tag.length,
      ),
    );
  }

  // Future<void> _save() async {
  //   if (_titleController.text.trim().isEmpty ||
  //       _contentController.text.trim().isEmpty) {
  //     return;
  //   }

  //   final snippet = widget.snippet ?? Snippet();
  //   snippet.title = _titleController.text.trim();
  //   snippet.content = _contentController.text;
  //   snippet.isPinned = _isPinned;

  //   await DatabaseService.saveSnippet(snippet);
  //   if (mounted) Navigator.pop(context);
  // }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return;
    }

    // Check Pro status if adding new snippet
    if (widget.snippet == null) {
      final count = await DatabaseService.getSnippetCount();
      final isPro = await RevenueCatService.isProUser();

      if (count >= 25 && !isPro) {
        if (mounted) {
          final unlocked = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const PaywallSheet(),
          );
          if (unlocked != true) return;
        }
      }
    }

    final snippet = widget.snippet ?? Snippet();
    snippet.title = _titleController.text.trim();
    snippet.content = _contentController.text;
    snippet.isPinned = _isPinned;

    await DatabaseService.saveSnippet(snippet);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.snippet == null ? 'New Snippet' : 'Edit Snippet',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                color: _isPinned ? Colors.amber : Colors.grey,
                onPressed: () => setState(() => _isPinned = !_isPinned),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Snippet Title (e.g. Bug Report Reply)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  'Content... Use {date}, {time}, {clipboard}, or {input:name}',
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip('{date}'),
                _buildChip('{time}'),
                _buildChip('{clipboard}'),
                _buildChip('{input:variable}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _save,
            child: const Text(
              'Save Snippet',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF58A6FF)),
        ),
        backgroundColor: const Color(0xFF161B22),
        side: const BorderSide(color: Color(0xFF30363D)),
        onPressed: () => _insertTag(label),
      ),
    );
  }
}
