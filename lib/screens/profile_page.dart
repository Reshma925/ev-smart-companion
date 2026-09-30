import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/vehicle_simulator.dart';
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

class _ProfileDetailsState extends State<_ProfileDetails> {
  final _firestore = FirestoreService();
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  late Stream<UserModel?> _profileStream;
  late Future<UserModel?> _initialProfile;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _subscribeToProfile();
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

  Future<void> _uploadProfilePhoto(UserModel profile) async {
    if (_uploadingPhoto) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final fileBytes = await picked.readAsBytes();
      final extension = picked.name.split('.').last.toLowerCase();
      final fileExt = extension.isNotEmpty ? extension : 'jpg';
      final ref = _storage
          .ref()
          .child('users/${widget.user.uid}/profile_photo.$fileExt');
      final uploadTask = ref.putData(
        fileBytes,
        SettableMetadata(contentType: 'image/$fileExt'),
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
        widget.onMessage('Could not update your profile photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _locationPermission() async {
    String message;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      message = switch (permission) {
        LocationPermission.always || LocationPermission.whileInUse =>
          'Location access is enabled for local driving conditions and weather updates.',
        LocationPermission.deniedForever =>
          'Location permission is blocked. Enable it in your device settings to use local EV conditions.',
        _ =>
          'Location permission is disabled. Enable it to get local driving conditions.',
      };
    } catch (error) {
      message = 'Could not check location permission. Please try again.';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location services'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  int _profileCompletion(UserModel profile) {
    final checks = <bool>[
      profile.name.trim().isNotEmpty,
      profile.phone.trim().isNotEmpty,
      profile.city.trim().isNotEmpty,
      profile.profileImageUrl.trim().isNotEmpty,
      profile.vehicleId != null && profile.vehicleId!.trim().isNotEmpty,
    ];
    final complete = checks.where((element) => element).length;
    return ((complete / checks.length) * 100).round();
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
                        title: Text(option),
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
      await onSelected(selected);
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
          final completion = _profileCompletion(profile);
          final vehicleName = profile.vehicleId == null || profile.vehicleId!.trim().isEmpty
              ? 'No vehicle connected'
              : 'View vehicle';
          final vehicleSubtitle = profile.vehicleId == null || profile.vehicleId!.trim().isEmpty
              ? 'Add a vehicle to your Firestore profile'
              : 'Open the linked EV details';

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
                      user: widget.user,
                      profile: profile,
                      uploading: _uploadingPhoto,
                      onEditProfile: () => _editProfile(profile),
                      onEditPhoto: () => _uploadProfilePhoto(profile),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5EBF0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            completion >= 80 ? Icons.verified_rounded : Icons.info_outline_rounded,
                            color: completion >= 80 ? const Color(0xFF1EA76A) : const Color(0xFFB77A00),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              completion >= 80 ? 'Profile complete' : 'Profile $completion% complete',
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Personal information'),
                    const SizedBox(height: 12),
                    _PersonalInfoCard(
                      profile: profile,
                      email: widget.user.email ?? profile.email,
                      createdAt: widget.user.metadata.creationTime ?? profile.createdAt,
                      onEdit: () => _editProfile(profile),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'My vehicle'),
                    const SizedBox(height: 12),
                    _VehicleShortcutCard(
                      title: vehicleName,
                      subtitle: vehicleSubtitle,
                      onTap: () {
                        if (profile.vehicleId == null || profile.vehicleId!.trim().isEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const VehicleDetailsPage()),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VehicleDetailsPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Preferences'),
                    const SizedBox(height: 12),
                    _PreferencesCard(
                      profile: profile,
                      onLocation: _locationPermission,
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
                        options: const ['Kilometres', 'Miles'],
                        currentValue: profile.unitSystem.isEmpty
                            ? 'Kilometres'
                            : profile.unitSystem,
                        onSelected: (value) async {
                          await _firestore.updateUserProfile(
                            uid: widget.user.uid,
                            unitSystem: value,
                          );
                          widget.onMessage('Distance unit updated.');
                        },
                      ),
                      onTemperature: () => _showPreferenceDialog(
                        title: 'Temperature unit',
                        options: const ['Celsius', 'Fahrenheit'],
                        currentValue: 'Celsius',
                        onSelected: (value) async {
                          widget.onMessage('Temperature unit set to $value for this device session.');
                        },
                      ),
                      onAppearance: () => _showPreferenceDialog(
                        title: 'Appearance',
                        options: const ['System', 'Light', 'Dark'],
                        currentValue: 'System',
                        onSelected: (value) async {
                          widget.onMessage('Appearance set to $value for this device session.');
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Account'),
                    const SizedBox(height: 12),
                    _AccountActionCard(
                      icon: Icons.logout_rounded,
                      title: 'Sign out',
                      subtitle: 'End the current authenticated session',
                      destructive: true,
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
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
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
    required this.onNotifications,
    required this.onUnits,
    required this.onTemperature,
    required this.onAppearance,
  });

  final UserModel profile;
  final VoidCallback onLocation;
  final VoidCallback onNotifications;
  final VoidCallback onUnits;
  final VoidCallback onTemperature;
  final VoidCallback onAppearance;

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
          title: 'Location',
          value: 'Weather & driving conditions',
          onTap: onLocation,
        ),
        _PreferenceRow(
          icon: Icons.straighten_rounded,
          title: 'Distance',
          value: profile.unitSystem.isEmpty ? 'Kilometres' : profile.unitSystem,
          onTap: onUnits,
        ),
        _PreferenceRow(
          icon: Icons.thermostat_rounded,
          title: 'Temperature',
          value: 'Celsius',
          onTap: onTemperature,
        ),
        _PreferenceRow(
          icon: Icons.dark_mode_rounded,
          title: 'Appearance',
          value: 'System',
          onTap: onAppearance,
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

class _AccountActionCard extends StatelessWidget {
  const _AccountActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: destructive ? const Color(0xFFEAD1D4) : const Color(0xFFE5EBF0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: destructive ? const Color(0xFFD93C4E) : AppTheme.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: destructive ? const Color(0xFFD93C4E) : AppTheme.navy,
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

  String get _initials {
    final parts = profile.name.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return 'EV';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (profile.profileImageUrl.isNotEmpty
            ? profile.profileImageUrl
            : (user.photoURL ?? ''))
        .trim();
    final displayName = profile.name.trim().isEmpty ? 'Your name' : profile.name;
    final displayEmail = user.email?.trim().isNotEmpty == true
        ? user.email!
        : 'Email not available';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5EBF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A11263E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onEditPhoto,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFEBF4FF),
                  backgroundImage:
                      imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                  child: imageUrl.isEmpty
                      ? Text(
                          _initials,
                          style: const TextStyle(
                            fontSize: 28,
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.blue,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: uploading
                      ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayEmail,
                  style: const TextStyle(
                    color: AppTheme.mutedBlue,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: user.emailVerified
                        ? const Color(0xFFE8F9F1)
                        : const Color(0xFFFFF4D9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.emailVerified
                            ? Icons.verified_rounded
                            : Icons.info_outline_rounded,
                        size: 14,
                        color: user.emailVerified
                            ? const Color(0xFF1B9A67)
                            : const Color(0xFFB87B00),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.emailVerified ? 'Verified account' : 'Verification pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: user.emailVerified
                              ? const Color(0xFF1B9A67)
                              : const Color(0xFFB87B00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onEditProfile,
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
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
  const _PersonalInfoCard({
    required this.profile,
    required this.email,
    required this.createdAt,
    required this.onEdit,
  });

  final UserModel profile;
  final String email;
  final DateTime? createdAt;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRowData>[
      _InfoRowData(
        label: 'Full name',
        value: profile.name.trim().isEmpty ? 'Not provided' : profile.name,
      ),
      _InfoRowData(
        label: 'Email',
        value: email.trim().isEmpty ? 'Not provided' : email,
      ),
      _InfoRowData(
        label: 'Phone',
        value: profile.phone.trim().isEmpty ? 'Not provided' : profile.phone,
      ),
      _InfoRowData(
        label: 'Location',
        value: profile.city.trim().isEmpty ? 'Not provided' : profile.city,
      ),
      _InfoRowData(
        label: 'Joined',
        value: createdAt == null
            ? 'Not provided'
            : MaterialLocalizations.of(context).formatMediumDate(createdAt!),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EBF0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Account details',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return _InfoRow(
              label: row.label,
              value: row.value,
              isLast: index == rows.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _VehicleSummaryCard extends StatefulWidget {
  const _VehicleSummaryCard({required this.firestore, required this.vehicleId});

  final FirestoreService firestore;
  final String vehicleId;

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
                            vehicle.model.isEmpty ? 'Model not provided' : vehicle.model,
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
                    const Icon(Icons.bluetooth_rounded, color: AppTheme.mutedBlue),
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
                            : '${telemetry.range.round()} km',
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

class _InfoRowData {
  const _InfoRowData({required this.label, required this.value});

  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.mutedBlue,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 1, indent: 20, endIndent: 20),
    ],
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
          style: const TextStyle(
            color: AppTheme.mutedBlue,
            fontSize: 11,
          ),
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
              style: const TextStyle(
                color: AppTheme.mutedBlue,
                height: 1.5,
              ),
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

