import 'package:flutter/material.dart';

/// What the passages are about. The player picks one before each round.
enum LinesCategory {
  cybersecurity,
  networking,
  programming,
  medicine,
  novels;

  String get label => switch (this) {
    cybersecurity => 'Cybersecurity',
    networking => 'Networking',
    programming => 'Programming',
    medicine => 'Medicine',
    novels => 'Art: Novels',
  };

  IconData get icon => switch (this) {
    cybersecurity => Icons.shield_outlined,
    networking => Icons.lan_outlined,
    programming => Icons.code_rounded,
    medicine => Icons.medical_services_outlined,
    novels => Icons.auto_stories_outlined,
  };

  /// Where the passages come from, for the picker.
  String get source => switch (this) {
    novels => 'Classic novels from Project Gutenberg',
    _ => 'Articles from Wikipedia',
  };

  /// Wikipedia categories to draw articles from. Empty for novels, which
  /// come from Project Gutenberg instead.
  List<String> get wikiCategories => switch (this) {
    cybersecurity => const [
      'Computer security',
      'Malware',
      'Cryptography',
      'Computer security exploits',
      'Computer network security',
    ],
    networking => const [
      'Computer networking',
      'Network protocols',
      'Internet protocols',
      'Routing',
      'Wireless networking',
    ],
    programming => const [
      'Programming languages',
      'Programming paradigms',
      'Software design patterns',
      'Algorithms',
      'Compilers',
    ],
    medicine => const [
      'Infectious diseases',
      'Human anatomy',
      'Medical tests',
      'Cardiology',
      'Neurology',
    ],
    novels => const [],
  };
}

/// A public-domain novel on Project Gutenberg.
typedef GutenbergBook = ({int id, String title, String author});

/// Novels to sample from. All on Project Gutenberg, all in the public domain.
const gutenbergBooks = <GutenbergBook>[
  (id: 1342, title: 'Pride and Prejudice', author: 'Jane Austen'),
  (id: 158, title: 'Emma', author: 'Jane Austen'),
  (id: 161, title: 'Sense and Sensibility', author: 'Jane Austen'),
  (id: 105, title: 'Persuasion', author: 'Jane Austen'),
  (id: 84, title: 'Frankenstein', author: 'Mary Shelley'),
  (id: 11, title: "Alice's Adventures in Wonderland", author: 'Lewis Carroll'),
  (
    id: 1661,
    title: 'The Adventures of Sherlock Holmes',
    author: 'Arthur Conan Doyle',
  ),
  (id: 2097, title: 'The Sign of the Four', author: 'Arthur Conan Doyle'),
  (id: 2701, title: 'Moby-Dick', author: 'Herman Melville'),
  (id: 98, title: 'A Tale of Two Cities', author: 'Charles Dickens'),
  (id: 1400, title: 'Great Expectations', author: 'Charles Dickens'),
  (id: 730, title: 'Oliver Twist', author: 'Charles Dickens'),
  (id: 345, title: 'Dracula', author: 'Bram Stoker'),
  (id: 1260, title: 'Jane Eyre', author: 'Charlotte Brontë'),
  (id: 768, title: 'Wuthering Heights', author: 'Emily Brontë'),
  (id: 174, title: 'The Picture of Dorian Gray', author: 'Oscar Wilde'),
  (id: 2554, title: 'Crime and Punishment', author: 'Fyodor Dostoevsky'),
  (id: 1184, title: 'The Count of Monte Cristo', author: 'Alexandre Dumas'),
  (id: 1257, title: 'The Three Musketeers', author: 'Alexandre Dumas'),
  (id: 76, title: 'Adventures of Huckleberry Finn', author: 'Mark Twain'),
  (id: 74, title: 'The Adventures of Tom Sawyer', author: 'Mark Twain'),
  (id: 120, title: 'Treasure Island', author: 'Robert Louis Stevenson'),
  (
    id: 43,
    title: 'Strange Case of Dr Jekyll and Mr Hyde',
    author: 'Robert Louis Stevenson',
  ),
  (id: 36, title: 'The War of the Worlds', author: 'H. G. Wells'),
  (id: 35, title: 'The Time Machine', author: 'H. G. Wells'),
  (id: 219, title: 'Heart of Darkness', author: 'Joseph Conrad'),
  (id: 145, title: 'Middlemarch', author: 'George Eliot'),
  (id: 514, title: 'Little Women', author: 'Louisa May Alcott'),
  (id: 64317, title: 'The Great Gatsby', author: 'F. Scott Fitzgerald'),
  (id: 25344, title: 'The Scarlet Letter', author: 'Nathaniel Hawthorne'),
  (id: 2600, title: 'War and Peace', author: 'Leo Tolstoy'),
  (id: 1399, title: 'Anna Karenina', author: 'Leo Tolstoy'),
  (id: 55, title: 'The Wonderful Wizard of Oz', author: 'L. Frank Baum'),
  (id: 829, title: "Gulliver's Travels", author: 'Jonathan Swift'),
  (id: 521, title: 'Robinson Crusoe', author: 'Daniel Defoe'),
  (id: 160, title: 'The Awakening', author: 'Kate Chopin'),
];
