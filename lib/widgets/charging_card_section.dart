import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/charging_card.dart';
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
    return StreamBuilder<ChargingCard?>(
      stream: firestoreService.watchChargingCard(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _CardMessage(
            icon: Icons.cloud_off_rounded,
            message: 'Charging card data could not be loaded from Firebase.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final card = snapshot.data;
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
              _ChargingCardVisual(card: card),
              if (card == null) ...[
                const SizedBox(height: 14),
                const _CardMessage(
                  icon: Icons.credit_card_off_rounded,
                  message:
                      'No charging card is linked to this account in Firebase.',
                ),
              ] else ...[
                const SizedBox(height: 16),
                _CardStatus(value: card.status ?? 'Not available'),
                _CardValue(
                  label: 'Linked vehicle',
                  value: card.linkedVehicleId ?? 'Not available',
                ),
                _CardValue(
                  label: 'Last recharge',
                  value: card.lastRechargeAmount == null
                      ? 'Not available'
                      : _currency(card.lastRechargeAmount!),
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
              ],
              const SizedBox(height: 10),
              _RecentTransactionSummary(
                uid: uid,
                firestoreService: firestoreService,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Recharge'),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Recharge is unavailable until a secure payment backend is connected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedBlue, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => _showTransactionHistory(context),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Transaction History'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionHistory(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: _TransactionHistory(
          uid: uid,
          firestoreService: firestoreService,
        ),
      ),
    );
  }
}

class _RecentTransactionSummary extends StatelessWidget {
  const _RecentTransactionSummary({
    required this.uid,
    required this.firestoreService,
  });

  final String uid;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChargingTransaction>>(
      stream: firestoreService.watchChargingTransactions(uid),
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
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent transaction',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              _CardValue(
                label: transaction.type ?? 'Type',
                value: transaction.amount == null
                    ? 'Not available'
                    : _currency(transaction.amount!),
              ),
              _CardValue(
                label: 'Station',
                value: transaction.stationName ?? 'Not available',
              ),
              _CardValue(
                label: 'Date',
                value: transaction.date == null
                    ? 'Not available'
                    : _dateLabel(transaction.date!),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChargingCardVisual extends StatelessWidget {
  const _ChargingCardVisual({required this.card});

  final ChargingCard? card;

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
              const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card?.cardType ?? 'Card type not available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.contactless_rounded, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            card?.maskedCardNumber ?? 'Card number not available',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'AVAILABLE BALANCE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            card?.balance == null ? 'Not available' : _currency(card!.balance!),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
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
    required this.firestoreService,
  });

  final String uid;
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
              stream: firestoreService.watchChargingTransactions(uid),
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
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF2F7),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: AppTheme.blue,
                        ),
                      ),
                      title: Text(transaction.type ?? 'Not available'),
                      subtitle: Text(
                        [
                          transaction.stationName ?? 'Not available',
                          transaction.date == null
                              ? 'Not available'
                              : _dateLabel(transaction.date!),
                        ].join(' · '),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            transaction.amount == null
                                ? 'Not available'
                                : _currency(transaction.amount!),
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(transaction.status ?? 'Not available'),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _currency(double amount) => '₹${amount.toStringAsFixed(2)}';

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
