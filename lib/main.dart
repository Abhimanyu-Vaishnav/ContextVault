import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/template_parser.dart';
import 'models/snippet.dart';
import 'services/database_service.dart';
import 'services/revenue_cat_service.dart';
import 'services/quick_access_service.dart';
import 'views/paywall/paywall_sheet.dart';
import 'views/editor/snippet_editor_sheet.dart';
import 'views/guide/vault_guide_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Resilient DatabaseService Init
  try {
    await DatabaseService.init();
    debugPrint("[Main] DatabaseService initialized.");
  } catch (e, stack) {
    debugPrint("[Main] DatabaseService init failed: $e\n$stack");
  }

  // 2. Resilient RevenueCatService Init
  try {
    await RevenueCatService.init();
    debugPrint("[Main] RevenueCatService initialized.");
  } catch (e, stack) {
    debugPrint("[Main] RevenueCatService init failed: $e\n$stack");
  }

  // 3. Resilient QuickAccessService Init
  try {
    await QuickAccessService.startQuickAccessNotification();
    debugPrint("[Main] QuickAccessService started.");
  } catch (e, stack) {
    debugPrint("[Main] QuickAccessService start failed: $e\n$stack");
  }

  // Guarantee UI render regardless of background service state
  runApp(const ContextVaultApp());
}

class ContextVaultApp extends StatelessWidget {
  const ContextVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ContextVault',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  Snippet? _selectedSnippet;
  final List<String> _categories = ['All', 'Work', 'Personal', 'Dev', 'Templates'];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleNewSnippet(bool isLargeScreen) {
    HapticFeedback.lightImpact();
    if (isLargeScreen) {
      setState(() => _selectedSnippet = Snippet());
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const SnippetEditorSheet(),
      );
    }
  }

  Future<void> _handleSnippetCopy(Snippet snippet) async {
    HapticFeedback.lightImpact();
    final vars = TemplateParser.extractVariables(snippet.content);
    Map<String, String> userInputs = {};

    if (vars.isNotEmpty) {
      final isPro = await RevenueCatService.isProUser();
      if (!isPro && mounted) {
        final unlocked = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const PaywallSheet(),
        );
        if (unlocked != true) return;
      }

      final inputs = await _showVariableInputDialog(vars);
      if (inputs == null) return;
      userInputs = inputs;
    }

    final parsedText = await TemplateParser.parseTemplate(
      snippet.content,
      userInputs: userInputs,
    );

    await Clipboard.setData(ClipboardData(text: parsedText));
    await DatabaseService.markUsed(snippet);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied: "${snippet.title}" to clipboard!'),
          backgroundColor: const Color(0xFF238636),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleShareSnippet(Snippet snippet) async {
    HapticFeedback.lightImpact();
    final vars = TemplateParser.extractVariables(snippet.content);
    Map<String, String> userInputs = {};

    if (vars.isNotEmpty) {
      final inputs = await _showVariableInputDialog(vars);
      if (inputs == null) return;
      userInputs = inputs;
    }

    final parsedText = await TemplateParser.parseTemplate(
      snippet.content,
      userInputs: userInputs,
    );

    await Clipboard.setData(ClipboardData(text: parsedText));
    await DatabaseService.markUsed(snippet);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied & Ready to Share anywhere!'),
          backgroundColor: Color(0xFF1F6FEB),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<Map<String, String>?> _showVariableInputDialog(List<String> vars) async {
    final controllers = {for (var v in vars) v: TextEditingController()};
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Color(0xFF58A6FF), size: 20),
            SizedBox(width: 8),
            Text(
              'Fill Dynamic Variables',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: vars.map((v) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: TextField(
                controller: controllers[v],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: v,
                  labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final result = {for (var v in vars) v: controllers[v]!.text};
              Navigator.pop(ctx, result);
            },
            child: const Text('Inject & Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = mediaWidth >= 600;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const FocusSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const CreateSnippetIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const ClearSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (FocusSearchIntent intent) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          CreateSnippetIntent: CallbackAction<CreateSnippetIntent>(
            onInvoke: (CreateSnippetIntent intent) {
              _handleNewSnippet(isLargeScreen);
              return null;
            },
          ),
          ClearSearchIntent: CallbackAction<ClearSearchIntent>(
            onInvoke: (ClearSearchIntent intent) {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
              _searchFocusNode.unfocus();
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161B22),
            elevation: 0,
            title: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF58A6FF), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'ContextVault',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                if (isLargeScreen) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: const Text(
                      'DeX Mode Supported (Ctrl+F, Ctrl+N, Esc)',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline, color: Color(0xFF8B949E)),
                tooltip: 'Vault Guide & Syntax',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VaultGuideScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.bolt, color: Color(0xFF58A6FF)),
                tooltip: 'Unlock Pro',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const PaywallSheet(),
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(105),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Instant search snippets (Ctrl+F)...',
                        hintStyle: const TextStyle(color: Color(0xFF484F58)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF8B949E), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
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
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedCategory = cat);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1F6FEB) : const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF8B949E),
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          body: isLargeScreen ? _buildDualPaneLayout() : _buildSinglePaneLayout(),
          floatingActionButton: isLargeScreen
              ? null
              : FloatingActionButton(
                  backgroundColor: const Color(0xFF238636),
                  elevation: 4,
                  child: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _handleNewSnippet(false),
                ),
        ),
      ),
    );
  }

  Widget _buildSinglePaneLayout() {
    return StreamBuilder<List<Snippet>>(
      stream: DatabaseService.watchSnippets(
        query: _searchQuery,
        category: _selectedCategory,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)));
        }
        final snippets = snapshot.data!;
        if (snippets.isEmpty) {
          return _buildEmptyState(false);
        }
        return ListView.builder(
          itemCount: snippets.length,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemBuilder: (context, index) {
            final snippet = snippets[index];
            return _buildDismissibleSnippetCard(snippet, false);
          },
        );
      },
    );
  }

  Widget _buildDualPaneLayout() {
    return Row(
      children: [
        // Left Pane (40% Width) - Snippet Master List
        Expanded(
          flex: 4,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Snippet (Ctrl+N)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _handleNewSnippet(true),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Snippet>>(
                    stream: DatabaseService.watchSnippets(
                      query: _searchQuery,
                      category: _selectedCategory,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)));
                      }
                      final snippets = snapshot.data!;
                      if (snippets.isEmpty) {
                        return _buildEmptyState(true);
                      }
                      return ListView.builder(
                        itemCount: snippets.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemBuilder: (context, index) {
                          final snippet = snippets[index];
                          final isSelected = _selectedSnippet?.id == snippet.id;
                          return Container(
                            decoration: isSelected
                                ? BoxDecoration(
                                    color: const Color(0xFF1F6FEB).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF58A6FF)),
                                  )
                                : null,
                            child: _buildDismissibleSnippetCard(snippet, true),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Pane (60% Width) - Detail Playground & Editor
        Expanded(
          flex: 6,
          child: Container(
            color: const Color(0xFF0D1117),
            padding: const EdgeInsets.all(20),
            child: _selectedSnippet == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 48, color: Color(0xFF484F58)),
                        SizedBox(height: 12),
                        Text(
                          'Select a snippet on the left to view or edit',
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : SnippetEditorSheet(snippet: _selectedSnippet),
          ),
        ),
      ],
    );
  }

  Widget _buildDismissibleSnippetCard(Snippet snippet, bool isLargeScreen) {
    return Dismissible(
      key: Key(snippet.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        if (!context.mounted) return false;
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            title: const Text('Delete Snippet?', style: TextStyle(color: Colors.white)),
            content: Text(
              'Are you sure you want to delete "${snippet.title}"?',
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
        return shouldDelete ?? false;
      },
      onDismissed: (direction) async {
        if (snippet.id != null) {
          final messenger = ScaffoldMessenger.of(context);
          await DatabaseService.deleteSnippet(snippet.id!);
          if (isLargeScreen && _selectedSnippet?.id == snippet.id) {
            setState(() => _selectedSnippet = null);
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text('Deleted "${snippet.title}"'),
              backgroundColor: const Color(0xFFDA3633),
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDA3633).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDA3633).withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete', style: TextStyle(color: Color(0xFFF85149), fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Color(0xFFF85149)),
          ],
        ),
      ),
      child: _buildSnippetCard(snippet, isLargeScreen),
    );
  }

  Widget _buildSnippetCard(Snippet snippet, bool isLargeScreen) {
    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isLargeScreen) {
            setState(() => _selectedSnippet = snippet);
          } else {
            _handleSnippetCopy(snippet);
          }
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (isLargeScreen) {
            setState(() => _selectedSnippet = snippet);
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => SnippetEditorSheet(snippet: snippet),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      snippet.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                    ),
                    color: snippet.isPinned ? const Color(0xFFD29922) : const Color(0xFF484F58),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await DatabaseService.togglePin(snippet);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      snippet.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Text(
                      'Used ${snippet.useCount}x',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                snippet.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B949E),
                      side: const BorderSide(color: Color(0xFF30363D)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 14),
                    label: const Text('Share', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleShareSnippet(snippet),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F6FEB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleSnippetCopy(snippet),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLargeScreen) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                size: 48,
                color: Color(0xFF58A6FF),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Snippets Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results matching "$_searchQuery".'
                  : 'No snippets in category "$_selectedCategory".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Create New Snippet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _handleNewSnippet(isLargeScreen),
            ),
          ],
        ),
      ),
    );
  }
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class CreateSnippetIntent extends Intent {
  const CreateSnippetIntent();
}

class ClearSearchIntent extends Intent {
  const ClearSearchIntent();
}