import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/otp_field.dart';
import '../../widgets/pill_button.dart';

enum _Step { name, gender, email, password, retype, otp }

/// Create-account flow: one question per step.
/// The account is created when the password is confirmed, and the emailed
/// code then verifies it.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _genders = ['Male', 'Female'];
  static const _minPassword = 8;
  static const _otpLength = 6;
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _retype = TextEditingController();
  final _otp = TextEditingController();
  String? _gender;
  _Step _step = _Step.name;
  bool _busy = false;
  String? _error; // from the server

  /// The code itself, only while the server has no email set up.
  String? _devCode;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _retype, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid => switch (_step) {
    _Step.name => _name.text.trim().isNotEmpty,
    _Step.gender => _gender != null,
    _Step.email => _emailPattern.hasMatch(_email.text.trim()),
    _Step.password => _password.text.length >= _minPassword,
    _Step.retype => _retype.text == _password.text,
    _Step.otp => _otp.text.length == _otpLength,
  };

  String get _question => switch (_step) {
    _Step.name => "What's your name?",
    _Step.gender => "What's your gender?",
    _Step.email => "What's your email?",
    _Step.password => 'Create a password',
    _Step.retype => 'Retype your password',
    _Step.otp => 'Enter your code',
  };

  String get _helper => switch (_step) {
    _Step.name => 'This appears on your profile.',
    _Step.gender => 'You can change this later in settings.',
    _Step.email => "You'll need to confirm this email next.",
    _Step.password => 'At least $_minPassword characters.',
    _Step.retype => "Passwords don't match.",
    _Step.otp =>
      _devCode == null
          ? 'We sent a $_otpLength-digit code to ${_email.text.trim()}.'
          : "Email isn't set up on the server yet. Your code is $_devCode.",
  };

  Future<void> _next() async {
    if (!_valid || _busy) return;
    if (_step != _Step.retype && _step != _Step.otp) {
      setState(() => _step = _Step.values[_step.index + 1]);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == _Step.retype) {
        final devCode = await Session.instance.signup(
          name: _name.text.trim(),
          gender: _gender!.toLowerCase(),
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;
        setState(() {
          _devCode = devCode;
          _otp.clear();
          _step = _Step.otp;
          _busy = false;
        });
      } else {
        // On success the router moves on to Home by itself.
        await Session.instance.verify(_email.text.trim(), _otp.text);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devCode = await Session.instance.resend(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _devCode = devCode;
        _otp.clear();
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  void _back() {
    if (_step == _Step.name) {
      context.pop();
    } else {
      setState(() {
        _step = _Step.values[_step.index - 1];
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mismatch =
        _step == _Step.retype && _retype.text.isNotEmpty && !_valid;
    final showHelper = _step != _Step.retype || mismatch;

    return DetailScaffold(
      title: 'Create account',
      onBack: _back,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 31),
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(_question, style: AppText.sectionTitle),
          ),
          const SizedBox(height: 6),
          switch (_step) {
            _Step.name => _field(_name, keyboard: TextInputType.name),
            _Step.gender => Column(
              children: [for (final g in _genders) _genderOption(g)],
            ),
            _Step.email => _field(_email, keyboard: TextInputType.emailAddress),
            _Step.password => _field(_password, obscure: true),
            _Step.retype => _field(_retype, obscure: true),
            _Step.otp => OtpField(
              controller: _otp,
              length: _otpLength,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _next(),
            ),
          },
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Text(
              _error ?? (showHelper ? _helper : ''),
              style: AppText.caption.copyWith(
                color: mismatch || _error != null
                    ? c.declining
                    : c.textSecondary,
              ),
            ),
          ),
          if (_step == _Step.otp)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _resend,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 0),
                  child: Text(
                    'Resend code',
                    style: AppText.label.copyWith(
                      color: c.brandAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 36),
          Center(
            child: PillButton(
              label: _step == _Step.otp ? 'Verify' : 'Next',
              width: _step == _Step.otp ? 96 : 82,
              height: 41,
              onPressed: _valid && !_busy ? _next : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    final c = context.colors;
    return TextField(
      key: ValueKey(_step),
      controller: controller,
      autofocus: true,
      obscureText: obscure,
      keyboardType: keyboard,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _next(),
      style: AppText.body.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: c.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _genderOption(String gender) {
    final c = context.colors;
    final selected = _gender == gender;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _gender = gender),
      child: Container(
        height: 51,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.brandAccent : c.textMuted,
                  width: 2,
                ),
              ),
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.brandAccent,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(gender, style: AppText.body),
          ],
        ),
      ),
    );
  }
}
