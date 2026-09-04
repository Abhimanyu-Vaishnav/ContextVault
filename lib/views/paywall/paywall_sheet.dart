import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../services/revenue_cat_service.dart';

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
      final customerInfo = await Purchases.restorePurchases();
      final isPro = customerInfo.entitlements.all['pro_access']?.isActive ?? false;

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
              content: Text('No active Pro subscription found to restore.'),
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

            // Billing Cycle Toggle Bar
            _buildPlanToggle(),
            const SizedBox(height: 20),

            // Free vs Pro Feature Comparison Matrix
            _buildComparisonMatrix(),
            const SizedBox(height: 24),

            // CTA Purchase Button
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
                ),
              )
            else
              _buildPurchaseButton(),
            const SizedBox(height: 16),

            // Legal & Restoration Footer
            _buildFooterLegal(),
          ],
        ),
      ),
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
              onTap: () => setState(() => _selectedPlan = BillingPlan.annual),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedPlan == BillingPlan.annual
                      ? const Color(0xFF21262D)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _selectedPlan == BillingPlan.annual
                      ? Border.all(
                          color: const Color(0xFF58A6FF).withValues(alpha: 0.5),
                        )
                      : null,
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
                          child: const Text(
                            'Save 40%',
                            style: TextStyle(
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
                      _packages.isNotEmpty && _currentPackage != null
                          ? '${_currentPackage!.storeProduct.priceString} / yr'
                          : '\$19.99 / yr (\$1.66/mo)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B949E),
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
              onTap: () => setState(() => _selectedPlan = BillingPlan.monthly),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedPlan == BillingPlan.monthly
                      ? const Color(0xFF21262D)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _selectedPlan == BillingPlan.monthly
                      ? Border.all(
                          color: const Color(0xFF58A6FF).withValues(alpha: 0.5),
                        )
                      : null,
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
                      _packages.isNotEmpty && _packages.length > 1
                          ? '${_packages.last.storeProduct.priceString} / mo'
                          : '\$2.99 / mo',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B949E),
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
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            decoration: isHighlight
                ? BoxDecoration(
                    color: const Color(0xFF1F6FEB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseButton() {
    final pkg = _currentPackage;
    final priceLabel = pkg != null
        ? '${pkg.storeProduct.priceString} / ${_selectedPlan == BillingPlan.annual ? 'year' : 'month'}'
        : _selectedPlan == BillingPlan.annual
        ? '\$19.99 / year'
        : '\$2.99 / month';

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
        'Unlock Pro for $priceLabel',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFooterLegal() {
    return Column(
      children: [
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
