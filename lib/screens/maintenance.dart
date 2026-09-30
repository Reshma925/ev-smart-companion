import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/vehicle.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('vehicles')
      .doc(widget.vehicle.id)
      .collection('maintenance');

  Stream<QuerySnapshot<Map<String, dynamic>>> get _maintenanceStream => _collection
      .orderBy('serviceDate', descending: true)
      .snapshots();

  Future<void> _addRecord() async {
    final formKey = GlobalKey<FormState>();
    final serviceTypeController = TextEditingController();
    final serviceCenterController = TextEditingController();
    final costController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? serviceDate;
    DateTime? nextServiceDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add maintenance record'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: serviceTypeController,
                    decoration: const InputDecoration(labelText: 'Service type'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Enter a service type.'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        serviceDate = picked;
                        setDialogState(() {});
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Service date'),
                      child: Text(
                        serviceDate == null
                            ? 'Select date'
                            : '${serviceDate!.day}/${serviceDate!.month}/${serviceDate!.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        nextServiceDate = picked;
                        setDialogState(() {});
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Next service date'),
                      child: Text(
                        nextServiceDate == null
                            ? 'Select date'
                            : '${nextServiceDate!.day}/${nextServiceDate!.month}/${nextServiceDate!.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: serviceCenterController,
                    decoration: const InputDecoration(labelText: 'Service center'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cost (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate() && serviceDate != null) {
                  Navigator.pop(dialogContext, true);
                } else if (serviceDate == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please choose a service date.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final record = {
      'serviceType': serviceTypeController.text.trim(),
      'serviceDate': Timestamp.fromDate(serviceDate!),
      'nextServiceDate': nextServiceDate == null ? null : Timestamp.fromDate(nextServiceDate!),
      'serviceCenter': serviceCenterController.text.trim(),
      'cost': costController.text.trim(),
      'notes': notesController.text.trim(),
      'status': 'Completed',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _collection.add(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maintenance record saved.')),
    );
  }

  void _showRecordDetails(Map<String, dynamic> data) {
    final serviceDate = data['serviceDate'] is Timestamp
        ? (data['serviceDate'] as Timestamp).toDate()
        : null;
    final nextServiceDate = data['nextServiceDate'] is Timestamp
        ? (data['nextServiceDate'] as Timestamp).toDate()
        : null;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (data['serviceType'] as String?) ?? 'Maintenance',
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (serviceDate != null)
                _DetailRow(
                  label: 'Service date',
                  value: '${serviceDate.day}/${serviceDate.month}/${serviceDate.year}',
                ),
              if (nextServiceDate != null)
                _DetailRow(
                  label: 'Next service',
                  value: '${nextServiceDate.day}/${nextServiceDate.month}/${nextServiceDate.year}',
                ),
              if ((data['serviceCenter'] as String? ?? '').isNotEmpty)
                _DetailRow(label: 'Service center', value: data['serviceCenter'] as String),
              if ((data['cost'] as String? ?? '').isNotEmpty)
                _DetailRow(label: 'Cost', value: data['cost'] as String),
              if ((data['notes'] as String? ?? '').isNotEmpty)
                _DetailRow(label: 'Notes', value: data['notes'] as String),
              _DetailRow(label: 'Status', value: (data['status'] as String?) ?? 'Completed'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
        backgroundColor: AppTheme.background,
      ),
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecord,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add maintenance'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _maintenanceStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load maintenance records',
              message: 'Please check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!.docs;
          if (records.isEmpty) {
            return _EmptyState(
              icon: Icons.build_rounded,
              title: 'No maintenance records yet',
              message: 'Add the first service record for this vehicle to begin tracking maintenance history.',
              actionLabel: 'Add record',
              onAction: _addRecord,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE5EBF0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vehicle.model,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.vehicle.registrationNumber.isEmpty
                          ? 'Registration not provided'
                          : widget.vehicle.registrationNumber,
                      style: const TextStyle(color: AppTheme.mutedBlue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Maintenance timeline',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...records.map((doc) {
                final data = doc.data();
                final serviceType = (data['serviceType'] as String?) ?? 'Service';
                final status = (data['status'] as String?) ?? 'Completed';
                final serviceDate = data['serviceDate'] is Timestamp
                    ? (data['serviceDate'] as Timestamp).toDate()
                    : null;
                final nextServiceDate = data['nextServiceDate'] is Timestamp
                    ? (data['nextServiceDate'] as Timestamp).toDate()
                    : null;
                final color = status.toLowerCase().contains('upcoming')
                    ? const Color(0xFF2388D9)
                    : const Color(0xFF1EA76A);

                return InkWell(
                  onTap: () => _showRecordDetails(data),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5EBF0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.build_rounded,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                serviceType,
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              if (serviceDate != null)
                                Text(
                                  'Service date: ${serviceDate.day}/${serviceDate.month}/${serviceDate.year}',
                                  style: const TextStyle(
                                    color: AppTheme.mutedBlue,
                                    fontSize: 12,
                                  ),
                                ),
                              if (nextServiceDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Next service: ${nextServiceDate.day}/${nextServiceDate.month}/${nextServiceDate.year}',
                                    style: const TextStyle(
                                      color: AppTheme.mutedBlue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.mutedBlue,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.mutedBlue, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.mutedBlue, height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
