import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'favorites.dart';
import 'progress.dart';

class User {
  const User({
    required this.name,
    required this.gender,
    required this.email,
    this.avatarVersion = 0,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    name: j['name'] as String,
    gender: j['gender'] as String,
    email: j['email'] as String,
    avatarVersion: (j['avatar_version'] as int?) ?? 0,
  );

  final String name;
  final String gender; // 'male' | 'female'
  final String email;

  /// Goes up each time the profile photo changes; 0 means there is none.
  final int avatarVersion;

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'email': email,
    'avatar_version': avatarVersion,
  };
}

/// The logged-in player, kept across app restarts, plus their activity.
/// Listen to it to rebuild when any of that changes.
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  static const _tokenKey = 'session.token';
  static const _userKey = 'session.user';
  static const _avatarKey = 'session.avatar'; // base64
  static const _avatarVersionKey = 'session.avatarVersion';

  String? token;
  User? user;

  /// The profile photo, kept on the device; null when there is none.
  Uint8List? avatar;
  int _avatarVersion = 0; // the version [avatar] is

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
      final photo = prefs.getString(_avatarKey);
      avatar = photo == null ? null : base64Decode(photo);
      _avatarVersion = prefs.getInt(_avatarVersionKey) ?? 0;
      refreshActivity();
      refreshProfile();
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
    avatar = null;
    _avatarVersion = 0;
    playedDays = {};
    streak = 0;
    Progress.instance.clear();
    Favorites.instance.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_avatarKey);
    await prefs.remove(_avatarVersionKey);
  }

  // ── Profile ─────────────────────────────────────────────

  /// Reloads the profile, and the photo if it changed on another device.
  Future<void> refreshProfile() async {
    if (!loggedIn) return;
    try {
      await _setUser(await _api.get('/me'));
    } on ApiException {
      // Keep what we had.
    }
  }

  Future<void> updateName(String name) async =>
      _setUser(await _api.patch('/me', {'name': name}));

  /// Throws [ApiException] if [current] is wrong. Other devices are signed
  /// out; this one stays in.
  Future<void> changePassword(String current, String next) =>
      _api.post('/me/password', {'current': current, 'new': next});

  /// [image] is a small square PNG (see `avatar_image.dart`).
  Future<void> setAvatar(Uint8List image) async {
    final r = await _api.put('/me/avatar', {'image': base64Encode(image)});
    await _keepAvatar(image, (r['avatar_version'] as int?) ?? 0);
    await _setUser(r);
  }

  Future<void> removeAvatar() async {
    final r = await _api.delete('/me/avatar');
    await _keepAvatar(null, (r['avatar_version'] as int?) ?? 0);
    await _setUser(r);
  }

  Future<void> _setUser(Map<String, dynamic> json) async {
    user = User.fromJson(json);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user!.toJson()));
    if (user!.avatarVersion != _avatarVersion) await _fetchAvatar();
  }

  Future<void> _fetchAvatar() async {
    try {
      final r = await _api.get('/me/avatar');
      final image = r['image'] as String?;
      await _keepAvatar(
        image == null ? null : base64Decode(image),
        r['version'] as int,
      );
    } on ApiException {
      // Try again next time.
    }
  }

  Future<void> _keepAvatar(Uint8List? image, int version) async {
    avatar = image;
    _avatarVersion = version;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (image == null) {
      await prefs.remove(_avatarKey);
    } else {
      await prefs.setString(_avatarKey, base64Encode(image));
    }
    await prefs.setInt(_avatarVersionKey, version);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token!);
    await _setUser(r['user'] as Map<String, dynamic>);
    refreshActivity();
  }
}
