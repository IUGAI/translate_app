import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';

class PricingView extends StatelessWidget {
  const PricingView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Column(
      children: [
        _buildPlanCard(
          context,
          title: 'Free',
          price: r'$0',
          features: [
            '10 translations per day',
            'Basic voice selection',
            'Standard support',
          ],
          isCurrent: appState.userPlan == 'Free',
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          context,
          title: 'Pro',
          price: r'$9.99/mo',
          features: [
            'Unlimited translations',
            'Premium AI voices',
            'Priority support',
            'No ads',
          ],
          isCurrent: appState.userPlan == 'Pro',
          color: Colors.blueAccent,
          isBestValue: true,
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          context,
          title: 'Enterprise',
          price: 'Custom',
          features: [
            'Team collaboration',
            'API access',
            'Dedicated account manager',
          ],
          isCurrent: appState.userPlan == 'Enterprise',
          color: Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required List<String> features,
    required bool isCurrent,
    required Color color,
    bool isBestValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent ? color : Colors.white.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          if (isBestValue)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Best Value',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: color),
                      const SizedBox(width: 8),
                      Text(
                        f,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrent ? Colors.transparent : color,
                    foregroundColor: Colors.white,
                    side: isCurrent ? BorderSide(color: color) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isCurrent ? null : () {},
                  child: Text(isCurrent ? 'Current Plan' : 'Upgrade'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
