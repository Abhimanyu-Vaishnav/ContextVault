import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../models/snippet.dart';
import '../../services/database_service.dart';
import '../../core/utils/template_parser.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuickDockOverlayApp());
}

class QuickDockOverlayApp extends StatelessWidget {
  const QuickDockOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const QuickDockOverlayWidget(),
    );
  }
}

class QuickDockOverlayWidget extends StatefulWidget {
  const QuickDockOverlayWidget({super.key});

  @override
  State<QuickDockOverlayWidget> createState() => _QuickDockOverlayWidgetState();
}

class _QuickDockOverlayWidgetState extends State<QuickDockOverlayWidget> {
  bool _isExpanded = false;
  String _searchQuery = '';
  List<Snippet> _snippets = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSnippets();
  }

  Future<void> _loadSnippets() async {
    try {
      await DatabaseService.init();
      final loaded = await DatabaseService.getSnippets();
      if (mounted) {
        setState(() {
          _snippets = loaded;
        });
      }
    } catch (_) {}
  }

  void _toggleExpanded() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      await FlutterOverlayWindow.resizeOverlay(320, 440, false);
      _loadSnippets();
    } else {
      await FlutterOverlayWindow.resizeOverlay(140, 180, true);
    }
  }

  Future<void> _copySnippet(Snippet snippet) async {
    HapticFeedback.lightImpact();
    final vars = TemplateParser.extractVariables(snippet.content);
    final listVars = TemplateParser.extractListVariables(snippet.content);

    String textToCopy = snippet.content;
    if (vars.isEmpty && listVars.isEmpty) {
      textToCopy = await TemplateParser.parseTemplate(snippet.content);
    }

    await Clipboard.setData(ClipboardData(text: textToCopy));
    await DatabaseService.markUsed(snippet);

    // Auto collapse overlay back into edge pill after copy
    setState(() {
      _isExpanded = false;
    });
    await FlutterOverlayWindow.resizeOverlay(140, 180, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return _buildCollapsedPill();
    }
    return _buildExpandedDockCard();
  }

  /// Collapsed Edge Bubble Pill View
  Widget _buildCollapsedPill() {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 44,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117).withValues(alpha: 0.9),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
              border: Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF58A6FF).withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, color: Color(0xFF58A6FF), size: 22),
                SizedBox(height: 4),
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'DOCK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded Quick-Dock Overlay Card View
  Widget _buildExpandedDockCard() {
    final filteredSnippets = _snippets.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).take(8).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF30363D), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF161B22),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF58A6FF), size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Quick-Dock Vault',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleExpanded,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close, color: Color(0xFF8B949E), size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search snippets...',
                    hintStyle: const TextStyle(color: Color(0xFF484F58), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF8B949E), size: 16),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF30363D)),
                    ),
                  ),
                ),
              ),
            ),

            // Snippets Quick-List
            Expanded(
              child: filteredSnippets.isEmpty
                  ? const Center(
                      child: Text(
                        'No snippets found',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredSnippets.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, idx) {
                        final snippet = filteredSnippets[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            title: Text(
                              snippet.title,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              snippet.content,
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.content_copy, color: Color(0xFF58A6FF), size: 16),
                              onPressed: () => _copySnippet(snippet),
                            ),
                            onTap: () => _copySnippet(snippet),
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
