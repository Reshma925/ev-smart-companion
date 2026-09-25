import 'package:flutter/material.dart';
import '../app_theme.dart';

class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.dashboard_outlined,
                  size: 72,
                  color: AppTheme.blue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Main Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Dashboard coming next',
                  style: TextStyle(color: AppTheme.mutedBlue, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
