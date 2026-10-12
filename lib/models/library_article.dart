import 'package:flutter/material.dart';

import '../config/color_config.dart';

enum LibraryCategory {
  foods('foods', 'Foods', Icons.eco_outlined),
  toDo('to-do', 'To Do', Icons.checklist_rounded),
  toAvoid('to-avoid', 'To Avoid', Icons.do_not_disturb_alt_outlined),
  bestPractices(
    'best-practices',
    'Best Practices',
    Icons.auto_awesome_outlined,
  );

  const LibraryCategory(this.id, this.label, this.icon);

  /// As written in an article's `category:` line.
  final String id;
  final String label;
  final IconData icon;

  static LibraryCategory fromId(String id) =>
      values.firstWhere((c) => c.id == id, orElse: () => bestPractices);

  Color color(AppColors c) => switch (this) {
    LibraryCategory.foods => c.libraryFoods,
    LibraryCategory.toDo => c.libraryToDo,
    LibraryCategory.toAvoid => c.libraryToAvoid,
    LibraryCategory.bestPractices => c.libraryBestPractices,
  };
}

class LibraryArticle {
  const LibraryArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.minutes,
    this.body,
  });

  factory LibraryArticle.fromJson(Map<String, dynamic> j) => LibraryArticle(
    id: j['id'] as String,
    title: j['title'] as String,
    category: LibraryCategory.fromId(j['category'] as String),
    summary: j['summary'] as String,
    minutes: j['minutes'] as int,
    body: j['body'] as String?,
  );

  final String id;
  final String title;
  final LibraryCategory category;
  final String summary;
  final int minutes; // reading time

  /// Markdown. Only present when a single article is fetched.
  final String? body;
}
