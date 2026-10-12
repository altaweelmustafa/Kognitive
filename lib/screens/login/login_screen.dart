import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid => _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the router moves on to Home by itself.
      await Session.instance.login(_email.text.trim(), _password.text);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DetailScaffold(
      title: 'Log in',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 31),
        children: [
          const SizedBox(height: 10),
          _label('Email'),
          _field(
            _email,
            key: 'login-email',
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),
          _label('Password'),
          _field(_password, key: 'login-password', obscure: true),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Text(
              _error ?? '',
              style: AppText.caption.copyWith(color: c.declining),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: PillButton(
              label: 'Log in',
              width: 120,
              height: 41,
              onPressed: _valid && !_busy ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 18, bottom: 6),
    child: Text(text, style: AppText.sectionTitle),
  );

  Widget _field(
    TextEditingController controller, {
    required String key,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    final c = context.colors;
    return TextField(
      key: ValueKey(key),
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submit(),
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
}
