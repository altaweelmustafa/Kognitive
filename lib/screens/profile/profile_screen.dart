import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/photo_picker.dart';
import '../../data/session.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/user_avatar.dart';

/// Edit profile: photo, name and password.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.pickPhoto});

  /// For tests: stands in for the photo picker. Returns the new avatar
  /// (a small square image), or null if the player cancelled.
  final Future<Uint8List?> Function()? pickPhoto;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(
    text: Session.instance.user?.name ?? '',
  );
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _retype = TextEditingController();

  bool _photoBusy = false;
  bool _nameBusy = false;
  bool _passwordBusy = false;
  String? _photoError;
  String? _nameMessage;
  bool _nameFailed = false;
  String? _passwordMessage;
  bool _passwordFailed = false;

  static const _minPassword = 8;

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _new.dispose();
    _retype.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    // The picker opens first, straight from the tap: Safari won't open it
    // after an await.
    final picking = (widget.pickPhoto ?? pickAvatarPhoto)();
    setState(() => _photoError = null);
    final Uint8List? photo;
    try {
      photo = await picking;
    } on StateError catch (e) {
      setState(() => _photoError = '${e.message}.');
      return;
    } catch (e) {
      setState(() => _photoError = "Couldn't open your photos ($e).");
      return;
    }
    if (photo == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      await Session.instance.setAvatar(photo);
    } on ApiException catch (e) {
      _photoError = e.message;
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _removePhoto() async {
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      await Session.instance.removeAvatar();
    } on ApiException catch (e) {
      _photoError = e.message;
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  bool get _nameChanged {
    final name = _name.text.trim();
    return name.isNotEmpty && name != Session.instance.user?.name;
  }

  Future<void> _saveName() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _nameBusy = true;
      _nameMessage = null;
    });
    try {
      await Session.instance.updateName(_name.text.trim());
      _nameMessage = 'Name saved.';
      _nameFailed = false;
    } on ApiException catch (e) {
      _nameMessage = e.message;
      _nameFailed = true;
    }
    if (mounted) setState(() => _nameBusy = false);
  }

  /// Why the password can't be changed yet, or null when it can.
  String? get _passwordProblem {
    if (_current.text.isEmpty) return 'Enter your current password.';
    if (_new.text.length < _minPassword) {
      return 'The new password needs at least $_minPassword characters.';
    }
    if (_retype.text != _new.text) return "The new passwords don't match.";
    return null;
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _passwordBusy = true;
      _passwordMessage = null;
    });
    try {
      await Session.instance.changePassword(_current.text, _new.text);
      _current.clear();
      _new.clear();
      _retype.clear();
      _passwordMessage =
          'Password changed. Other devices have been signed out.';
      _passwordFailed = false;
    } on ApiException catch (e) {
      _passwordMessage = e.message;
      _passwordFailed = true;
    }
    if (mounted) setState(() => _passwordBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DetailScaffold(
      title: 'Edit profile',
      child: ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) {
          final user = Session.instance.user;
          final hasPhoto = Session.instance.avatar != null;
          final problem = _passwordProblem;
          // Only nag about the password once they've started on it.
          final started =
              _current.text.isNotEmpty ||
              _new.text.isNotEmpty ||
              _retype.text.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(27, 12, 27, 32),
            children: [
              // ── Photo ──
              Center(
                child: GestureDetector(
                  onTap: _photoBusy ? null : _changePhoto,
                  child: Stack(
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _photoBusy ? 0.4 : 1,
                        child: const UserAvatar(size: 108),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: c.elevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.background, width: 3),
                          ),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (_photoBusy)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('change-photo'),
                    onPressed: _photoBusy ? null : _changePhoto,
                    child: Text(
                      hasPhoto ? 'Change photo' : 'Add a photo',
                      style: AppText.label.copyWith(
                        color: c.brandAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasPhoto)
                    TextButton(
                      key: const ValueKey('remove-photo'),
                      onPressed: _photoBusy ? null : _removePhoto,
                      child: Text(
                        'Remove',
                        style: AppText.label.copyWith(color: c.textSecondary),
                      ),
                    ),
                ],
              ),
              if (_photoError case final error?)
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: c.declining),
                ),
              if (user != null) ...[
                const SizedBox(height: 4),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: AppText.mono12.copyWith(color: c.textMuted),
                ),
              ],

              // ── Name ──
              _heading('Name'),
              _field(_name, key: 'profile-name', keyboard: TextInputType.name),
              _message(_nameMessage, failed: _nameFailed),
              Align(
                alignment: Alignment.centerRight,
                child: PillButton(
                  label: 'Save name',
                  width: 140,
                  height: 40,
                  onPressed: _nameChanged && !_nameBusy ? _saveName : null,
                ),
              ),

              // ── Password ──
              _heading('Password'),
              _label('Current password'),
              _field(_current, key: 'password-current', obscure: true),
              const SizedBox(height: 12),
              _label('New password'),
              _field(_new, key: 'password-new', obscure: true),
              const SizedBox(height: 12),
              _label('New password again'),
              _field(_retype, key: 'password-retype', obscure: true),
              _message(
                _passwordMessage ?? (started ? problem : null),
                failed: _passwordMessage == null || _passwordFailed,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: PillButton(
                  label: 'Change password',
                  width: 180,
                  height: 40,
                  onPressed: problem == null && !_passwordBusy
                      ? _changePassword
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 30, bottom: 10),
    child: Text(text, style: AppText.sectionTitle),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppText.label.copyWith(color: context.colors.textSecondary),
    ),
  );

  Widget _message(String? text, {required bool failed}) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text ?? '',
        style: AppText.caption.copyWith(
          color: failed ? c.declining : c.improving,
        ),
      ),
    );
  }

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
      autocorrect: !obscure,
      onChanged: (_) => setState(() {
        _nameMessage = null;
        _passwordMessage = null;
      }),
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
