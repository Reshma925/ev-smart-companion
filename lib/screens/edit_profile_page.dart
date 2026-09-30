import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});

  final UserModel profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _firestore = FirestoreService();
  final _auth = AuthService();
  bool _saving = false;
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile.name;
    _phoneController.text = widget.profile.phone;
    _cityController.text = widget.profile.city;
    _selectedDateOfBirth = widget.profile.dateOfBirth;
    if (_selectedDateOfBirth != null) {
      _dateOfBirthController.text = _formatDate(_selectedDateOfBirth!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _selectedDateOfBirth = picked;
      _dateOfBirthController.text = _formatDate(picked);
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.profile.uid) {
      _showMessage('Your session changed. Sign in again before editing.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _firestore.updateUserProfile(
        uid: user.uid,
        name: _nameController.text,
        phone: _phoneController.text,
        city: _cityController.text,
        dateOfBirth: _selectedDateOfBirth,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(_auth.messageFor(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    appBar: AppBar(
      title: const Text('Edit profile'),
      backgroundColor: AppTheme.background,
      scrolledUnderElevation: 0,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFE5EBF0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal details',
                          style: TextStyle(
                            color: AppTheme.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Update the profile information stored in your Firestore account. Your sign-in email remains managed by Firebase Authentication.',
                          style: TextStyle(
                            color: AppTheme.mutedBlue,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) {
                            final phone = value?.trim() ?? '';
                            if (phone.isEmpty) return null;
                            final digits = phone.replaceAll(RegExp(r'\D'), '');
                            if (!RegExp(r'^[+()\d\s-]+$').hasMatch(phone) ||
                                digits.length < 7 ||
                                digits.length > 15) {
                              return 'Enter a valid phone number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _cityController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'City / location',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _dateOfBirthController,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: const InputDecoration(
                            labelText: 'Date of birth',
                            prefixIcon: Icon(Icons.calendar_month_outlined),
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'Saving…' : 'Save changes'),
                          ),
                        ),
                      ],
                    ),
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
