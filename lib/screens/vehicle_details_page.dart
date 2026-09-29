import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/common_widgets.dart';
import 'bluetooth_scanning_page.dart';

class VehicleDetailsPage extends StatefulWidget {
  const VehicleDetailsPage({super.key, this.pendingSignup});

  final PendingSignup? pendingSignup;

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  final formKey = GlobalKey<FormState>();
  final registration = TextEditingController();
  final model = TextEditingController();
  final ownerName = TextEditingController();
  final vin = TextEditingController();
  final authService = AuthService();
  final firestoreService = FirestoreService();
  bool isLoading = false;

  @override
  void dispose() {
    registration.dispose();
    model.dispose();
    ownerName.dispose();
    vin.dispose();
    super.dispose();
  }

  Future<void> saveVehicleAndContinue() async {
    if (isLoading) return;
    if (!formKey.currentState!.validate()) {
      return;
    }
    setState(() => isLoading = true);
    User? newlyCreatedUser;
    var profileCreated = false;
    try {
      final signup = widget.pendingSignup;
      final vehicle = await firestoreService.verifyVehicleDetails(
        registrationNumber: registration.text,
        model: model.text,
        ownerName: ownerName.text,
        vin: vin.text,
      );
      if (vehicle == null) {
        if (mounted) {
          await showErrorDialog(
            context,
            'Vehicle details could not be verified. Please check all details and try again.',
            title: 'Vehicle verification failed',
          );
        }
        return;
      }

      User? user = authService.currentUser;
      if (signup != null &&
          user?.email?.toLowerCase() != signup.email.toLowerCase()) {
        if (user != null) {
          throw FirebaseAuthException(
            code: 'signup-session-mismatch',
            message: 'Please sign in again to continue onboarding.',
          );
        }
        final password = signup.password;
        if (password == null) {
          throw StateError('A password is required to create this account.');
        }
        user = (await authService.signUpWithEmail(
          email: signup.email,
          password: password,
          name: signup.name,
        )).user;
        newlyCreatedUser = user;
      }
      if (user == null) {
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'Your sign-in session ended. Please log in again.',
        );
      }

      final existingProfile = await firestoreService.getUserProfile(user.uid);
      if (existingProfile == null) {
        final profileName = signup?.name.trim().isNotEmpty == true
            ? signup!.name.trim()
            : user.displayName?.trim();
        if (profileName == null || profileName.isEmpty) {
          throw StateError(
            'A profile name is required to finish registration.',
          );
        }
        await firestoreService.createUserProfile(
          uid: user.uid,
          name: profileName,
          email: user.email ?? signup?.email ?? '',
          phone: signup?.mobile ?? '',
          vehicle: vehicle,
        );
        profileCreated = true;
      } else if (existingProfile.vehicleId != vehicle.id) {
        throw StateError(
          'This account is already registered to another vehicle.',
        );
      }
      final registeredVehicle = await firestoreService.getVehicleById(
        vehicle.id,
      );
      if (registeredVehicle == null) {
        throw StateError(
          'The verified vehicle is no longer active or could not be loaded.',
        );
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BluetoothScanningPage(vehicle: registeredVehicle),
        ),
        (route) => false,
      );
    } catch (error, stackTrace) {
      debugPrint('Vehicle registration failed: $error\n$stackTrace');
      if (newlyCreatedUser != null && !profileCreated) {
        try {
          await newlyCreatedUser.delete();
        } catch (_) {
          // Keep the original registration error visible if rollback is blocked.
        }
      }
      if (mounted) {
        await showErrorDialog(
          context,
          'Vehicle verification failed: ${authService.messageFor(error)}\n\nDetails: $error',
          title: 'Unable to register vehicle',
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
                ScreenHeader(
                  title: widget.pendingSignup == null
                      ? 'Register Your Vehicle'
                      : 'Verify Your Vehicle',
                  subtitle: 'Enter the details of your pre-registered vehicle.',
                ),
                const SizedBox(height: 34),
                TextInputField(
                  controller: registration,
                  label: 'Registration Number',
                  hint: 'Enter registration number',
                  icon: Icons.confirmation_number_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter the registered vehicle number'
                      : null,
                ),
                const SizedBox(height: 18),
                TextInputField(
                  controller: model,
                  label: 'Vehicle Model',
                  hint: 'Enter vehicle model',
                  icon: Icons.electric_car_outlined,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter the vehicle model'
                      : null,
                ),
                const SizedBox(height: 18),
                TextInputField(
                  controller: ownerName,
                  label: 'Owner Name',
                  hint: 'Enter registered owner name',
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter the registered owner name'
                      : null,
                ),
                const SizedBox(height: 18),
                TextInputField(
                  controller: vin,
                  label: 'VIN',
                  hint: 'Enter vehicle VIN',
                  icon: Icons.fingerprint,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter the vehicle VIN'
                      : null,
                ),
                const SizedBox(height: 30),
                PrimaryButton(
                  label: 'Verify and Pair Vehicle',
                  onPressed: saveVehicleAndContinue,
                  isLoading: isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
