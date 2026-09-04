import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/revenue_cat_service.dart';
import '../../services/database_service.dart';
import '../paywall/paywall_sheet.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _isBiometricsEnabled = false;
  String _appUserId = 'Loading...';
  int _snippetCount = 0;
  bool _isPro = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }

  Future<void> _loadSettingsData() async {
    final bioEnabled = await AuthService.isBiometricEnabled();
    final userId = await RevenueCatService.getAppUserID();
    final isProUser = await RevenueCatService.isProUser();
    final snippets = await DatabaseService.getSnippets();

    if (mounted) {
      setState(() {
        _isBiometricsEnabled = bioEnabled;
        _appUserId = userId;
        _isPro = isProUser;
        _snippetCount = snippets.length;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool newValue) async {
    // Requires local auth confirmation before changing setting
    final authenticated = await AuthService.authenticateUser(
      reason: newValue
          ? 'Authenticate to enable Biometric Vault Lock'
          : 'Authenticate to disable Biometric Vault Lock',
    );

    if (authenticated) {
      await AuthService.setBiometricEnabled(newValue);
      setState(() {
        _isBiometricsEnabled = newValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? '🔒 Biometric Vault Lock enabled'
                  : '🔓 Biometric Vault Lock disabled',
            ),
            backgroundColor: const Color(0xFF238636),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Setting unchanged.'),
            backgroundColor: Color(0xFFDA3633),
          ),
        );
      }
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() => _isLoading = true);
    await RevenueCatService.restorePurchases();
    final isProUser = await RevenueCatService.isProUser();

    if (mounted) {
      setState(() {
        _isPro = isProUser;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isProUser
                ? '🎉 Purchases restored! ContextVault Pro active.'
                : 'No active subscription found to restore.',
          ),
          backgroundColor:
              isProUser ? const Color(0xFF238636) : const Color(0xFFD29922),
        ),
      );
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Grabber Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF484F58),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFF58A6FF)),
                const SizedBox(width: 10),
                const Text(
                  'Vault Settings & Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
                ),
              )
            else
              Column(
                children: [
                  // 1. Biometric Lock Section
                  _buildSectionHeader('SECURITY'),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: SwitchListTile(
                      activeThumbColor: const Color(0xFF58A6FF),
                      title: const Text(
                        'Biometric App Lock',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Require fingerprint/PIN after 2 mins in background',
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.fingerprint,
                        color: Color(0xFF58A6FF),
                      ),
                      value: _isBiometricsEnabled,
                      onChanged: _toggleBiometrics,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Storage Stats Section
                  _buildSectionHeader('STORAGE STATS'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.storage,
                              color: Color(0xFF3FB950),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Snippet Usage',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _isPro
                                      ? 'Unlimited Storage (Pro Tier)'
                                      : 'Free Tier Cap (15 Max)',
                                  style: const TextStyle(
                                    color: Color(0xFF8B949E),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isPro
                                ? const Color(0xFF1F6FEB).withValues(alpha: 0.2)
                                : const Color(0xFF21262D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isPro
                                  ? const Color(0xFF58A6FF)
                                  : const Color(0xFF30363D),
                            ),
                          ),
                          child: Text(
                            _isPro
                                ? '$_snippetCount Snippets'
                                : '$_snippetCount / 15',
                            style: TextStyle(
                              color: _isPro
                                  ? const Color(0xFF58A6FF)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Account Section
                  _buildSectionHeader('ACCOUNT & REVENUECAT'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              color: Color(0xFFD29922),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'App User ID:',
                              style: TextStyle(
                                color: Color(0xFF8B949E),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                _appUserId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                size: 16,
                                color: Color(0xFF58A6FF),
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _appUserId),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('App User ID copied!'),
                                    backgroundColor: Color(0xFF238636),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF21262D), height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isPro ? 'Status: ContextVault PRO' : 'Status: Free Tier',
                              style: TextStyle(
                                color: _isPro
                                    ? const Color(0xFF3FB950)
                                    : const Color(0xFF8B949E),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF21262D),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: Color(0xFF30363D),
                                  ),
                                ),
                              ),
                              onPressed: () async {
                                if (!_isPro) {
                                  final unlocked =
                                      await showModalBottomSheet<bool>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => const PaywallSheet(),
                                  );
                                  if (unlocked == true) {
                                    _loadSettingsData();
                                  }
                                } else {
                                  _handleRestorePurchases();
                                }
                              },
                              icon: Icon(
                                _isPro ? Icons.restore : Icons.bolt,
                                size: 16,
                                color: const Color(0xFF58A6FF),
                              ),
                              label: Text(_isPro ? 'Restore' : 'Upgrade'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8B949E),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
