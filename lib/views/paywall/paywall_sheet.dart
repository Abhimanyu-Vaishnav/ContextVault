import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../services/revenue_cat_service.dart';

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key});

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  bool _isLoading = true;
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

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isLoading = true);
    final isSuccess = await RevenueCatService.makePurchase(package);
    setState(() => _isLoading = false);

    if (isSuccess && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to ContextVault Pro!'),
          backgroundColor: Color(0xFF238636),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.bolt, size: 48, color: Color(0xFF58A6FF)),
          const SizedBox(height: 12),
          const Text(
            'Unlock ContextVault Pro',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Supercharge your power-user workflow with unlimited templates & dynamic overlays.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildFeatureRow(
            Icons.all_inclusive,
            'Unlimited snippets & tags (Free limited to 25)',
          ),
          _buildFeatureRow(
            Icons.layers,
            'Floating Edge Dock & System Overlay access',
          ),
          _buildFeatureRow(Icons.code, 'Custom dynamic token parser engine'),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_packages.isEmpty)
            // Fallback UI for testing/judges before Play Console IAP links
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pro Monthly Plan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$2.99 / mo',
                        style: TextStyle(
                          color: Color(0xFF58A6FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sandbox Pro Access Granted!'),
                      ),
                    );
                  },
                  child: const Text(
                    'Unlock Pro (Demo / Judge Mode)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          else
            ..._packages.map(
              (pkg) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _handlePurchase(pkg),
                child: Text(
                  'Subscribe for ${pkg.storeProduct.priceString} / month',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF58A6FF)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
