import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../services/revenue_cat_service.dart';
import '../../../services/coupon_service.dart';

enum BillingPlan { annual, monthly }

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key});

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  bool _isLoading = true;
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
    // Default to Indian Rupee (₹) unless device locale specifically indicates USD/other currency
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
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final pkgs = await RevenueCatService.getOfferings();
    if (mounted) {
      setState(() {
        _packages = pkgs;
        _isLoading = false;

        // If RevenueCat returns live store product strings, update state dynamically
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
    setState(() => _isLoading = true);
    try {
      final customerInfo = await RevenueCatService.restorePurchases();
      final isPro = customerInfo?.entitlements.all['pro_access']?.isActive ?? false;

      if (mounted) {
        setState(() => _isLoading = false);
        if (isPro) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Purchases successfully restored! Welcome back Pro user.',
              ),
              backgroundColor: Color(0xFF238636),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active Pro subscriptions found for this Google account.'),
              backgroundColor: Color(0xFFD29922),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
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

              // Header Banner Icon & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F6FEB).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF58A6FF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.bolt,
                      size: 28,
                      color: Color(0xFF58A6FF),
                    ),
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
                style: TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Billing Cycle Toggle Bar with Spring Animated Glow
              _buildPlanToggle(),
              const SizedBox(height: 20),

              // Free vs Pro Feature Comparison Matrix with Icons
              _buildComparisonMatrix(),
              const SizedBox(height: 24),

              // CTA Purchase Button
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                )
              else
                _buildPurchaseButton(),
              const SizedBox(height: 16),

              // Clean Legal & Restoration Footer
              _buildFooterLegal(),
            ],
          ),
        ),
      ),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                child: const Text(
                  'Apply Promo Code',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
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
          // Annual Option
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
                  color: _selectedPlan == BillingPlan.annual
                      ? const Color(0xFF21262D)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedPlan == BillingPlan.annual
                        ? const Color(0xFF58A6FF)
                        : Colors.transparent,
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
                            color: _selectedPlan == BillingPlan.annual
                                ? Colors.white
                                : const Color(0xFF8B949E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF238636),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Save $_savingsPercentage%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$_annualPriceText ($_annualSubText)",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B949E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Monthly Option
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
                  color: _selectedPlan == BillingPlan.monthly
                      ? const Color(0xFF21262D)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedPlan == BillingPlan.monthly
                        ? const Color(0xFF58A6FF)
                        : Colors.transparent,
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
                        color: _selectedPlan == BillingPlan.monthly
                            ? Colors.white
                            : const Color(0xFF8B949E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _monthlyPriceText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B949E),
                        fontWeight: FontWeight.w500,
                      ),
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
          // Table Header
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'FEATURE',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'FREE TIER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'CONTEXTVAULT PRO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF58A6FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF21262D), height: 16),

          // Feature Rows
          _buildMatrixRow(
            'Snippet Limit',
            '15 Max',
            'Unlimited (Vault Sync)',
            isHighlight: true,
          ),
          const SizedBox(height: 8),
          _buildMatrixRow(
            'Template Vault',
            '10 Essentials',
            '150+ Pro Library',
            isHighlight: true,
          ),
          const SizedBox(height: 8),
          _buildMatrixRow(
            'Dynamic Variables',
            'Standard',
            'Multi-Field Forms ({input:})',
            isHighlight: false,
          ),
          const SizedBox(height: 8),
          _buildMatrixRow(
            'Categories & Tagging',
            '3 Tags',
            'Unlimited Color Tags',
            isHighlight: true,
          ),
          const SizedBox(height: 8),
          _buildMatrixRow(
            'Quick-Dock Edge Overlay',
            'Disabled',
            'Background Floating Dock',
            isHighlight: false,
          ),
          const SizedBox(height: 8),
          _buildMatrixRow(
            'Data Export & Backup',
            'Plain Text',
            'Encrypted JSON / Backup',
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(
    String feature,
    String freeVal,
    String proVal, {
    required bool isHighlight,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            feature,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            freeVal,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
          ),
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
                  color: isHighlight
                      ? const Color(0xFF58A6FF)
                      : const Color(0xFF3FB950),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    proVal,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isHighlight
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFF3FB950),
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
    final selectedPriceText =
        _selectedPlan == BillingPlan.annual ? _annualPriceText : _monthlyPriceText;

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
              child: const Text(
                'Restore Purchases',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
            ),
            const Text('•', style: TextStyle(color: Color(0xFF30363D))),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Terms',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
            ),
            const Text('•', style: TextStyle(color: Color(0xFF30363D))),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Privacy',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
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
