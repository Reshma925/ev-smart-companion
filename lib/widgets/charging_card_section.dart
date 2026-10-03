import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../app_theme.dart';
import '../models/charging_card.dart';
import '../models/vehicle.dart';
import '../services/firestore_service.dart';

class ChargingCardSection extends StatelessWidget {
  const ChargingCardSection({
    required this.uid,
    required this.firestoreService,
    super.key,
  });

  final String uid;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Vehicle?>(
      stream: firestoreService.watchConnectedVehicle(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _CardMessage(
            icon: Icons.cloud_off_rounded,
            message:
                'Connected vehicle data could not be loaded from Firebase.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final vehicle = snapshot.data;
        if (vehicle == null) {
          return const _CardMessage(
            icon: Icons.directions_car_filled_outlined,
            message:
                'No active connected vehicle is linked to this Firebase account.',
          );
        }
        return StreamBuilder<ChargingCard?>(
          key: ValueKey(vehicle.id),
          stream: firestoreService.watchChargingCard(
            uid,
            vehicleId: vehicle.id,
          ),
          builder: (context, cardSnapshot) {
            if (cardSnapshot.hasError) {
              return const _CardMessage(
                icon: Icons.cloud_off_rounded,
                message:
                    'Charging card data could not be loaded from Firebase.',
              );
            }
            if (cardSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildCardContent(context, vehicle, cardSnapshot.data);
          },
        );
      },
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    Vehicle vehicle,
    ChargingCard? card,
  ) {
    final registerButton = FilledButton.icon(
      onPressed: () => _openCardForm(context, vehicle),
      icon: const Icon(Icons.add_card_rounded),
      label: const Text('Register Charging Card'),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'MY CHARGING CARD',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _CardValue(
            label: 'Connected vehicle',
            value:
                '${vehicle.model}\n${vehicle.registrationNumber}\n${vehicle.id}',
          ),
          const SizedBox(height: 12),
          if (card == null) ...[
            _LegacyCardMigration(
              key: ValueKey(vehicle.id),
              uid: uid,
              vehicle: vehicle,
              firestoreService: firestoreService,
              onRegister: () => registerButton,
              onNoLegacyCard: () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CardMessage(
                    icon: Icons.credit_card_off_rounded,
                    message: 'No charging card registered for this vehicle.',
                  ),
                  const SizedBox(height: 14),
                  registerButton,
                ],
              ),
            ),
          ] else ...[
            _ChargingCardVisual(card: card),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CARD DETAILS',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openCardForm(context, vehicle, card: card),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
            _CardValue(
              label: 'Card type',
              value: card.cardType ?? 'Not available',
            ),
            _CardValue(
              label: 'Card number',
              value: card.displayCardNumber ?? 'Not available',
            ),
            _CardValue(
              label: 'Card holder',
              value: card.cardHolderName ?? 'Not available',
            ),
            _CardValue(
              label: 'Vehicle',
              value:
                  '${vehicle.model}\n${vehicle.registrationNumber}\n${vehicle.id}',
            ),
            _CardValue(
              label: 'Currency',
              value: card.currency ?? 'Not available',
            ),
            _CardStatus(value: card.status ?? 'Not available'),
            _CardValue(
              label: 'Last recharge',
              value: card.lastRechargeAmount == null
                  ? 'Not available'
                  : _formatMoney(card.lastRechargeAmount!, card.currency),
            ),
            _CardValue(
              label: 'Last recharge date',
              value: card.lastRechargeDate == null
                  ? 'Not available'
                  : _dateLabel(card.lastRechargeDate!),
            ),
            _CardValue(
              label: 'Expiry',
              value: card.expiryDate == null
                  ? 'Not available'
                  : _dateLabel(card.expiryDate!),
            ),
            _CardValue(
              label: 'Registered',
              value: card.registeredAt == null
                  ? 'Not available'
                  : _dateLabel(card.registeredAt!),
            ),
            const SizedBox(height: 12),
            const Text(
              'TRANSACTION HISTORY',
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _RecentTransactionSummary(
              uid: uid,
              vehicleId: vehicle.id,
              firestoreService: firestoreService,
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _showRechargeMessage(context),
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Recharge'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => _showTransactionHistory(context, vehicle.id),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Transaction History'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCardForm(
    BuildContext context,
    Vehicle vehicle, {
    ChargingCard? card,
  }) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _ChargingCardForm(
          uid: uid,
          firestoreService: firestoreService,
          connectedVehicle: vehicle,
          existingCard: card,
        ),
      ),
    );
  }

  void _showRechargeMessage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recharge unavailable'),
        content: const Text(
          'Recharge payment service is not connected yet. Your balance has not been changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTransactionHistory(BuildContext context, String vehicleId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.76,
        child: _TransactionHistory(
          uid: uid,
          vehicleId: vehicleId,
          firestoreService: firestoreService,
        ),
      ),
    );
  }
}

class _LegacyCardMigration extends StatefulWidget {
  const _LegacyCardMigration({
    super.key,
    required this.uid,
    required this.vehicle,
    required this.firestoreService,
    required this.onRegister,
    required this.onNoLegacyCard,
  });

  final String uid;
  final Vehicle vehicle;
  final FirestoreService firestoreService;
  final Widget Function() onRegister;
  final Widget Function() onNoLegacyCard;

  @override
  State<_LegacyCardMigration> createState() => _LegacyCardMigrationState();
}

class _LegacyCardMigrationState extends State<_LegacyCardMigration> {
  bool _migrating = false;
  String? _error;
  late Future<Map<String, dynamic>?> _legacyCardSummary;

  @override
  void initState() {
    super.initState();
    _legacyCardSummary = _loadLegacyCardSummary();
  }

  Future<Map<String, dynamic>?> _loadLegacyCardSummary() =>
      widget.firestoreService.getLegacyChargingCardSummary(
        uid: widget.uid,
        vehicleId: widget.vehicle.id,
      );

  Future<void> _migrate() async {
    if (_migrating) return;
    setState(() {
      _migrating = true;
      _error = null;
    });
    try {
      await widget.firestoreService.migrateLegacyChargingCard(
        uid: widget.uid,
        vehicleId: widget.vehicle.id,
      );
    } catch (error, stackTrace) {
      debugPrint('Could not migrate legacy charging card: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _migrating = false;
          _error = error is FirebaseFunctionsException
              ? error.message
              : error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _legacyCardSummary,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardMessage(
                icon: Icons.cloud_off_rounded,
                message:
                    'Legacy card status could not be checked. Registration remains protected by Firestore rules.',
              ),
              const SizedBox(height: 14),
              widget.onRegister(),
            ],
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final legacyCard = snapshot.data;
        if (legacyCard == null) return widget.onNoLegacyCard();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardMessage(
              icon: Icons.sync_rounded,
              message:
                  'A card from the previous account-level structure was found. Migration copies only masked card details to the connected vehicle and keeps the original data unchanged.',
            ),
            if (legacyCard['cardType'] is String)
              _CardValue(
                label: 'Card type',
                value: legacyCard['cardType'] as String,
              ),
            if (legacyCard['maskedCardNumber'] is String)
              _CardValue(
                label: 'Card number',
                value: legacyCard['maskedCardNumber'] as String,
              ),
            if (legacyCard['cardHolderName'] is String)
              _CardValue(
                label: 'Card holder',
                value: legacyCard['cardHolderName'] as String,
              ),
            if (legacyCard['balance'] is num)
              _CardValue(
                label: 'Available balance',
                value: _formatMoney(
                  (legacyCard['balance'] as num).toDouble(),
                  legacyCard['currency'] as String?,
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _migrating ? null : _migrate,
              icon: _migrating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.move_down_rounded),
              label: const Text('Migrate Card to Connected Vehicle'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        );
      },
    );
  }
}

class _ChargingCardForm extends StatefulWidget {
  const _ChargingCardForm({
    required this.uid,
    required this.firestoreService,
    required this.connectedVehicle,
    this.existingCard,
  });

  final String uid;
  final FirestoreService firestoreService;
  final Vehicle connectedVehicle;
  final ChargingCard? existingCard;

  @override
  State<_ChargingCardForm> createState() => _ChargingCardFormState();
}

class _ChargingCardFormState extends State<_ChargingCardForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _typeController;
  late final TextEditingController _numberController;
  late final TextEditingController _holderController;
  String? _selectedVehicleId;
  DateTime? _expiryDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final card = widget.existingCard;
    _typeController = TextEditingController(text: card?.cardType ?? '');
    _numberController = TextEditingController();
    _holderController = TextEditingController(text: card?.cardHolderName ?? '');
    _expiryDate = card?.expiryDate;
    _selectedVehicleId = widget.connectedVehicle.id;
  }

  @override
  void dispose() {
    _typeController.dispose();
    _numberController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final vehicleId = _selectedVehicleId ?? widget.connectedVehicle.id;
    if (vehicleId.isEmpty) {
      setState(() => _error = 'Link a vehicle to your account first.');
      return;
    }
    if (_expiryDate == null) {
      setState(() => _error = 'Choose the card expiry date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existingCard == null) {
        await widget.firestoreService.registerChargingCard(
          uid: widget.uid,
          cardType: _typeController.text,
          cardNumber: _numberController.text,
          cardHolderName: _holderController.text,
          vehicleId: vehicleId,
          expiryDate: _expiryDate,
        );
      } else {
        await widget.firestoreService.updateChargingCardDetails(
          uid: widget.uid,
          cardType: _typeController.text,
          cardNumber: _numberController.text,
          cardHolderName: _holderController.text,
          vehicleId: vehicleId,
          expiryDate: _expiryDate,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Could not save charging-card details: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is StateError || error is ArgumentError
            ? error.toString().replaceFirst('Bad state: ', '')
            : 'Charging-card details could not be saved. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCard != null;
    final vehicle = widget.connectedVehicle;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Edit Charging Card' : 'Register Charging Card',
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your charging card details. Do not enter a CVV, PIN, or payment password.',
              style: TextStyle(color: AppTheme.mutedBlue),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _typeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Card type',
                hintText: 'For example, EV charging card',
              ),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numberController,
              decoration: const InputDecoration(
                labelText: 'Card number',
                hintText: 'Enter a number, or leave empty to keep it',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (!isEditing && text.isEmpty) {
                  return 'Enter a card number.';
                }
                if (text.isNotEmpty &&
                    !RegExp(
                      r'^[A-Za-z0-9]{4,32}$',
                    ).hasMatch(text.replaceAll(RegExp(r'[\s-]'), ''))) {
                  return 'Enter a valid card number.';
                }
                return null;
              },
            ),
            if (isEditing) ...[
              const SizedBox(height: 5),
              const Text(
                'Leave the card number blank to keep the existing masked number. A replacement number is stored only in masked form.',
                style: TextStyle(color: AppTheme.mutedBlue, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _holderController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Card holder name'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Expiry date'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _expiryDate == null
                          ? 'Not set'
                          : _dateLabel(_expiryDate!),
                      style: const TextStyle(color: AppTheme.navy),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final now = DateTime.now();
                            final selected = await showDatePicker(
                              context: context,
                              initialDate:
                                  _expiryDate ??
                                  DateTime(now.year + 1, now.month, now.day),
                              firstDate: DateTime(now.year, now.month, now.day),
                              lastDate: DateTime(now.year + 30),
                            );
                            if (selected != null && mounted) {
                              setState(() => _expiryDate = selected);
                            }
                          },
                    child: const Text('Choose'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedVehicleId ?? vehicle.id,
              decoration: const InputDecoration(
                labelText: 'Vehicle association',
              ),
              items: [
                DropdownMenuItem(
                  value: vehicle.id,
                  child: Text(
                    '${vehicle.model} · ${vehicle.registrationNumber} · ${vehicle.id}',
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _selectedVehicleId = value;
                    }),
            ),
            if (!isEditing) ...[
              const SizedBox(height: 10),
              Text(
                'New cards start with a Firebase balance of ${_currency(0, 'INR')}.',
                style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Save Changes' : 'Register Card'),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}

class _RecentTransactionSummary extends StatelessWidget {
  const _RecentTransactionSummary({
    required this.uid,
    required this.vehicleId,
    required this.firestoreService,
  });

  final String uid;
  final String vehicleId;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChargingTransaction>>(
      stream: firestoreService.watchChargingTransactions(
        uid,
        vehicleId: vehicleId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _CardMessage(
            icon: Icons.cloud_off_rounded,
            message: 'Recent transaction data could not be loaded.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        final transactions = snapshot.data ?? const [];
        if (transactions.isEmpty) {
          return const _CardMessage(
            icon: Icons.receipt_long_rounded,
            message: 'No transactions yet.',
          );
        }
        final transaction = transactions.first;
        return _TransactionTile(transaction: transaction);
      },
    );
  }
}

class _ChargingCardVisual extends StatelessWidget {
  const _ChargingCardVisual({required this.card});

  final ChargingCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12395A), Color(0xFF167A92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.cardType ?? 'Charging Card',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.contactless_rounded, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            card.displayCardNumber ?? 'Not available',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CARD HOLDER',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.cardHolderName ?? 'Not available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.balance == null
                        ? 'Not available'
                        : _formatMoney(card.balance!, card.currency),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardValue extends StatelessWidget {
  const _CardValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.mutedBlue),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardStatus extends StatelessWidget {
  const _CardStatus({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = value.toLowerCase();
    final color = normalized == 'active'
        ? const Color(0xFF16845B)
        : normalized == 'inactive' || normalized == 'blocked'
        ? const Color(0xFFB44343)
        : AppTheme.mutedBlue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Expanded(
            child: Text('Status', style: TextStyle(color: AppTheme.mutedBlue)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: color),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardMessage extends StatelessWidget {
  const _CardMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.mutedBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.mutedBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionHistory extends StatelessWidget {
  const _TransactionHistory({
    required this.uid,
    required this.vehicleId,
    required this.firestoreService,
  });

  final String uid;
  final String vehicleId;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Transaction History',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<ChargingTransaction>>(
              stream: firestoreService.watchChargingTransactions(
                uid,
                vehicleId: vehicleId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _CardMessage(
                    icon: Icons.cloud_off_rounded,
                    message:
                        'Transaction history could not be loaded from Firebase.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final transactions = snapshot.data ?? const [];
                if (transactions.isEmpty) {
                  return const _CardMessage(
                    icon: Icons.receipt_long_rounded,
                    message: 'No transactions yet.',
                  );
                }
                return ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _TransactionTile(transaction: transactions[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final ChargingTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final amount = transaction.amount;
    final isCredit = transaction.type?.toLowerCase() == 'credit';
    final isDebit = transaction.type?.toLowerCase() == 'debit';
    final timestamp = transaction.date;
    final details = <String>[
      'Date and time: ${timestamp == null ? 'Not available' : '${_dateLabel(timestamp)} · ${_timeLabel(timestamp)}'}',
      'Reference: ${transaction.sessionReferenceId ?? transaction.id}',
      'Card: ${transaction.cardId ?? 'Not available'}',
      'Station: ${transaction.stationName ?? 'Not available'}',
      'Operator: ${transaction.operator ?? 'Not available'}',
      'Vehicle: ${transaction.vehicleId ?? 'Not available'}',
      'Balance before: ${transaction.balanceBefore == null ? 'Not available' : _formatMoney(transaction.balanceBefore!, transaction.currency)}',
      'Balance after: ${transaction.balanceAfter == null ? 'Not available' : _formatMoney(transaction.balanceAfter!, transaction.currency)}',
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF2F7),
        child: Icon(
          isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: AppTheme.blue,
        ),
      ),
      title: Text(
        transaction.description ??
            (transaction.type == null
                ? 'Charging transaction'
                : '${transaction.type![0].toUpperCase()}${transaction.type!.substring(1)}'),
        style: const TextStyle(
          color: AppTheme.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(details.join('\n')),
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount == null
                ? 'Not available'
                : '${isCredit
                      ? '+'
                      : isDebit
                      ? '-'
                      : ''}${_formatMoney(amount, transaction.currency)}',
            style: const TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(transaction.status ?? 'Not available'),
        ],
      ),
    );
  }
}

String _currency(double amount, String currency) {
  final symbol = switch (currency.toUpperCase()) {
    'INR' => '₹',
    'USD' => r'$',
    'EUR' => '€',
    _ => '$currency ',
  };
  return '$symbol${amount.toStringAsFixed(2)}';
}

String _formatMoney(double amount, String? currency) =>
    currency == null || currency.trim().isEmpty
    ? amount.toStringAsFixed(2)
    : _currency(amount, currency);

String _dateLabel(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')} '
      '${months[date.month - 1]} ${date.year}';
}

String _timeLabel(DateTime value) {
  final time = value.toLocal();
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
