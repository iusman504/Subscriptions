import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_subscriptions/ui/subscription/subscription_provider.dart';

class SubscriptionScreen extends StatelessWidget {
  final bool isCameFromScanScreen;

  const SubscriptionScreen({super.key, this.isCameFromScanScreen = false});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SubscriptionProvider(),
      child: const _SubscriptionView(),
    );
  }
}

class _SubscriptionView extends StatelessWidget {
  const _SubscriptionView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription'), centerTitle: true),
      body: provider.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 16),

                /// 🔐 Premium status
                Icon(
                  provider.isPremium ? Icons.verified : Icons.lock_outline,
                  size: 72,
                  color: provider.isPremium ? Colors.green : Colors.grey,
                ),

                const SizedBox(height: 8),

                Text(
                  provider.isPremium
                      ? 'You are Premium 🎉'
                      : 'Unlock Premium Features',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 24),

                /// 📦 Subscription Plans
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.products.length,
                    itemBuilder: (context, index) {
                      final plan = provider.products[index];
                      final product = plan.product;

                      if (product == null || !plan.isVisiblePlan) {
                        return const SizedBox.shrink();
                      }

                      return _PlanTile(
                        title: provider.getDisplayTitle(product),
                        price: plan.displayPrice,
                        isSelected: plan.isSelected,
                        onTap: () => provider.selectPlan(index),
                      );
                    },
                  ),
                ),

                /// 🛒 Purchase Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: provider.isPurchaseInProgress
                          ? null
                          : () {
                              final selectedPlan =
                                  provider.products[provider.selectedPlanIndex];

                              if (selectedPlan.product != null) {
                                provider.startPurchase(selectedPlan.product!);
                              }
                            },
                      child: provider.isPurchaseInProgress
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              provider.isPremium
                                  ? 'Manage Subscription'
                                  : 'Continue',
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.title,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: 2,
          ),
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha:  0.05)
              : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              price,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
