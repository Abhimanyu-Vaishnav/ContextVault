import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../editor/snippet_editor_sheet.dart';

class VaultGuideScreen extends StatelessWidget {
  const VaultGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF58A6FF), size: 20),
            SizedBox(width: 8),
            Text(
              'Vault Guide & Syntax',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1F6FEB).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 14, color: Color(0xFF58A6FF)),
                  SizedBox(width: 6),
                  Text(
                    'ContextVault Architecture Guide',
                    style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // SECTION 1: The Problem & The Fix
          _buildSectionHeader(Icons.speed, '1. The Problem & The Fix'),
          const SizedBox(height: 12),
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stop Re-typing Repetitive Text',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Professionals waste an average of 45 minutes daily re-typing meeting links, boilerplate bug report templates, support responses, and dynamic emails.',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBadge('Repetitive Typing', '45m / day', const Color(0xFFDA3633)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricBadge('With ContextVault', '1-Tap Copy', const Color(0xFF238636)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // SECTION 2: Dynamic Variable Syntax Cheat-Sheet
          _buildSectionHeader(Icons.code, '2. Dynamic Variable Syntax Cheat-Sheet'),
          const SizedBox(height: 12),
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automate Placeholders on the Fly',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Embed these smart tokens anywhere in your snippet content:',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildSyntaxRow(
                  token: '{date}',
                  description: 'Auto-injects current date (YYYY-MM-DD)',
                  isPro: false,
                ),
                const Divider(color: Color(0xFF21262D), height: 16),
                _buildSyntaxRow(
                  token: '{time}',
                  description: 'Auto-injects current time (HH:mm)',
                  isPro: false,
                ),
                const Divider(color: Color(0xFF21262D), height: 16),
                _buildSyntaxRow(
                  token: '{clipboard}',
                  description: 'Auto-pastes active device clipboard text',
                  isPro: false,
                ),
                const Divider(color: Color(0xFF21262D), height: 16),
                _buildSyntaxRow(
                  token: '{input:variable}',
                  description: 'Opens interactive input dialog when copying',
                  isPro: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF58A6FF),
                      side: const BorderSide(color: Color(0xFF30363D)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Try Live in Editor', style: TextStyle(fontWeight: FontWeight.bold)),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // SECTION 3: Privacy & Offline Promise
          _buildSectionHeader(Icons.security, '3. Privacy & Offline Promise'),
          const SizedBox(height: 12),
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield, color: Color(0xFF3FB950), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Zero Data Collection Guarantee',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'ContextVault stores all your snippets, tokens, and database files 100% locally on your physical device using SQLite. We do NOT operate remote servers, tracking SDKs, or cloud sync backends.',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF3FB950), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Encrypted Local SQLite • Zero Telemetry',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF58A6FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: child,
    );
  }

  Widget _buildMetricBadge(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSyntaxRow({required String token, required String description, required bool isPro}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Text(
            token,
            style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 12, height: 1.3),
              ),
              if (isPro) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD29922).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PRO FEATURE',
                    style: TextStyle(color: Color(0xFFD29922), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
