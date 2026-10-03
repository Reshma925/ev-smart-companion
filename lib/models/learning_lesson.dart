import 'package:flutter/material.dart';

class LearningCategory {
  const LearningCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.lessons,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<LearningLesson> lessons;
}

class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.title,
    required this.introduction,
    required this.explanation,
    required this.keyPoints,
    required this.icon,
    this.practicalTip,
  });

  final String id;
  final String title;
  final String introduction;
  final String explanation;
  final List<String> keyPoints;
  final IconData icon;
  final String? practicalTip;
}
