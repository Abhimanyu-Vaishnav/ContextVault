import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/template_parser.dart';
import 'models/snippet.dart';
import 'services/database_service.dart';
import 'services/revenue_cat_service.dart';
import 'views/paywall/paywall_sheet.dart';
import 'views/editor/snippet_editor_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();
  await RevenueCatService.init();
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
  final List<String> _categories = ['All', 'Work', 'Personal', 'Dev', 'Templates'];

  Future<void> _handleSnippetCopy(Snippet snippet) async {
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

    // Standard Android Intent / System Share fallback via Clipboard share notification
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF58A6FF), size: 22),
            SizedBox(width: 8),
            Text(
              'ContextVault',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
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
              // Search Input Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Instant search snippets...',
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

              // Category Filter Bar
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
      body: StreamBuilder<List<Snippet>>(
        stream: DatabaseService.watchSnippets(
          query: _searchQuery,
          category: _selectedCategory,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
            );
          }
          final snippets = snapshot.data!;
          if (snippets.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            itemCount: snippets.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              final snippet = snippets[index];
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
                child: _buildSnippetCard(snippet),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF238636),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          HapticFeedback.lightImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const SnippetEditorSheet(),
          );
        },
      ),
    );
  }

  Widget _buildSnippetCard(Snippet snippet) {
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
        onTap: () => _handleSnippetCopy(snippet),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SnippetEditorSheet(snippet: snippet),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header: Title + Pin Button + Use Count
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

              // Snippet Preview Body
              Text(
                snippet.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),

              // Action Toolbar: Share + Copy Buttons
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

  Widget _buildEmptyState() {
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
                  ? 'No results matching "$_searchQuery". Try a different search keyword.'
                  : 'You have no snippets in the "$_selectedCategory" category yet.',
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
              onPressed: () {
                HapticFeedback.lightImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const SnippetEditorSheet(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}