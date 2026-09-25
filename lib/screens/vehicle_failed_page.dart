import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/common_widgets.dart';
import 'vehicle_details_page.dart';

class VehicleFailedPage extends StatelessWidget {
  const VehicleFailedPage({super.key});

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
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.redAccent,
                    size: 55,
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Verification Failed',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The entered vehicle information does not match our records. Check the model, registration number, owner name and VIN, then try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedBlue, height: 1.5),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Try Again',
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VehicleDetailsPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
