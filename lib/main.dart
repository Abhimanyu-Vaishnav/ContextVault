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

  Future<void> _handleSnippetCopy(Snippet snippet) async {
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

  Future<Map<String, String>?> _showVariableInputDialog(List<String> vars) async {
    final controllers = {for (var v in vars) v: TextEditingController()};
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Fill Dynamic Variables'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: vars.map((v) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: TextField(
                controller: controllers[v],
                decoration: InputDecoration(labelText: v),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
      appBar: AppBar(
        title: const Text('ContextVault', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: Color(0xFF58A6FF)),
            tooltip: 'Unlock Pro',
            onPressed: () {
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
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Instant search snippets...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Snippet>>(
        stream: DatabaseService.watchSnippets(query: _searchQuery),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final snippets = snapshot.data!;
          if (snippets.isEmpty) {
            return const Center(
              child: Text('No snippets found. Tap + to create one!', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            itemCount: snippets.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final s = snippets[index];
              return Card(
                color: const Color(0xFF161B22),
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFF30363D)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Row(
                    children: [
                      if (s.isPinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.push_pin, size: 16, color: Colors.amber),
                        ),
                      Expanded(
                        child: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        'Used ${s.useCount}x',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      s.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF58A6FF)),
                    onPressed: () => _handleSnippetCopy(s),
                  ),
                  onTap: () => _handleSnippetCopy(s),
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF0D1117),
                      builder: (_) => SnippetEditorSheet(snippet: s),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF238636),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFF0D1117),
            builder: (_) => const SnippetEditorSheet(),
          );
        },
      ),
    );
  }
}