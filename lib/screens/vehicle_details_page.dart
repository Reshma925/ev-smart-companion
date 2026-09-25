import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mock_service.dart';
import '../widgets/common_widgets.dart';
import 'vehicle_verifying_page.dart';

class VehicleDetailsPage extends StatefulWidget {
  const VehicleDetailsPage({super.key});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  final formKey = GlobalKey<FormState>();
  final registration = TextEditingController();
  final owner = TextEditingController();
  final vin = TextEditingController();
  String? model;

  @override
  void dispose() {
    registration.dispose();
    owner.dispose();
    vin.dispose();
    super.dispose();
  }

  void verify() {
    if (!formKey.currentState!.validate() || model == null) {
      showErrorDialog(
        context,
        'Select a vehicle model and complete every field.',
      );
      return;
    }
    final vehicle = MockService.findVehicle(
      model: model!,
      registrationNumber: registration.text.trim().replaceAll(' ', ''),
      ownerName: owner.text.trim(),
      vin: vin.text.trim(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VehicleVerifyingPage(vehicle: vehicle)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
            child: Column(
              children: [
                const ScreenHeader(
                  title: 'Pair Your Vehicle',
                  subtitle:
                      'Enter the details exactly as shown in your vehicle records.',
                ),
                const SizedBox(height: 34),
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Car Model',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: model,
                  decoration: const InputDecoration(
                    hintText: 'Select car model',
                    prefixIcon: Icon(
                      Icons.electric_car_outlined,
                      color: AppTheme.mutedBlue,
                    ),
                  ),
                  items: MockService.vehicles
                      .map(
                        (vehicle) => DropdownMenuItem(
                          value: vehicle.model,
                          child: Text(vehicle.model),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => model = value),
                  validator: (value) =>
                      value == null ? 'Select a car model' : null,
                ),
                const SizedBox(height: 18),
                TextInputField(
                  controller: registration,
                  label: 'Registration Number',
                  hint: 'Example: TN01AB1234',
                  icon: Icons.confirmation_number_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      v == null ||
                          !RegExp(
                            r'^[A-Za-z]{2}[0-9]{1,2}[A-Za-z]{1,3}[0-9]{4}$',
                          ).hasMatch(v.replaceAll(' ', ''))
                      ? 'Enter a valid registration number'
                      : null,
                ),
                const SizedBox(height: 18),
                TextInputField(
                  controller: owner,
                  label: 'Registered Owner Name',
                  hint: 'Enter owner name',
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter the registered owner name'
                      : null,
                ),
                const SizedBox(height: 18),
                TextInputField(
                  controller: vin,
                  label: 'VIN',
                  hint: 'Enter 17-character VIN',
                  icon: Icons.fingerprint,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => v == null || v.trim().length != 17
                      ? 'VIN must be 17 characters'
                      : null,
                ),
                const SizedBox(height: 30),
                PrimaryButton(label: 'Verify Vehicle', onPressed: verify),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
