import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'progress.dart';

class User {
  const User({required this.name, required this.gender, required this.email});

  factory User.fromJson(Map<String, dynamic> j) => User(
    name: j['name'] as String,
    gender: j['gender'] as String,
    email: j['email'] as String,
  );

  final String name;
  final String gender; // 'male' | 'female'
  final String email;

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'email': email,
  };
}

/// The logged-in player, kept across app restarts, plus their activity.
/// Listen to it to rebuild when any of that changes.
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  static const _tokenKey = 'session.token';
  static const _userKey = 'session.user';

  String? token;
  User? user;

  /// Days (UTC, `yyyy-mm-dd`) on which the player solved something.
  Set<String> playedDays = {};
  int streak = 0;

  bool get loggedIn => token != null;

  ApiClient get _api => ApiClient();

  /// Call once at startup.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    final saved = prefs.getString(_userKey);
    if (token != null && saved != null) {
      user = User.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      refreshActivity();
    } else {
      token = null;
    }
  }

  /// Starts a sign-up and sends the code. Returns the code itself only while
  /// the server has no email set up.
  Future<String?> signup({
    required String name,
    required String gender,
    required String email,
    required String password,
  }) async {
    final r = await _api.post('/auth/signup', {
      'name': name,
      'gender': gender,
      'email': email,
      'password': password,
    });
    return r['dev_code'] as String?;
  }

  Future<String?> resend(String email) async =>
      (await _api.post('/auth/resend', {'email': email}))['dev_code']
          as String?;

  Future<void> verify(String email, String code) async =>
      _start(await _api.post('/auth/verify', {'email': email, 'code': code}));

  Future<void> login(String email, String password) async => _start(
    await _api.post('/auth/login', {'email': email, 'password': password}),
  );

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Logging out locally is enough.
    }
    await expire();
  }

  /// Forgets the login on this device.
  Future<void> expire() async {
    if (token == null) return;
    token = null;
    user = null;
    playedDays = {};
    streak = 0;
    Progress.instance.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Call after the player finishes a game: reloads the streak, today's
  /// session and the performance numbers.
  Future<void> refreshActivity() async {
    if (!loggedIn) return;
    Progress.instance.refresh();
    try {
      final r = await _api.get('/me/activity');
      playedDays = (r['days'] as List).cast<String>().toSet();
      streak = r['streak'] as int;
      notifyListeners();
    } on ApiException {
      // Keep what we had.
    }
  }

  Future<void> _start(Map<String, dynamic> r) async {
    token = r['token'] as String;
    user = User.fromJson(r['user'] as Map<String, dynamic>);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token!);
    await prefs.setString(_userKey, jsonEncode(user!.toJson()));
    refreshActivity();
  }
}
