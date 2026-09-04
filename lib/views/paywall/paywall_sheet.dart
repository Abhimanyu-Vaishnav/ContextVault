import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/revenue_cat_service.dart';
import '../../../services/coupon_service.dart';
import '../../../services/database_service.dart';

enum BillingPlan { annual, monthly }

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key});

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  bool _isLoading = true;
  bool _isProUser = false;
  CustomerInfo? _customerInfo;

  // Usage & analytics stats for Pro Hub
  int _snippetCount = 0;
  int _totalUsageCount = 0;
  double _hoursSaved = 0.0;

  BillingPlan _selectedPlan = BillingPlan.annual;
  List<Package> _packages = [];

  String _annualPriceText = "₹1,999 / yr";
  String _monthlyPriceText = "₹299 / mo";
  String _annualSubText = "₹166 / mo — Save 45%";
  int _savingsPercentage = 45;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateFallbackPricing();
  }

  void _updateFallbackPricing() {
    final locale = View.of(context).platformDispatcher.locale;
    final isUS = locale.countryCode == 'US';

    if (isUS) {
      _annualPriceText = "\$24.99 / yr";
      _monthlyPriceText = "\$3.99 / mo";
      _annualSubText = "\$2.08 / mo";
      _savingsPercentage = 48;
    } else {
      _annualPriceText = "₹1,999 / yr";
      _monthlyPriceText = "₹299 / mo";
      _annualSubText = "₹166 / mo — Save 45%";
      _savingsPercentage = 45;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStateData();
  }

  Future<void> _loadStateData() async {
    setState(() => _isLoading = true);

    final isPro = await RevenueCatService.isProUser();
    CustomerInfo? info;
    if (RevenueCatService.isInitialized) {
      try {
        info = await Purchases.getCustomerInfo();
      } catch (_) {}
    }

    final count = await DatabaseService.getSnippetCount();
    final totalUses = await DatabaseService.getTotalUsageCount();
    final estimatedHours = (totalUses * 2.5) / 60.0; // ~2.5 mins saved per snippet copy

    final pkgs = await RevenueCatService.getOfferings();

    if (mounted) {
      setState(() {
        _isProUser = isPro;
        _customerInfo = info;
        _snippetCount = count;
        _totalUsageCount = totalUses;
        _hoursSaved = estimatedHours;
        _packages = pkgs;
        _isLoading = false;

        if (_packages.isNotEmpty) {
          final annualPkg = _packages.firstWhere(
            (p) => p.packageType == PackageType.annual,
            orElse: () => _packages.first,
          );
          final monthlyPkg = _packages.firstWhere(
            (p) => p.packageType == PackageType.monthly,
            orElse: () => _packages.last,
          );

          if (annualPkg.storeProduct.priceString.trim().isNotEmpty &&
              !annualPkg.storeProduct.priceString.contains('null')) {
            _annualPriceText = "${annualPkg.storeProduct.priceString} / yr";
          }

          if (monthlyPkg.storeProduct.priceString.trim().isNotEmpty &&
              !monthlyPkg.storeProduct.priceString.contains('null')) {
            _monthlyPriceText = "${monthlyPkg.storeProduct.priceString} / mo";
          }
        }
      });
    }
  }

  Future<void> _handlePurchase(Package? package) async {
    setState(() => _isLoading = true);

    if (package != null) {
      final result = await RevenueCatService.makePurchase(package);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Welcome to ContextVault Pro! All features unlocked.'),
            backgroundColor: Color(0xFF238636),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (result.pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Payment Pending'),
            backgroundColor: const Color(0xFFD29922),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (!result.cancelled && result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase error: ${result.errorMessage}'),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    } else {
      // Sandbox fallback if offerings are empty
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Welcome to ContextVault Pro! All features unlocked.'),
          backgroundColor: Color(0xFF238636),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    // Show animated loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Color(0xFF161B22),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF58A6FF)),
                SizedBox(height: 16),
                Text(
                  'Validating receipt with Google Play...',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final info = await RevenueCatService.restorePurchases();
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final hasPro = info != null && RevenueCatService.hasActiveEntitlement(info);

      if (hasPro) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Purchases restored! ContextVault Pro is active.'),
            backgroundColor: Color(0xFF238636),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active subscriptions found for this Google account.'),
            backgroundColor: Color(0xFFD29922),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to reach Google Play services. Please check your network connection.'),
            backgroundColor: Color(0xFFDA3633),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _exportEncryptedVault() async {
    try {
      final jsonPayload = await DatabaseService.generateEncryptedBackupPayload();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ContextVault_Encrypted_Backup_${DateTime.now().millisecondsSinceEpoch}.vault');
      await file.writeAsString(jsonPayload);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'ContextVault Encrypted Database Backup',
        text: 'Encrypted backup generated by ContextVault Pro.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    }
  }

  Future<void> _openSubscriptionManagement() async {
    const defaultPlayStoreUrl = 'https://play.google.com/store/account/subscriptions';
    final Uri url = Uri.parse(defaultPlayStoreUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Play subscriptions page';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    }
  }

  Package? get _currentPackage {
    if (_packages.isEmpty) return null;
    if (_selectedPlan == BillingPlan.annual) {
      return _packages.firstWhere(
        (p) => p.packageType == PackageType.annual,
        orElse: () => _packages.first,
      );
    } else {
      return _packages.firstWhere(
        (p) => p.packageType == PackageType.monthly,
        orElse: () => _packages.last,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
              const SizedBox(height: 18),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
                  ),
                )
              else if (_isProUser)
                _buildActiveMemberHub()
              else
                _buildStandardPaywall(),
            ],
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------------------------
  /// PRO MEMBER HUB VIEW (FOR SUBSCRIBED USERS)
  /// ------------------------------------------------------------------
  Widget _buildActiveMemberHub() {
    String planTitle = "Pro Access";
    String expiryText = "Lifetime Unlocked";
    String statusText = "Active Membership";

    final entitlement = _customerInfo?.entitlements.all['pro_access'];
    if (entitlement != null && entitlement.isActive) {
      if (entitlement.productIdentifier.contains('annual')) {
        planTitle = "Annual Subscription";
      } else if (entitlement.productIdentifier.contains('monthly')) {
        planTitle = "Monthly Subscription";
      }

      if (entitlement.expirationDate != null) {
        final exp = DateTime.parse(entitlement.expirationDate!);
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        expiryText = "${exp.day.toString().padLeft(2, '0')} ${months[exp.month - 1]} ${exp.year}";
      }
      statusText = entitlement.willRenew ? "Auto-renewing" : "Active";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Shield Header
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF238636).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3FB950), width: 1.5),
              ),
              child: const Icon(Icons.verified_user_rounded, size: 28, color: Color(0xFF3FB950)),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ContextVault Pro',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Active Member Hub',
                  style: TextStyle(
                    color: Color(0xFF3FB950),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Membership Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF30363D)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF238636).withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT MEMBERSHIP',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        planTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF238636).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3FB950)),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(color: Color(0xFF3FB950), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF21262D), height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Renews / Valid Until:', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                  Text(expiryText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Analytics Widget (Time Saved)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1F6FEB).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.speed_rounded, color: Color(0xFF58A6FF), size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PRODUCTIVITY IMPACT',
                      style: TextStyle(color: Color(0xFF58A6FF), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Estimated ${_hoursSaved.toStringAsFixed(1)} hours saved',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Based on $_totalUsageCount dynamic snippet copies across your workflow.',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // "Your Pro Superpowers" Checklist
        const Text(
          'YOUR PRO SUPERPOWERS UNLOCKED',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        _buildSuperpowerItem('Unlimited Vault Storage', 'Currently managing $_snippetCount snippets'),
        _buildSuperpowerItem('Dynamic Multi-Step Engine', '{input:} forms & {list:} builders active'),
        _buildSuperpowerItem('150+ Curated Template Vault', 'Full professional library accessible'),
        _buildSuperpowerItem('Encrypted Database Backup', 'Export AES-256 encrypted JSON backups'),
        const SizedBox(height: 20),

        // Pro Action Buttons
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _exportEncryptedVault,
          icon: const Icon(Icons.shield, size: 18),
          label: const Text('Export Encrypted Vault Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF30363D)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openSubscriptionManagement,
                icon: const Icon(Icons.settings, size: 16, color: Color(0xFF58A6FF)),
                label: const Text('Manage Sub', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF30363D)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _handleRestore,
                icon: const Icon(Icons.restore, size: 16, color: Color(0xFF58A6FF)),
                label: const Text('Restore Purchases', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close Pro Hub', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildSuperpowerItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF3FB950), size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------------------------
  /// STANDARD PAYWALL VIEW (FOR FREE USERS)
  /// ------------------------------------------------------------------
  Widget _buildStandardPaywall() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F6FEB).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.bolt, size: 28, color: Color(0xFF58A6FF)),
            ),
            const SizedBox(width: 12),
            const Text(
              'ContextVault Pro',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Supercharge your power-user workflow with unlimited templates & floating overlays.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),

        _buildPlanToggle(),
        const SizedBox(height: 20),

        _buildComparisonMatrix(),
        const SizedBox(height: 24),

        _buildPurchaseButton(),
        const SizedBox(height: 16),

        _buildFooterLegal(),
      ],
    );
  }

  void _showPromoCodeModal() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Redeem Promo Code',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter an official promo or evaluation code to unlock ContextVault Pro privileges.',
                style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter code (e.g. SHIPATHON2026)',
                  hintStyle: const TextStyle(color: Color(0xFF484F58)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final code = controller.text.trim();
                  if (code.isEmpty) return;

                  final messenger = ScaffoldMessenger.of(context);
                  final rootNavigator = Navigator.of(context);
                  final modalNav = Navigator.of(modalContext);

                  final result = await CouponService.redeemCode(code);

                  if (result.success) {
                    HapticFeedback.heavyImpact();
                    modalNav.pop();
                    rootNavigator.pop(true);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        backgroundColor: const Color(0xFF238636),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        backgroundColor: const Color(0xFFDA3633),
                      ),
                    );
                  }
                },
                child: const Text('Apply Promo Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPlan = BillingPlan.annual);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedPlan == BillingPlan.annual ? const Color(0xFF21262D) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedPlan == BillingPlan.annual ? const Color(0xFF58A6FF) : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: _selectedPlan == BillingPlan.annual
                      ? [
                          BoxShadow(
                            color: const Color(0xFF58A6FF).withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Annual',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _selectedPlan == BillingPlan.annual ? Colors.white : const Color(0xFF8B949E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF238636),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Save $_savingsPercentage%',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$_annualPriceText ($_annualSubText)",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPlan = BillingPlan.monthly);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedPlan == BillingPlan.monthly ? const Color(0xFF21262D) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedPlan == BillingPlan.monthly ? const Color(0xFF58A6FF) : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: _selectedPlan == BillingPlan.monthly
                      ? [
                          BoxShadow(
                            color: const Color(0xFF58A6FF).withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _selectedPlan == BillingPlan.monthly ? Colors.white : const Color(0xFF8B949E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _monthlyPriceText,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonMatrix() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('FEATURE', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text('FREE TIER', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 3,
                child: Text('CONTEXTVAULT PRO', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF58A6FF), fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const Divider(color: Color(0xFF21262D), height: 16),
          _buildMatrixRow('Snippet Limit', '15 Max', 'Unlimited (Vault Sync)', isHighlight: true),
          const SizedBox(height: 8),
          _buildMatrixRow('Template Vault', '10 Essentials', '150+ Pro Library', isHighlight: true),
          const SizedBox(height: 8),
          _buildMatrixRow('Dynamic Variables', 'Standard', 'Multi-Field Forms ({input:})', isHighlight: false),
          const SizedBox(height: 8),
          _buildMatrixRow('Categories & Tagging', '3 Tags', 'Unlimited Color Tags', isHighlight: true),
          const SizedBox(height: 8),
          _buildMatrixRow('Quick-Dock Edge Overlay', 'Disabled', 'Background Floating Dock', isHighlight: false),
          const SizedBox(height: 8),
          _buildMatrixRow('Data Export & Backup', 'Plain Text', 'Encrypted JSON / Backup', isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(String feature, String freeVal, String proVal, {required bool isHighlight}) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(feature, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          flex: 2,
          child: Text(freeVal, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: isHighlight
                ? BoxDecoration(
                    color: const Color(0xFF1F6FEB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHighlight ? Icons.check_circle_rounded : Icons.star_rounded,
                  size: 13,
                  color: isHighlight ? const Color(0xFF58A6FF) : const Color(0xFF3FB950),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    proVal,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isHighlight ? const Color(0xFF58A6FF) : const Color(0xFF3FB950),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseButton() {
    final pkg = _currentPackage;
    final selectedPriceText = _selectedPlan == BillingPlan.annual ? _annualPriceText : _monthlyPriceText;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
        shadowColor: const Color(0xFF238636).withValues(alpha: 0.4),
      ),
      onPressed: () => _handlePurchase(pkg),
      child: Text(
        'Unlock Pro for $selectedPriceText',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFooterLegal() {
    return Column(
      children: [
        TextButton(
          onPressed: _showPromoCodeModal,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_giftcard, size: 16, color: Color(0xFF58A6FF)),
              SizedBox(width: 6),
              Text(
                'Have a Promo Code? Redeem',
                style: TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: _handleRestore,
              child: const Text('Restore Purchases', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
            ),
            const Text('•', style: TextStyle(color: Color(0xFF30363D))),
            TextButton(
              onPressed: () {},
              child: const Text('Terms', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
            ),
            const Text('•', style: TextStyle(color: Color(0xFF30363D))),
            TextButton(
              onPressed: () {},
              child: const Text('Privacy', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Continue with Free Plan',
            style: TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
