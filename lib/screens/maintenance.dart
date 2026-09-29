import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';

class ServiceTask {
  final String id;
  final String name;
  final IconData icon;
  final int everyMonths;
  final int sampleDaysAgo; // used only to create sample data the first time
  const ServiceTask(this.id, this.name, this.icon, this.everyMonths, this.sampleDaysAgo);
}

const tasks = [
  ServiceTask('tyres', 'Tyre Rotation', Icons.tire_repair, 6, 200),
  ServiceTask('brakes', 'Brake Inspection', Icons.car_repair, 12, 340),
  ServiceTask('cabinFilter', 'Cabin Air Filter', Icons.air, 12, 100),
  ServiceTask('coolant', 'Battery Coolant Check', Icons.ac_unit, 24, 400),
  ServiceTask('battery12v', '12V Battery Check', Icons.battery_charging_full, 12, 380),
  ServiceTask('wipers', 'Wiper Blades', Icons.water_drop_outlined, 12, 150),
  ServiceTask('software', 'Software Update', Icons.system_update, 6, 30),
];

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  // Each vehicle has its own maintenance records in Firebase
  late final col = FirebaseFirestore.instance
      .collection('vehicles')
      .doc(widget.vehicle.registrationNumber)
      .collection('maintenance');
  late final stream = col.snapshots();

  @override
  void initState() {
    super.initState();
    addSampleDataIfEmpty();
  }

  // Creates sample "last done" dates the first time this vehicle opens the page
  Future<void> addSampleDataIfEmpty() async {
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final now = DateTime.now();
    for (final t in tasks) {
      await col.doc(t.id).set({
        'lastDone': Timestamp.fromDate(now.subtract(Duration(days: t.sampleDaysAgo))),
      });
    }
  }

  // Saves today's date when the user taps Done
  Future<void> markDone(ServiceTask t) async {
    await col.doc(t.id).set({'lastDone': Timestamp.now()});
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${t.name} marked as done')));
  }

  String formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load maintenance: ${snap.error}'));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Last done date for each task, read from Firebase
          final lastDone = {
            for (final doc in snap.data!.docs)
              doc.id: (doc.data()['lastDone'] as Timestamp).toDate(),
          };
          final now = DateTime.now();
          var overdue = 0;
          var dueSoon = 0;

          final cards = <Widget>[];
          for (final t in tasks) {
            final last = lastDone[t.id] ?? now;
            final due = DateTime(last.year, last.month + t.everyMonths, last.day);
            final daysLeft = due.difference(now).inDays;

            Color color;
            String status;
            if (daysLeft < 0) {
              overdue++;
              color = Colors.red;
              status = 'Overdue by ${-daysLeft} days';
            } else if (daysLeft <= 30) {
              dueSoon++;
              color = Colors.orange;
              status = 'Due in $daysLeft days';
            } else {
              color = Colors.green;
              status = 'Due in $daysLeft days';
            }

            cards.add(Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(t.icon, color: AppTheme.blue),
                title: Text(t.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.navy)),
                subtitle: Text(
                  'Every ${t.everyMonths} months · Last done ${formatDate(last)}\n$status',
                ),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: () => markDone(t),
                  child: const Text('Done'),
                ),
                shape: Border(left: BorderSide(color: color, width: 5)),
              ),
            ));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: overdue > 0 ? const Color(0xFFFFEBEB) : const Color(0xFFE5F8EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(overdue > 0 ? Icons.warning_amber_rounded : Icons.check_circle,
                        color: overdue > 0 ? Colors.red : Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        overdue == 0 && dueSoon == 0
                            ? 'All maintenance is up to date'
                            : '$overdue overdue · $dueSoon due soon',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: AppTheme.navy),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.vehicle.model,
                  style: const TextStyle(color: AppTheme.mutedBlue)),
              const SizedBox(height: 16),

              // Service checklist
              ...cards,

              // Learning card
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.school, color: AppTheme.blue),
                      SizedBox(width: 8),
                      Text('Why EVs need less maintenance',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: AppTheme.navy)),
                    ]),
                    SizedBox(height: 8),
                    Text(
                      'Electric vehicles have no engine oil, spark plugs, or '
                      'gearbox oil to change, and far fewer moving parts. '
                      'Regenerative braking also means the brake pads wear out '
                      'more slowly. Tyres, brakes, the cabin filter, and battery '
                      'cooling still need regular checks.',
                      style: TextStyle(color: AppTheme.navy, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}