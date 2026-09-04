import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Timer? _debounceTimer;
  String _evaluatedPreview = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.snippet?.title ?? '');
    _contentController = TextEditingController(
      text: widget.snippet?.content ?? '',
    );
    _isPinned = widget.snippet?.isPinned ?? false;

    _evaluatedPreview = _contentController.text;
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _evaluatedPreview = _contentController.text;
        });
      }
    });
  }

  void _insertTag(String tag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start == -1 ? text.length : selection.start;
    final end = selection.end == -1 ? text.length : selection.end;
    final newText = text.replaceRange(start, end, tag);
    
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
  }

  void _applyPredefinedTemplate(String title, String content) {
    setState(() {
      _titleController.text = title;
      _contentController.text = content;
      _evaluatedPreview = content;
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return;
    }

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

  Future<void> _delete() async {
    if (widget.snippet?.id == null) return;
    HapticFeedback.mediumImpact();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Text('Delete Snippet?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete "${widget.snippet!.title}"?',
          style: const TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDA3633),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await DatabaseService.deleteSnippet(widget.snippet!.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${widget.snippet!.title}"'),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF484F58),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Top Header & Pin Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.snippet == null ? 'New Snippet' : 'Edit Snippet',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  ),
                  color: _isPinned ? const Color(0xFFD29922) : const Color(0xFF8B949E),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isPinned = !_isPinned);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick-Insert Starter Templates
            const Text(
              'STARTER TEMPLATES',
              style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTemplateChip(
                    'Meeting Follow-up',
                    'Hi {input:Name},\n\nThanks for connecting today on {date} at {time}.\nKey Next Steps:\n1. {input:Task_1}\n\nBest,\n[Your Name]',
                  ),
                  _buildTemplateChip(
                    'Bug Report Template',
                    '🐛 **[Bug]: {input:Issue_Summary}**\n\n**Environment:** {input:OS_Device}\n**Timestamp:** {date} {time}\n**Steps to Reproduce:**\n1. {input:Step_1}\n\n**Clipboard Log:**\n{clipboard}',
                  ),
                  _buildTemplateChip(
                    'Quick Invoice Note',
                    'Receipt for {input:Client_Name}\nDate: {date}\nAmount: \${input:Amount}\nStatus: Paid via {input:Payment_Method}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Title Input Field
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Snippet Title (e.g. Bug Report Reply)',
                hintStyle: const TextStyle(color: Color(0xFF484F58)),
                filled: true,
                fillColor: const Color(0xFF161B22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

            // Content Textarea Input
            TextField(
              controller: _contentController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'Content... Use {date}, {time}, {clipboard}, or {input:name}',
                hintStyle: const TextStyle(color: Color(0xFF484F58)),
                filled: true,
                fillColor: const Color(0xFF161B22),
                contentPadding: const EdgeInsets.all(14),
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
            const SizedBox(height: 8),

            // Variable Insert Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTagChip('{date}'),
                  _buildTagChip('{time}'),
                  _buildTagChip('{clipboard}'),
                  _buildTagChip('{input:variable}'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Real-Time Live Preview Engine Container
            _buildLivePreviewContainer(),
            const SizedBox(height: 16),

            // Save Action Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _save,
              child: const Text(
                'Save Snippet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            // In-Editor Delete Button (If Editing Existing Snippet)
            if (widget.snippet?.id != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDA3633),
                  side: const BorderSide(color: Color(0xFFDA3633)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text(
                  'Delete Snippet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(
          title,
          style: const TextStyle(fontSize: 11, color: Color(0xFFE6EDE3), fontWeight: FontWeight.w500),
        ),
        avatar: const Icon(Icons.bolt, size: 14, color: Color(0xFFD29922)),
        backgroundColor: const Color(0xFF21262D),
        side: const BorderSide(color: Color(0xFF30363D)),
        onPressed: () => _applyPredefinedTemplate(title, content),
      ),
    );
  }

  Widget _buildTagChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF58A6FF), fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF161B22),
        side: const BorderSide(color: Color(0xFF30363D)),
        onPressed: () => _insertTag(label),
      ),
    );
  }

  Widget _buildLivePreviewContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility, size: 14, color: Color(0xFF58A6FF)),
              SizedBox(width: 6),
              Text(
                'LIVE PREVIEW',
                style: TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _evaluatedPreview.isEmpty
              ? const Text(
                  'Start typing above to see live tag evaluation...',
                  style: TextStyle(color: Color(0xFF484F58), fontSize: 13, fontStyle: FontStyle.italic),
                )
              : _buildRichPreviewWidget(_evaluatedPreview),
        ],
      ),
    );
  }

  Widget _buildRichPreviewWidget(String rawText) {
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    const clipboardStr = "[Clipboard Content]";

    final regExp = RegExp(r'\{date\}|\{time\}|\{clipboard\}|\{input:[^}]+\}');
    final matches = regExp.allMatches(rawText);

    if (matches.isEmpty) {
      return Text(
        rawText,
        style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.4),
      );
    }

    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: rawText.substring(lastMatchEnd, match.start),
          style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.4),
        ));
      }

      final tag = match.group(0)!;
      if (tag == '{date}') {
        spans.add(TextSpan(
          text: dateStr,
          style: const TextStyle(color: Color(0xFF79C0FF), fontWeight: FontWeight.bold, fontSize: 13),
        ));
      } else if (tag == '{time}') {
        spans.add(TextSpan(
          text: timeStr,
          style: const TextStyle(color: Color(0xFF79C0FF), fontWeight: FontWeight.bold, fontSize: 13),
        ));
      } else if (tag == '{clipboard}') {
        spans.add(TextSpan(
          text: clipboardStr,
          style: const TextStyle(color: Color(0xFFA5D6FF), fontStyle: FontStyle.italic, fontSize: 13),
        ));
      } else if (tag.startsWith('{input:')) {
        final varName = tag.substring(7, tag.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF388BFD).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.5)),
              ),
              child: Text(
                'var: $varName',
                style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < rawText.length) {
      spans.add(TextSpan(
        text: rawText.substring(lastMatchEnd),
        style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.4),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}
