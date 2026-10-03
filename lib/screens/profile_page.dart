import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle.dart';
import '../models/vehicle_telemetry.dart';
import '../services/auth_service.dart';
import '../services/distance_unit_service.dart';
import '../services/firestore_service.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';
import 'vehicle_details_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  late final StreamSubscription<User?> _authSubscription;
  User? _user;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (mounted) setState(() => _user = user);
    });
    _reloadAuthUser();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _reloadAuthUser() async {
    try {
      await _authService.currentUser?.reload();
      if (mounted) setState(() => _user = _authService.currentUser);
    } catch (_) {
      // Keep the locally available authenticated identity if refresh is offline.
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (error) {
      if (mounted) _showMessage(_authService.messageFor(error));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.background,
        scrolledUnderElevation: 0,
      ),
      body: user == null
          ? _SignedOutView(
              onSignIn: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              ),
            )
          : _ProfileDetails(
              key: ValueKey(user.uid),
              user: user,
              authService: _authService,
              signingOut: _signingOut,
              onSignOut: _signOut,
              onMessage: _showMessage,
            ),
    );
  }
}

class _ProfileDetails extends StatefulWidget {
  const _ProfileDetails({
    super.key,
    required this.user,
    required this.authService,
    required this.signingOut,
    required this.onSignOut,
    required this.onMessage,
  });

  final User user;
  final AuthService authService;
  final bool signingOut;
  final VoidCallback onSignOut;
  final ValueChanged<String> onMessage;

  @override
  State<_ProfileDetails> createState() => _ProfileDetailsState();
}

class _ProfileDetailsState extends State<_ProfileDetails>
    with WidgetsBindingObserver {
  final _firestore = FirestoreService();
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  late Stream<UserModel?> _profileStream;
  late Future<UserModel?> _initialProfile;
  bool _uploadingPhoto = false;
  bool _locationEnabled = false;
  bool _checkingLocation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeToProfile();
    _refreshLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationPermission();
    }
  }

  void _subscribeToProfile() {
    _profileStream = _firestore.watchUserProfile(widget.user.uid);
    _initialProfile = _firestore
        .getUserProfile(widget.user.uid)
        .timeout(const Duration(seconds: 20));
  }

  void _retryProfile() => setState(_subscribeToProfile);

  Future<void> _editProfile(UserModel profile) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(profile: profile)),
    );
    if (saved == true && mounted) {
      widget.onMessage('Profile updated.');
      setState(() => _subscribeToProfile());
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_uploadingPhoto) return;
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } catch (_) {
      if (mounted) {
        widget.onMessage('Could not open your photos. Please try again.');
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final fileBytes = await picked.readAsBytes();
      final extension = picked.name.split('.').last.toLowerCase();
      final fileExt = const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
          ? extension
          : 'jpg';
      final contentType = fileExt == 'jpg' ? 'image/jpeg' : 'image/$fileExt';
      final ref = _storage.ref().child(
        'users/${widget.user.uid}/profile_photo.$fileExt',
      );
      final uploadTask = ref.putData(
        fileBytes,
        SettableMetadata(contentType: contentType),
      );
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      await _firestore.updateUserProfile(
        uid: widget.user.uid,
        profileImageUrl: url,
      );
      if (mounted) {
        widget.onMessage('Profile photo updated.');
        setState(() => _subscribeToProfile());
      }
    } catch (error) {
      if (mounted) {
        widget.onMessage(
          'Could not update your profile photo. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _refreshLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _locationEnabled =
            serviceEnabled &&
            (permission == LocationPermission.always ||
                permission == LocationPermission.whileInUse);
        _checkingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationEnabled = false;
        _checkingLocation = false;
      });
    }
  }

  Future<void> _locationPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        await _refreshLocationPermission();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
      await _refreshLocationPermission();
    } catch (error) {
      if (mounted) {
        widget.onMessage('Could not update location access. Please try again.');
      }
    }
  }

  Future<void> _verifyEmail() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      widget.onMessage('No authenticated user is available.');
      return;
    }

    try {
      await currentUser.sendEmailVerification();
      await currentUser.reload();
      if (mounted) {
        widget.onMessage(
          'Verification email sent. Please check your inbox and refresh your status.',
        );
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        widget.onMessage(widget.authService.messageFor(error));
      }
    }
  }

  Future<void> _refreshEmailStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await currentUser.reload();
      if (mounted) setState(() {});
    } catch (_) {
      // The existing auth state is still valid if the refresh fails.
    }
  }

  Future<void> _showPreferenceDialog({
    required String title,
    required List<String> options,
    required String currentValue,
    required Future<void> Function(String) onSelected,
  }) async {
    String selectedValue = currentValue;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: RadioGroup<String>(
              groupValue: selectedValue,
              onChanged: (value) {
                if (value == null) return;
                selectedValue = value;
                setDialogState(() {});
                Navigator.pop(dialogContext, value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map(
                      (option) => RadioListTile<String>(
                        value: option,
                        title: Text(switch (option) {
                          'km' => 'Kilometres (km)',
                          'mi' => 'Miles (mi)',
                          _ => option,
                        }),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null && selected != currentValue) {
      try {
        await onSelected(selected);
      } catch (error) {
        if (mounted) {
          widget.onMessage(widget.authService.messageFor(error));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserModel?>(
    future: _initialProfile,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _ProfileStateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Profile unavailable',
          message:
              'We could not load your Firestore profile. Check your connection and retry.',
          actionLabel: 'Retry',
          onAction: _retryProfile,
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final initialProfile = snapshot.data;
      if (initialProfile == null) {
        return _ProfileStateMessage(
          icon: Icons.person_off_outlined,
          title: 'Profile not found',
          message:
              'There is no Firestore profile linked to this signed-in account.',
          actionLabel: 'Retry',
          onAction: _retryProfile,
        );
      }

      return StreamBuilder<UserModel?>(
        stream: _profileStream,
        initialData: initialProfile,
        builder: (context, liveSnapshot) {
          if (liveSnapshot.hasError && !liveSnapshot.hasData) {
            return _ProfileStateMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Profile updates unavailable',
              message:
                  'Your profile was loaded, but live Firestore updates are unavailable.',
              actionLabel: 'Retry',
              onAction: _retryProfile,
            );
          }

          final profile = liveSnapshot.data ?? initialProfile;

          return RefreshIndicator(
            onRefresh: () async {
              setState(_subscribeToProfile);
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
                  children: [
                    _ProfileHeader(
                      user: FirebaseAuth.instance.currentUser ?? widget.user,
                      profile: profile,
                      uploading: _uploadingPhoto,
                      onEditProfile: () => _editProfile(profile),
                      onEditPhoto: _uploadProfilePhoto,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Personal information'),
                    const SizedBox(height: 12),
                    _PersonalInfoCard(
                      profile: profile,
                      createdAt:
                          widget.user.metadata.creationTime ??
                          profile.createdAt,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'My vehicle'),
                    const SizedBox(height: 12),
                    _VehicleShortcutCard(
                      firestore: _firestore,
                      vehicleId: profile.vehicleId,
                      onTap: () async {
                        if (profile.vehicleId == null ||
                            profile.vehicleId!.trim().isEmpty) {
                          final navContext = context;
                          if (!mounted) return;
                          if (!navContext.mounted) return;
                          Navigator.push(
                            navContext,
                            MaterialPageRoute(
                              builder: (_) => const VehicleDetailsPage(),
                            ),
                          );
                          return;
                        }
                        final navContext = context;
                        final linkedVehicle = await _firestore
                            .getVehicleRecordById(profile.vehicleId!);
                        if (!mounted) return;
                        if (linkedVehicle == null) {
                          widget.onMessage(
                            'The linked vehicle is unavailable in Firestore.',
                          );
                          return;
                        }
                        if (!navContext.mounted) return;
                        Navigator.push(
                          navContext,
                          MaterialPageRoute(
                            builder: (_) =>
                                VehicleDetailsPage(vehicle: linkedVehicle),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Preferences'),
                    const SizedBox(height: 12),
                    _PreferencesCard(
                      profile: profile,
                      onLocation: _locationPermission,
                      locationEnabled: _locationEnabled,
                      checkingLocation: _checkingLocation,
                      onNotifications: () => _showPreferenceDialog(
                        title: 'Notifications',
                        options: const ['All alerts', 'Vehicle only', 'Off'],
                        currentValue: profile.notificationPreference.isEmpty
                            ? 'All alerts'
                            : profile.notificationPreference,
                        onSelected: (value) async {
                          await _firestore.updateUserProfile(
                            uid: widget.user.uid,
                            notificationPreference: value,
                          );
                          widget.onMessage('Notification preference updated.');
                        },
                      ),
                      onUnits: () => _showPreferenceDialog(
                        title: 'Distance unit',
                        options: const ['km', 'mi'],
                        currentValue: DistanceUnitService.normalize(
                          profile.distanceUnit,
                        ),
                        onSelected: (value) async {
                          await _firestore.updateUserProfile(
                            uid: widget.user.uid,
                            distanceUnit: value,
                          );
                          widget.onMessage('Distance unit updated.');
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Account'),
                    const SizedBox(height: 12),
                    _AccountCard(
                      user: FirebaseAuth.instance.currentUser ?? widget.user,
                      signingOut: widget.signingOut,
                      onVerifyEmail: _verifyEmail,
                      onRefreshStatus: _refreshEmailStatus,
                      onTap: widget.onSignOut,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _VehicleShortcutCard extends StatelessWidget {
  const _VehicleShortcutCard({
    required this.firestore,
    required this.vehicleId,
    required this.onTap,
  });

  final FirestoreService firestore;
  final String? vehicleId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = vehicleId?.trim() ?? '';
    if (id.isEmpty) {
      return _card(
        context,
        title: 'No vehicle linked',
        subtitle: 'Link your registered EV to your account',
      );
    }

    return StreamBuilder<Vehicle?>(
      stream: firestore.watchVehicleById(id),
      builder: (context, snapshot) {
        final vehicle = snapshot.data;
        return _card(
          context,
          title: snapshot.hasError
              ? 'Vehicle details unavailable'
              : vehicle?.model.isNotEmpty == true
              ? vehicle!.model
              : snapshot.connectionState == ConnectionState.waiting
              ? 'Loading linked vehicle…'
              : 'Vehicle details unavailable',
          subtitle: vehicle?.registrationNumber.isNotEmpty == true
              ? vehicle!.registrationNumber
              : 'Open linked EV details',
        );
      },
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EBF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.electric_car_rounded, color: AppTheme.blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.mutedBlue,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedBlue),
        ],
      ),
    ),
  );
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.profile,
    required this.onLocation,
    required this.locationEnabled,
    required this.checkingLocation,
    required this.onNotifications,
    required this.onUnits,
  });

  final UserModel profile;
  final VoidCallback onLocation;
  final bool locationEnabled;
  final bool checkingLocation;
  final VoidCallback onNotifications;
  final VoidCallback onUnits;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5EBF0)),
    ),
    child: Column(
      children: [
        _PreferenceRow(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          value: profile.notificationPreference.isEmpty
              ? 'All alerts'
              : profile.notificationPreference,
          onTap: onNotifications,
        ),
        _PreferenceRow(
          icon: Icons.location_on_outlined,
          title: 'Location Services',
          value: checkingLocation
              ? 'Checking permission…'
              : locationEnabled
              ? 'Enabled · Local weather and driving conditions'
              : 'Enable Location · Used for local weather and driving conditions',
          onTap: onLocation,
        ),
        _PreferenceRow(
          icon: Icons.straighten_rounded,
          title: 'Distance Unit',
          value:
              DistanceUnitService.normalize(profile.distanceUnit) ==
                  DistanceUnitService.mi
              ? 'Miles (mi)'
              : 'Kilometres (km)',
          onTap: onUnits,
        ),
      ],
    ),
  );
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.mutedBlue,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedBlue),
        ],
      ),
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.signingOut,
    required this.onVerifyEmail,
    required this.onRefreshStatus,
    required this.onTap,
  });

  final User user;
  final bool signingOut;
  final VoidCallback onVerifyEmail;
  final VoidCallback onRefreshStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verified = user.emailVerified;
    final statusColor = verified
        ? const Color(0xFF16875A)
        : const Color(0xFFB87B00);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EBF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified
                    ? Icons.verified_rounded
                    : Icons.mark_email_unread_outlined,
                color: statusColor,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  verified ? 'Email verified' : 'Email not verified',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRefreshStatus,
                child: const Text('Refresh'),
              ),
            ],
          ),
          if (!verified)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onVerifyEmail,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Send verification email'),
              ),
            ),
          const Divider(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: signingOut ? null : onTap,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD93C4E),
                alignment: Alignment.centerLeft,
              ),
              icon: signingOut
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(signingOut ? 'Signing out…' : 'Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.profile,
    required this.uploading,
    required this.onEditProfile,
    required this.onEditPhoto,
  });

  final User user;
  final UserModel profile;
  final bool uploading;
  final VoidCallback onEditProfile;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.profileImageUrl.trim();
    final displayName = profile.name.trim().isEmpty
        ? 'Not provided'
        : profile.name.trim();
    final authEmail = user.email?.trim() ?? '';
    final displayEmail = authEmail.isNotEmpty
        ? authEmail
        : profile.email.trim().isNotEmpty
        ? profile.email.trim()
        : 'Not provided';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EBF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A11263E),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Container(
                  width: 116,
                  height: 116,
                  color: const Color(0xFFEBF4FF),
                  child: imageUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: AppTheme.blue,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.person_rounded,
                                size: 64,
                                color: AppTheme.blue,
                              ),
                        ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: AppTheme.blue,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: uploading ? null : onEditPhoto,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: uploading
                            ? const SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            displayEmail,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: AppTheme.navy,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.profile, required this.createdAt});

  final UserModel profile;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final items = <_PersonalInfoItem>[
      _PersonalInfoItem(
        icon: Icons.phone_outlined,
        label: 'Phone',
        value: profile.phone.trim().isEmpty ? 'Not provided' : profile.phone,
      ),
      if (profile.city.trim().isNotEmpty)
        _PersonalInfoItem(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: profile.city.trim(),
        ),
      _PersonalInfoItem(
        icon: Icons.calendar_month_outlined,
        label: 'Member since',
        value: createdAt == null
            ? 'Not provided'
            : MaterialLocalizations.of(context).formatMediumDate(createdAt!),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EBF0)),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: _PersonalInfoTile(item: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PersonalInfoItem {
  const _PersonalInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _PersonalInfoTile extends StatelessWidget {
  const _PersonalInfoTile({required this.item});

  final _PersonalInfoItem item;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 92),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8EDF2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(item.icon, size: 17, color: AppTheme.blue),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _VehicleSummaryCard extends StatefulWidget {
  const _VehicleSummaryCard({
    required this.firestore,
    required this.vehicleId,
    required this.distanceUnit,
  });

  final FirestoreService firestore;
  final String vehicleId;
  final String distanceUnit;

  @override
  State<_VehicleSummaryCard> createState() => _VehicleSummaryCardState();
}

class _VehicleSummaryCardState extends State<_VehicleSummaryCard> {
  late Stream<Vehicle?> _vehicleStream;
  late Stream<VehicleData?> _telemetryStream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _VehicleSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleId != widget.vehicleId) {
      _subscribe();
    }
  }

  void _subscribe() {
    _vehicleStream = widget.firestore.watchVehicleById(widget.vehicleId);
    _telemetryStream = widget.firestore.watchVehicleTelemetry(widget.vehicleId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Vehicle?>(
    stream: _vehicleStream,
    builder: (context, vehicleSnapshot) {
      if (vehicleSnapshot.hasError) {
        return _ProfileStateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Vehicle unavailable',
          message: 'We could not load your registered EV from Firestore.',
          actionLabel: 'Retry',
          onAction: () => setState(_subscribe),
        );
      }
      if (!vehicleSnapshot.hasData &&
          vehicleSnapshot.connectionState == ConnectionState.waiting) {
        return const _LoadingCard(label: 'Loading your EV…');
      }

      final vehicle = vehicleSnapshot.data;
      if (vehicle == null) {
        return _ProfileStateMessage(
          icon: Icons.directions_car_outlined,
          title: 'Vehicle missing',
          message: 'The registered vehicle for this account is not available.',
          actionLabel: 'Retry',
          onAction: () => setState(_subscribe),
        );
      }

      return StreamBuilder<VehicleData?>(
        stream: _telemetryStream,
        builder: (context, telemetrySnapshot) {
          final telemetry = telemetrySnapshot.data;
          final chargeLabel = telemetry != null && telemetry.isCharging
              ? 'Charging'
              : 'Standby';
          final connectionLabel = vehicle.bluetoothDeviceId.isNotEmpty
              ? 'Bluetooth registered'
              : 'Not connected';

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5EBF0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.electric_car_rounded,
                        color: AppTheme.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.model.isEmpty
                                ? 'Model not provided'
                                : vehicle.model,
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.registrationNumber.isEmpty
                                ? 'Registration not provided'
                                : vehicle.registrationNumber,
                            style: const TextStyle(
                              color: AppTheme.mutedBlue,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(
                      label: vehicle.isActive ? 'Active' : 'Inactive',
                      active: vehicle.isActive,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.bluetooth_rounded,
                      color: AppTheme.mutedBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connectionLabel,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TelemetryTile(
                        icon: Icons.battery_charging_full_rounded,
                        label: 'Battery',
                        value: telemetry == null
                            ? '—'
                            : '${telemetry.battery.round()}%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TelemetryTile(
                        icon: Icons.route_rounded,
                        label: 'Range',
                        value: telemetry == null
                            ? '—'
                            : DistanceUnitService.format(
                                telemetry.range,
                                widget.distanceUnit,
                                decimals: 0,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TelemetryTile(
                        icon: Icons.health_and_safety_outlined,
                        label: 'Health',
                        value: telemetry == null
                            ? '—'
                            : '${telemetry.batteryHealth.round()}%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE9EEF3)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InlineStatus(
                        icon: telemetry != null && telemetry.isCharging
                            ? Icons.ev_station_rounded
                            : Icons.power_outlined,
                        label: chargeLabel,
                        color: telemetry != null && telemetry.isCharging
                            ? const Color(0xFF16875A)
                            : AppTheme.mutedBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineStatus(
                        icon: Icons.bluetooth_disabled_rounded,
                        label: 'Not connected',
                        color: AppTheme.mutedBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vehicle ID: ${vehicle.id.isEmpty ? 'Not provided' : vehicle.id}',
                    style: const TextStyle(
                      color: AppTheme.mutedBlue,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _TelemetryTile extends StatelessWidget {
  const _TelemetryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.blue, size: 18),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF16875A) : const Color(0xFFD93C4E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5EBF0)),
    ),
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppTheme.mutedBlue)),
      ],
    ),
  );
}

class _ProfileStateMessage extends StatelessWidget {
  const _ProfileStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5EBF0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.mutedBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: AppTheme.mutedBlue, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: _ProfileStateMessage(
        icon: Icons.lock_outline_rounded,
        title: 'You are signed out',
        message: 'Sign in to view your Firebase profile and registered EV.',
        actionLabel: 'Sign in',
        onAction: onSignIn,
      ),
    ),
  );
}
