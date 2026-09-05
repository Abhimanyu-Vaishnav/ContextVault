import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Snippet? _activeSnippetForForm;
  Map<String, TextEditingController> _inputControllers = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSnippetsFromPrefs();
  }

  Future<void> _loadSnippetsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString('quick_dock_snippets');
      if (rawJson != null && rawJson.isNotEmpty) {
        final List list = jsonDecode(rawJson);
        if (mounted) {
          setState(() {
            _snippets = list.map((e) => Snippet.fromMap(e)).toList();
          });
        }
      } else {
        await DatabaseService.init();
        final loaded = await DatabaseService.getSnippets();
        if (mounted) {
          setState(() {
            _snippets = loaded.take(20).toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleExpanded() async {
    HapticFeedback.selectionClick();
    final nextState = !_isExpanded;
    if (nextState) {
      // Expand window to 320x440 and load latest snippets
      await FlutterOverlayWindow.resizeOverlay(320, 440, true);
      await _loadSnippetsFromPrefs();
      if (mounted) {
        setState(() {
          _isExpanded = true;
          _activeSnippetForForm = null;
        });
      }
    } else {
      // Collapse window back to 65x75 pill to restore phone touch interaction instantly
      await _collapseOverlay();
    }
  }

  Future<void> _collapseOverlay() async {
    setState(() {
      _isExpanded = false;
      _activeSnippetForForm = null;
    });
    await FlutterOverlayWindow.resizeOverlay(65, 75, true);
  }

  Future<void> _killOverlay() async {
    HapticFeedback.heavyImpact();
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _copySnippet(Snippet snippet) async {
    HapticFeedback.heavyImpact();
    final vars = TemplateParser.extractVariables(snippet.content);
    final listVars = TemplateParser.extractListVariables(snippet.content);

    if (vars.isNotEmpty || listVars.isNotEmpty) {
      // Show dynamic form in-tray
      setState(() {
        _activeSnippetForForm = snippet;
        _inputControllers = {for (var v in vars) v: TextEditingController()};
      });
      return;
    }

    final textToCopy = await TemplateParser.parseTemplate(snippet.content);
    await Clipboard.setData(ClipboardData(text: textToCopy));
    DatabaseService.markUsed(snippet);

    // Instant retract back to pill mode and unblock phone touches
    await _collapseOverlay();
  }

  Future<void> _submitFormAndCopy() async {
    if (_activeSnippetForForm == null) return;
    HapticFeedback.heavyImpact();

    final userInputs = {
      for (var entry in _inputControllers.entries) entry.key: entry.value.text
    };

    final textToCopy = await TemplateParser.parseTemplate(
      _activeSnippetForForm!.content,
      userInputs: userInputs,
    );

    await Clipboard.setData(ClipboardData(text: textToCopy));
    DatabaseService.markUsed(_activeSnippetForForm!);

    await _collapseOverlay();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return _buildCollapsedPill();
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Outside Dismiss Tap Detector (resizes overlay back to 60x90 pill instantly)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _collapseOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Expanded Drawer Container (320dp width x 480dp height)
          Positioned(
            top: 0,
            right: 0,
            child: _buildExpandedDrawer(),
          ),
        ],
      ),
    );
  }

  /// Collapsed Edge Handle Pill (50x60 pill)
  Widget _buildCollapsedPill() {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            width: 50,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xEE161B22),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF30363D)),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.bolt,
                color: Color(0xFF58A6FF),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded Drawer Container
  Widget _buildExpandedDrawer() {
    final filteredSnippets = _snippets.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      width: 320,
      height: 470,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF58A6FF), size: 18),
                const SizedBox(width: 6),
                const Text(
                  'ContextVault Quick',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Close button (X)
                GestureDetector(
                  onTap: _collapseOverlay,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, color: Color(0xFF8B949E), size: 18),
                  ),
                ),
                const SizedBox(width: 6),
                // Exit Dock button ('Turn Off')
                GestureDetector(
                  onTap: _killOverlay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDA3633).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.power_settings_new, color: Color(0xFFDA3633), size: 12),
                        SizedBox(width: 2),
                        Text(
                          'Turn Off',
                          style: TextStyle(
                            color: Color(0xFFDA3633),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_activeSnippetForForm != null)
            _buildInTrayFormView()
          else ...[
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: SizedBox(
                height: 38,
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

            // Optimized 60fps ListView.builder with itemExtent: 56.0
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
                      itemExtent: 56.0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemBuilder: (context, idx) {
                        final snippet = filteredSnippets[idx];
                        final hasVars = TemplateParser.extractVariables(snippet.content).isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    snippet.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasVars)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F6FEB).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Form',
                                      style: TextStyle(
                                        color: Color(0xFF58A6FF),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
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
        ],
      ),
    );
  }

  /// In-Tray Dynamic Form Builder for snippets containing {input:}
  Widget _buildInTrayFormView() {
    final snippet = _activeSnippetForForm!;
    final vars = _inputControllers.keys.toList();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF8B949E), size: 18),
                  onPressed: () => setState(() => _activeSnippetForForm = null),
                ),
                Expanded(
                  child: Text(
                    'Fill Form: ${snippet.title}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: vars.length,
                itemBuilder: (context, idx) {
                  final varName = vars[idx];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: _inputControllers[varName],
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: varName,
                        labelStyle: const TextStyle(color: Color(0xFF58A6FF), fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF161B22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF30363D)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _submitFormAndCopy,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Copy Rendered Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
