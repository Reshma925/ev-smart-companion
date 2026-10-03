import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/learning_catalog.dart';
import '../models/learning_lesson.dart';
import '../models/vehicle.dart';
import '../models/vehicle_telemetry.dart';
import '../services/distance_unit_service.dart';
import '../services/learning_assistant_service.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({
    super.key,
    required this.vehicleStream,
    required this.telemetryStreamFor,
    this.assistant,
    this.distanceUnit = DistanceUnitService.km,
  });

  final Stream<Vehicle?> vehicleStream;
  final Stream<VehicleData?> Function(String vehicleId) telemetryStreamFor;
  final EvLearningAssistant? assistant;
  final String distanceUnit;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final TextEditingController _questionController = TextEditingController();
  final Set<String> _completedLessonIds = {};
  late final EvLearningAssistant _assistant =
      widget.assistant ?? FirebaseLearningAssistantService();
  String? _answer;
  String? _assistantError;
  bool _asking = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask(LearningVehicleContext context) async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() {
        _answer = null;
        _assistantError = 'Enter a question before asking the EV assistant.';
      });
      return;
    }
    if (question.length > 2000) {
      setState(() {
        _answer = null;
        _assistantError = 'Please keep your question under 2,000 characters.';
      });
      return;
    }
    FocusScope.of(this.context).unfocus();
    setState(() {
      _asking = true;
      _answer = null;
      _assistantError = null;
    });
    try {
      final answer = await _assistant.ask(question, context: context);
      if (!mounted) return;
      setState(() {
        _asking = false;
        _answer = answer;
      });
    } on LearningAssistantException catch (error) {
      if (!mounted) return;
      setState(() {
        _asking = false;
        _assistantError = error.message;
      });
    } catch (error, stackTrace) {
      debugPrint('EV learning assistant failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _asking = false;
        _assistantError =
            'AI assistant is temporarily unavailable. Please try again.';
      });
    }
  }

  void _openCategory(LearningCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearningCategoryPage(
          category: category,
          completedLessonIds: _completedLessonIds,
          onLessonCompleted: (lesson) {
            setState(() => _completedLessonIds.add(lesson.id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: StreamBuilder<Vehicle?>(
        stream: widget.vehicleStream,
        builder: (context, vehicleSnapshot) {
          final vehicle = vehicleSnapshot.data;
          if (vehicle == null) {
            return _buildContent(
              vehicle: null,
              telemetry: null,
              vehicleUnavailable:
                  vehicleSnapshot.hasError ||
                  vehicleSnapshot.connectionState != ConnectionState.waiting,
              telemetryUnavailable: false,
            );
          }
          return StreamBuilder<VehicleData?>(
            key: ValueKey(vehicle.id),
            stream: widget.telemetryStreamFor(vehicle.id),
            builder: (context, telemetrySnapshot) => _buildContent(
              vehicle: vehicle,
              telemetry: telemetrySnapshot.data,
              vehicleUnavailable: false,
              telemetryUnavailable:
                  telemetrySnapshot.hasError ||
                  telemetrySnapshot.connectionState != ConnectionState.waiting,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required Vehicle? vehicle,
    required VehicleData? telemetry,
    required bool vehicleUnavailable,
    required bool telemetryUnavailable,
  }) {
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text(
          'LEARN',
          style: TextStyle(
            color: AppTheme.blue,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Understand your EV',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Learn how your vehicle works and how to drive smarter.',
          style: TextStyle(color: AppTheme.mutedBlue, fontSize: 15),
        ),
        const SizedBox(height: 20),
        _assistantCard(
          LearningVehicleContext(vehicle: vehicle, telemetry: telemetry),
        ),
        if (vehicle != null && telemetry != null) ...[
          const SizedBox(height: 14),
          _vehicleSnapshot(vehicle, telemetry),
        ] else if (vehicleUnavailable || telemetryUnavailable) ...[
          const SizedBox(height: 12),
          _contextNotice(
            vehicle == null
                ? 'Current vehicle information is unavailable. You can still explore lessons and ask general EV questions.'
                : 'Live vehicle telemetry is unavailable. You can still explore lessons and ask general EV questions.',
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Explore learning paths',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 750 ? 3 : 2;
            return GridView.builder(
              itemCount: learningCategories.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 172,
              ),
              itemBuilder: (context, index) =>
                  _categoryCard(learningCategories[index]),
            );
          },
        ),
      ],
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: content,
      ),
    );
  }

  Widget _assistantCard(LearningVehicleContext vehicleContext) {
    const suggestions = [
      'Why is my range lower today?',
      'What is regenerative braking?',
      'How does DC fast charging work?',
      'How can I improve my range?',
      'What does battery health mean?',
    ];
    return Card(
      elevation: 0,
      color: const Color(0xFFEDF5FC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD5E6F5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.blue),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASK YOUR EV ASSISTANT',
                        style: TextStyle(
                          color: AppTheme.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Have a question about your EV?',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _questionController,
              minLines: 1,
              maxLines: 3,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(vehicleContext),
              decoration: InputDecoration(
                hintText: 'Ask an EV learning question…',
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Ask the EV assistant',
                  onPressed: _asking ? null : () => _ask(vehicleContext),
                  icon: _asking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ),
            if (_asking) ...[
              const SizedBox(height: 8),
              const Text(
                'Thinking...',
                key: ValueKey('learn-assistant-thinking'),
                style: TextStyle(
                  color: AppTheme.mutedBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final question in suggestions)
                  ActionChip(
                    label: Text(question),
                    onPressed: _asking
                        ? null
                        : () {
                            _questionController.text = question;
                            _ask(vehicleContext);
                          },
                  ),
              ],
            ),
            if (_assistantError != null) ...[
              const SizedBox(height: 12),
              _responseBox(
                _assistantError!,
                icon: Icons.info_outline_rounded,
                error: true,
              ),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 12),
              _responseBox(
                _answer!,
                icon: Icons.chat_bubble_outline_rounded,
                error: false,
              ),
            ],
            const SizedBox(height: 9),
            const Text(
              'For learning only — not vehicle diagnostics, safety advice or vehicle control.',
              style: TextStyle(color: AppTheme.mutedBlue, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _responseBox(
    String text, {
    required IconData icon,
    required bool error,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFF5F2) : Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: error ? Colors.deepOrange : AppTheme.blue,
          ),
          const SizedBox(width: 9),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }

  Widget _vehicleSnapshot(Vehicle vehicle, VehicleData telemetry) {
    final range = DistanceUnitService.format(
      telemetry.range,
      widget.distanceUnit,
      decimals: 0,
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD9E0E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.electric_car_rounded, color: AppTheme.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your ${vehicle.model}',
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${telemetry.battery.toStringAsFixed(0)}% · $range estimated',
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextNotice(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F6FA),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 13),
    ),
  );

  Widget _categoryCard(LearningCategory category) {
    final completed = category.lessons
        .where((lesson) => _completedLessonIds.contains(lesson.id))
        .length;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFFD9E0E8)),
      ),
      child: InkWell(
        onTap: () => _openCategory(category),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(category.icon, color: AppTheme.blue, size: 23),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.mutedBlue,
                    size: 18,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 12),
              ),
              const SizedBox(height: 7),
              Text(
                '$completed/${category.lessons.length} lessons complete',
                style: const TextStyle(
                  color: AppTheme.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LearningCategoryPage extends StatefulWidget {
  const LearningCategoryPage({
    super.key,
    required this.category,
    required this.completedLessonIds,
    required this.onLessonCompleted,
  });

  final LearningCategory category;
  final Set<String> completedLessonIds;
  final ValueChanged<LearningLesson> onLessonCompleted;

  @override
  State<LearningCategoryPage> createState() => _LearningCategoryPageState();
}

class _LearningCategoryPageState extends State<LearningCategoryPage> {
  late final Set<String> _completedIds = {...widget.completedLessonIds};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleCase(widget.category.title))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Text(
            widget.category.subtitle,
            style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 15),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < widget.category.lessons.length; index++)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Color(0xFFD9E0E8)),
              ),
              child: ListTile(
                leading: Icon(
                  _completedIds.contains(widget.category.lessons[index].id)
                      ? Icons.check_circle_rounded
                      : widget.category.lessons[index].icon,
                  color:
                      _completedIds.contains(widget.category.lessons[index].id)
                      ? Colors.green
                      : AppTheme.blue,
                ),
                title: Text(
                  widget.category.lessons[index].title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  widget.category.lessons[index].introduction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LearningLessonPage(
                      category: widget.category,
                      lessonIndex: index,
                      isCompleted: _completedIds.contains(
                        widget.category.lessons[index].id,
                      ),
                      onLessonCompleted: _completeLesson,
                      completedLessonIds: _completedIds,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _completeLesson(LearningLesson lesson) {
    setState(() => _completedIds.add(lesson.id));
    widget.onLessonCompleted(lesson);
  }

  static String _titleCase(String value) => value
      .toLowerCase()
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class LearningLessonPage extends StatefulWidget {
  const LearningLessonPage({
    super.key,
    required this.category,
    required this.lessonIndex,
    required this.isCompleted,
    required this.onLessonCompleted,
    required this.completedLessonIds,
  });

  final LearningCategory category;
  final int lessonIndex;
  final bool isCompleted;
  final ValueChanged<LearningLesson> onLessonCompleted;
  final Set<String> completedLessonIds;

  @override
  State<LearningLessonPage> createState() => _LearningLessonPageState();
}

class _LearningLessonPageState extends State<LearningLessonPage> {
  late bool _isCompleted = widget.isCompleted;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.category.lessons[widget.lessonIndex];
    final next = widget.lessonIndex + 1 < widget.category.lessons.length
        ? widget.category.lessons[widget.lessonIndex + 1]
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FB),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(lesson.icon, color: AppTheme.blue, size: 37),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                lesson.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lesson.introduction,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 16),
              ),
              const SizedBox(height: 22),
              _lessonPanel(
                context,
                child: Text(
                  lesson.explanation,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    height: 1.55,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              _lessonPanel(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Key points',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final point in lesson.keyPoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.blue,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (lesson.practicalTip != null) ...[
                const SizedBox(height: 13),
                _lessonPanel(
                  context,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: AppTheme.blue),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          lesson.practicalTip!,
                          style: const TextStyle(
                            color: AppTheme.navy,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _isCompleted
                    ? null
                    : () {
                        widget.onLessonCompleted(lesson);
                        setState(() => _isCompleted = true);
                      },
                icon: Icon(
                  _isCompleted ? Icons.check_circle : Icons.done_rounded,
                ),
                label: Text(
                  _isCompleted ? 'Lesson completed' : 'Mark as complete',
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => LearningLessonPage(
                        category: widget.category,
                        lessonIndex: widget.lessonIndex + 1,
                        isCompleted: widget.completedLessonIds.contains(
                          next.id,
                        ),
                        onLessonCompleted: widget.onLessonCompleted,
                        completedLessonIds: widget.completedLessonIds,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Next lesson: ${next.title}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _lessonPanel(BuildContext context, {required Widget child}) => Card(
    elevation: 0,
    color: const Color(0xFFF7F9FC),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFD9E0E8)),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
