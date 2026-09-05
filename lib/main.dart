import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/template_parser.dart';
import 'models/snippet.dart';
import 'services/database_service.dart';
import 'services/revenue_cat_service.dart';
import 'services/quick_access_service.dart';
import 'services/backup_service.dart';
import 'services/auth_service.dart';
import 'views/paywall/paywall_sheet.dart';
import 'views/editor/snippet_editor_sheet.dart';
import 'views/guide/vault_guide_screen.dart';
import 'views/templates/template_library_sheet.dart';
import 'views/auth/biometric_lock_screen.dart';
import 'views/settings/settings_sheet.dart';
import 'services/overlay_service.dart';
import 'views/paywall/quick_dock_overlay.dart';
import 'views/quick/quick_search_dialog.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuickDockOverlayApp());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Resilient DatabaseService Init
  try {
    await DatabaseService.init();
    await BackupService.seedStarterKit();
    debugPrint("[Main] DatabaseService & Starter Kit initialized.");
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

  // Guarantee UI render regardless of background service state
  runApp(const ContextVaultApp());
}

class ContextVaultApp extends StatefulWidget {
  const ContextVaultApp({super.key});

  @override
  State<ContextVaultApp> createState() => _ContextVaultAppState();
}

class _ContextVaultAppState extends State<ContextVaultApp> with WidgetsBindingObserver {
  bool _isLocked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RevenueCatService.proStatusNotifier.addListener(_onProStatusChanged);
    RevenueCatService.addCustomerInfoListener((customerInfo) {
      if (mounted) {
        setState(() {}); // Re-render UI dynamically across the entire app
      }
    });
  }

  void _onProStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    RevenueCatService.proStatusNotifier.removeListener(_onProStatusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Check if user turned Biometrics ON in Settings
      final bioEnabled = await AuthService.isBiometricEnabled();
      if (!bioEnabled) return;

      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        // Grace period of 2 minutes (120 seconds)
        if (elapsed.inSeconds >= 120) {
          if (!_isLocked) {
            setState(() => _isLocked = true);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ContextVault',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => _isLocked
            ? BiometricLockScreen(
                onUnlocked: () => setState(() => _isLocked = false),
              )
            : const HomeScreen(),
        'quick_bubble_dialog': (context) => const QuickBubbleDialogScaffold(),
      },
    );
  }
}

class QuickBubbleDialogScaffold extends StatelessWidget {
  const QuickBubbleDialogScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => SystemNavigator.pop(),
        child: const Center(
          child: QuickSearchDialogContent(),
        ),
      ),
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if launched via Quick Settings Tile or Quick Action
      const MethodChannel('com.contextvault.app/quick_access').invokeMethod('getLaunchIntentAction').then((action) {
        if ((action == 'quick_access' || action == 'ACTION_QUICK_SEARCH' || action == 'quick_bubble_dialog') && mounted) {
          QuickSearchDialog.show(context);
        }
      }).catchError((_) {});
    });
  }

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
    final listVars = TemplateParser.extractListVariables(snippet.content);
    Map<String, String> userInputs = {};
    Map<String, List<String>> userLists = {};

    if (vars.isNotEmpty || listVars.isNotEmpty) {
      final res = await _showVariableInputDialog(snippet, vars, listVars);
      if (res == null) return;
      userInputs = res.inputs;
      userLists = res.lists;
    }

    final parsedText = await TemplateParser.parseTemplate(
      snippet.content,
      userInputs: userInputs,
      userLists: userLists,
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
    final listVars = TemplateParser.extractListVariables(snippet.content);
    Map<String, String> userInputs = {};
    Map<String, List<String>> userLists = {};

    if (vars.isNotEmpty || listVars.isNotEmpty) {
      final res = await _showVariableInputDialog(snippet, vars, listVars);
      if (res == null) return;
      userInputs = res.inputs;
      userLists = res.lists;
    }

    final parsedText = await TemplateParser.parseTemplate(
      snippet.content,
      userInputs: userInputs,
      userLists: userLists,
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

  Future<({Map<String, String> inputs, Map<String, List<String>> lists})?>
      _showVariableInputDialog(
    Snippet snippet,
    List<String> vars,
    List<String> listVars,
  ) async {
    final inputControllers = {for (var v in vars) v: TextEditingController()};
    final listControllers = {
      for (var lv in listVars) lv: [TextEditingController()]
    };
    String livePreview = snippet.content;

    Future<String> renderPreview(
      Map<String, String> currentInputs,
      Map<String, List<String>> currentLists,
    ) async {
      return await TemplateParser.parseTemplate(
        snippet.content,
        userInputs: currentInputs,
        userLists: currentLists,
      );
    }

    return showDialog<
        ({Map<String, String> inputs, Map<String, List<String>> lists})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void updatePreview() async {
              final currentInputs = {
                for (var v in vars) v: inputControllers[v]!.text
              };
              final currentLists = {
                for (var lv in listVars)
                  lv: listControllers[lv]!.map((c) => c.text).toList()
              };
              final rendered = await renderPreview(currentInputs, currentLists);
              if (ctx.mounted) {
                setModalState(() {
                  livePreview = rendered;
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF161B22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF30363D)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF58A6FF), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fill Template: ${snippet.title}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Standard Input Fields
                      ...vars.map((v) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: TextField(
                            controller: inputControllers[v],
                            style: const TextStyle(color: Colors.white),
                            onChanged: (_) => updatePreview(),
                            decoration: InputDecoration(
                              labelText: v,
                              labelStyle:
                                  const TextStyle(color: Color(0xFF8B949E)),
                              filled: true,
                              fillColor: const Color(0xFF0D1117),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF30363D)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF58A6FF)),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Dynamic Repeating List Sections
                      ...listVars.map((lv) {
                        final ctrlList = listControllers[lv]!;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.format_list_numbered,
                                      size: 16, color: Color(0xFF58A6FF)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dynamic List: $lv',
                                    style: const TextStyle(
                                      color: Color(0xFF58A6FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...ctrlList.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final ctrl = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: ctrl,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (_) => updatePreview(),
                                          decoration: InputDecoration(
                                            hintText: 'Step ${idx + 1}...',
                                            hintStyle: const TextStyle(
                                                color: Color(0xFF484F58)),
                                            filled: true,
                                            fillColor: const Color(0xFF161B22),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFF30363D)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFF58A6FF)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (ctrlList.length > 1)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Color(0xFFDA3633),
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            setModalState(() {
                                              ctrl.dispose();
                                              ctrlList.removeAt(idx);
                                            });
                                            updatePreview();
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF58A6FF),
                                  side: const BorderSide(
                                      color: Color(0xFF58A6FF)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text(
                                  '+ Add Step',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setModalState(() {
                                    ctrlList.add(TextEditingController());
                                  });
                                  updatePreview();
                                },
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      const Text(
                        'LIVE RENDERED OUTPUT',
                        style: TextStyle(
                          color: Color(0xFF58A6FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: Text(
                          livePreview,
                          style: const TextStyle(
                              color: Color(0xFFC9D1D9),
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF8B949E))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final inputsResult = {
                      for (var v in vars) v: inputControllers[v]!.text
                    };
                    final listsResult = {
                      for (var lv in listVars)
                        lv: listControllers[lv]!.map((c) => c.text).toList()
                    };
                    Navigator.pop(ctx,
                        (inputs: inputsResult, lists: listsResult));
                  },
                  child: const Text(
                    'Copy Rendered Context',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showBackupDialog(BuildContext context) async {
    HapticFeedback.lightImpact();
    final jsonString = await BackupService.exportSnippetsJson();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Row(
          children: [
            Icon(Icons.import_export, color: Color(0xFF58A6FF), size: 20),
            SizedBox(width: 8),
            Text(
              'Backup & Portability',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export database snippets to JSON or restore from a backup file.',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F6FEB),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Export JSON to Clipboard (Free)'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: jsonString));
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All snippets exported to clipboard as JSON!'),
                        backgroundColor: Color(0xFF238636),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD29922),
                  side: const BorderSide(color: Color(0xFFD29922)),
                ),
                icon: const Icon(Icons.lock_outline, size: 16),
                label: const Text('Restore from JSON (Pro Feature)'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final isPro = await RevenueCatService.isProUser();
                  if (!isPro && context.mounted) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const PaywallSheet(),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pro unlocked! Paste JSON in snippet editor to restore.'),
                        backgroundColor: Color(0xFF238636),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
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
                const Flexible(
                  child: Text(
                    'ContextVault',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
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
                icon: const Icon(Icons.library_books, color: Color(0xFF58A6FF)),
                tooltip: 'Browse 150+ Templates',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const TemplateLibrarySheet(),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.import_export, color: Color(0xFF8B949E)),
                tooltip: 'Backup & Restore JSON',
                onPressed: () => _showBackupDialog(context),
              ),
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
                icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Color(0xFF58A6FF)),
                tooltip: 'Toggle Edge Quick-Dock',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  OverlayService.toggleOverlay(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Color(0xFF8B949E)),
                tooltip: 'Vault Settings',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SettingsSheet(),
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
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 250 + (index * 40).clamp(0, 300)),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1.0 - value) * 16),
                    child: child,
                  ),
                );
              },
              child: _buildDismissibleSnippetCard(snippet, false),
            );
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
        side: BorderSide(
          color: snippet.isPinned ? const Color(0xFFD29922).withValues(alpha: 0.5) : const Color(0xFF30363D),
          width: snippet.isPinned ? 1.2 : 1.0,
        ),
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
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF8B949E)),
                    color: const Color(0xFF161B22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF30363D)),
                    ),
                    onSelected: (value) async {
                      HapticFeedback.lightImpact();
                      if (value == 'edit') {
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
                      } else if (value == 'pin') {
                        await DatabaseService.togglePin(snippet);
                      } else if (value == 'duplicate') {
                        final messenger = ScaffoldMessenger.of(context);
                        final copySnippet = Snippet(
                          title: 'Copy of ${snippet.title}',
                          content: snippet.content,
                          category: snippet.category,
                          isPinned: false,
                        );
                        await DatabaseService.saveSnippet(copySnippet);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Duplicated "${snippet.title}"'),
                            backgroundColor: const Color(0xFF238636),
                          ),
                        );
                      } else if (value == 'delete') {
                        if (snippet.id != null) {
                          if (!context.mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
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
                          if (confirm == true) {
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
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16, color: Color(0xFF58A6FF)),
                            SizedBox(width: 8),
                            Text('Edit Snippet', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(
                              snippet.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                              size: 16,
                              color: const Color(0xFFD29922),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              snippet.isPinned ? 'Unpin' : 'Pin to Top',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy_all, size: 16, color: Color(0xFF3FB950)),
                            SizedBox(width: 8),
                            Text('Duplicate', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: Color(0xFFF85149)),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Color(0xFFF85149), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
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