import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/data/template_vault_data.dart';
import '../../models/snippet.dart';
import '../../services/database_service.dart';
import '../../services/revenue_cat_service.dart';
import '../paywall/paywall_sheet.dart';

class TemplateLibrarySheet extends StatefulWidget {
  final Function(VaultTemplate)? onSelectTemplate;

  const TemplateLibrarySheet({super.key, this.onSelectTemplate});

  @override
  State<TemplateLibrarySheet> createState() => _TemplateLibrarySheetState();
}

class _TemplateLibrarySheetState extends State<TemplateLibrarySheet> {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Dev',
    'Growth',
    'Sales',
    'Support',
    'Founder',
    'Education',
  ];
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
  }

  Future<void> _checkProStatus() async {
    final pro = await RevenueCatService.isProUser();
    if (mounted) setState(() => _isPro = pro);
  }

  Future<void> _handleTemplateTap(VaultTemplate template) async {
    HapticFeedback.lightImpact();

    if (template.isPro && !_isPro) {
      final unlocked = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const PaywallSheet(),
      );
      if (unlocked == true) {
        _checkProStatus();
      }
      return;
    }

    if (widget.onSelectTemplate != null) {
      widget.onSelectTemplate!(template);
      Navigator.pop(context);
    } else {
      // Save directly to user vault
      final snippet = Snippet(
        title: template.title,
        content: template.content,
        category: template.category,
      );
      await DatabaseService.saveSnippet(snippet);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${template.title}" to your Vault!'),
            backgroundColor: const Color(0xFF238636),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = TemplateVaultData.getAllTemplates();
    final filtered = _selectedCategory == 'All'
        ? all
        : all.where((t) => t.category == _selectedCategory).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Handle
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
          const SizedBox(height: 14),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.library_books, color: Color(0xFF58A6FF), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Template Vault (160+)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          // Profession Starter Packs Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStarterPackChip(
                  context,
                  '💻 Developer Superpack',
                  'Dev',
                  const Color(0xFF1F6FEB),
                ),
                _buildStarterPackChip(
                  context,
                  '💼 Freelancer & Agency',
                  'Sales',
                  const Color(0xFF238636),
                ),
                _buildStarterPackChip(
                  context,
                  '🚀 Product & Support',
                  'Support',
                  const Color(0xFFD29922),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : const Color(0xFF8B949E),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1F6FEB),
                    backgroundColor: const Color(0xFF161B22),
                    side: const BorderSide(color: Color(0xFF30363D)),
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Templates List View
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, index) {
                final item = filtered[index];
                final isLocked = item.isPro && !_isPro;

                return Card(
                  color: const Color(0xFF161B22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row Title & Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.isPro
                                    ? const Color(0xFF1F6FEB).withValues(alpha: 0.15)
                                    : const Color(0xFF238636).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: item.isPro
                                      ? const Color(0xFF58A6FF).withValues(alpha: 0.4)
                                      : const Color(0xFF3FB950).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.isPro) ...[
                                    const Icon(
                                      Icons.bolt,
                                      size: 12,
                                      color: Color(0xFF58A6FF),
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  Text(
                                    item.isPro ? 'PRO TEMPLATE' : 'FREE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item.isPro
                                          ? const Color(0xFF58A6FF)
                                          : const Color(0xFF3FB950),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B949E),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Action Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLocked
                                  ? const Color(0xFF21262D)
                                  : const Color(0xFF238636),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: isLocked
                                    ? const BorderSide(color: Color(0xFF58A6FF))
                                    : BorderSide.none,
                              ),
                            ),
                            icon: Icon(
                              isLocked ? Icons.lock : Icons.add_circle_outline,
                              size: 14,
                              color: isLocked
                                  ? const Color(0xFF58A6FF)
                                  : Colors.white,
                            ),
                            label: Text(
                              isLocked ? 'Unlock Pro Template' : 'Use Template',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isLocked
                                    ? const Color(0xFF58A6FF)
                                    : Colors.white,
                              ),
                            ),
                            onPressed: () => _handleTemplateTap(item),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarterPackChip(
    BuildContext context,
    String label,
    String categoryFilter,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: Icon(Icons.flash_on, size: 14, color: accentColor),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
        onPressed: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedCategory = categoryFilter;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded $label into explorer!'),
              backgroundColor: accentColor,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
