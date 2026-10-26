import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/color_config.dart';
import '../../data/api_client.dart';
import '../../data/web_push.dart';
import '../../theme/app_text.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/pill_button.dart';

/// Where this device stands with notifications.
enum _Device {
  /// The phone and desktop apps: reminders go to the web app.
  nativeApp,

  /// Opened over plain http: browsers only allow notifications on https.
  insecure,

  /// iPhone Safari: only the app added to the Home Screen can get them.
  iosBrowser,
  unsupported,
  blocked,
  off,
  on,
}

/// The daily reminder: a notification at a chosen time if today's session
/// isn't finished. Sent by the server as Web Push to the web app.
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key, this.api});

  final ApiClient? api;

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();

  bool? _enabled; // null while loading
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  String _timezone = 'UTC';
  int _devices = 0;

  String? _serverKey; // fetched ahead, so a tap can subscribe at once
  bool _subscribed = false;
  bool _busy = false;
  String? _message;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.get('/me/reminder');
      _apply(r);
      if (kIsWeb && WebPush.available) {
        _serverKey = (await _api.get('/push/key'))['key'] as String;
        _subscribed = await WebPush.current() != null;
      }
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) setState(() => _show(e.message, failed: true));
    }
  }

  void _apply(Map<String, dynamic> r) {
    final parts = (r['time'] as String).split(':');
    _enabled = r['enabled'] as bool;
    _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    _timezone = r['timezone'] as String;
    _devices = r['devices'] as int;
  }

  void _show(String? message, {bool failed = false}) {
    _message = message;
    _failed = failed;
  }

  _Device get _device {
    if (!kIsWeb) return _Device.nativeApp;
    if (!WebPush.secure) return _Device.insecure;
    if (WebPush.ios && !WebPush.standalone) return _Device.iosBrowser;
    if (!WebPush.available) return _Device.unsupported;
    if (WebPush.permission == 'denied') return _Device.blocked;
    return _subscribed ? _Device.on : _Device.off;
  }

  String get _hhmm =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _save({bool? enabled, TimeOfDay? time}) async {
    final before = (_enabled, _time);
    setState(() {
      _enabled = enabled ?? _enabled;
      _time = time ?? _time;
      _show(null);
    });
    try {
      final r = await _api.put('/me/reminder', {
        'enabled': _enabled,
        'time': _hhmm,
        // The web app knows the device's zone; the phone apps keep the last.
        'timezone': WebPush.timeZone ?? _timezone,
      });
      if (mounted) setState(() => _apply(r));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _enabled = before.$1;
          _time = before.$2;
          _show(e.message, failed: true);
        });
      }
    }
  }

  /// Turns notifications on for this device. Runs straight from the tap:
  /// the permission prompt must come before any await.
  Future<void> _turnOn({bool alsoEnable = false}) async {
    final key = _serverKey;
    if (key == null) return;
    final subscribing = WebPush.subscribe(key);
    setState(() {
      _busy = true;
      _show(null);
    });
    try {
      final sub = await subscribing;
      await _api.post('/push/subscriptions', sub);
      _subscribed = true;
      if (alsoEnable || _enabled == false) await _save(enabled: true);
      _show('Notifications are on for this device.');
    } on StateError catch (e) {
      _show(switch (e.message) {
        'denied' =>
          'Notifications are blocked for Kognitiv. Allow them in Settings, '
              'then come back.',
        'default' => 'No problem. Turn them on whenever you like.',
        final reason =>
          "This device couldn't sign up for notifications "
              '($reason).',
      }, failed: e.message != 'default');
    } on ApiException catch (e) {
      _show(e.message, failed: true);
    } catch (_) {
      _show("This device couldn't sign up for notifications.", failed: true);
    }
    await _refreshDevices();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _turnOff() async {
    setState(() => _busy = true);
    try {
      final endpoint = await WebPush.unsubscribe();
      if (endpoint != null) {
        await _api.post('/push/subscriptions/remove', {'endpoint': endpoint});
      }
      _subscribed = false;
      _show('This device won’t get notifications any more.');
    } on ApiException catch (e) {
      _show(e.message, failed: true);
    }
    await _refreshDevices();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      await _api.post('/push/test');
      _show('Sent. It should arrive in a moment.');
    } on ApiException catch (e) {
      _show(e.message, failed: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _refreshDevices() async {
    try {
      _devices = (await _api.get('/me/reminder'))['devices'] as int;
    } on ApiException {
      // Not worth bothering anyone about.
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) await _save(time: picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = _enabled;
    final device = _device;
    final body = AppText.body.copyWith(color: c.textSecondary);

    return DetailScaffold(
      title: 'Daily reminder',
      child: enabled == null && _message == null
          ? Center(child: CircularProgressIndicator(color: c.brandAccent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(27, 12, 27, 32),
              children: [
                Text(
                  "A nudge at the time you choose, on days you haven't "
                  'finished your session yet.',
                  style: body,
                ),
                const SizedBox(height: 20),
                _tile(
                  title: 'Remind me',
                  trailing: Switch(
                    key: const ValueKey('reminder-switch'),
                    value: enabled ?? false,
                    activeThumbColor: c.brandAccent,
                    onChanged: enabled == null || _busy
                        ? null
                        : (on) {
                            // Turning on where this device could get them but
                            // doesn't yet: ask now, while it's a tap.
                            if (on && device == _Device.off) {
                              _turnOn(alsoEnable: true);
                            } else {
                              _save(enabled: on);
                            }
                          },
                  ),
                ),
                _tile(
                  title: 'Time',
                  onTap: enabled == true ? _pickTime : null,
                  trailing: Text(
                    _time.format(context),
                    key: const ValueKey('reminder-time'),
                    style: AppText.mono16.copyWith(
                      color: enabled == true ? c.brandAccent : c.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('This device', style: AppText.sectionTitle),
                const SizedBox(height: 10),
                Text(
                  _deviceText(device),
                  key: const ValueKey('device-status'),
                  style: body,
                ),
                const SizedBox(height: 16),
                if (device == _Device.off)
                  Center(
                    child: PillButton(
                      label: 'Turn on notifications',
                      width: 240,
                      height: 42,
                      onPressed: _busy || _serverKey == null
                          ? null
                          : () => _turnOn(),
                    ),
                  ),
                if (device == _Device.on) ...[
                  Center(
                    child: PillButton(
                      label: 'Send a test notification',
                      width: 260,
                      height: 42,
                      onPressed: _busy ? null : _test,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : _turnOff,
                      child: Text(
                        'Turn off on this device',
                        style: AppText.label.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ),
                ],
                if (_message case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    key: const ValueKey('reminder-message'),
                    textAlign: TextAlign.center,
                    style: AppText.label.copyWith(
                      color: _failed ? c.declining : c.improving,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  _devices == 1
                      ? 'Reminders go to 1 device.'
                      : 'Reminders go to $_devices devices.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
    );
  }

  String _deviceText(_Device device) => switch (device) {
    _Device.nativeApp =>
      'Reminders arrive through the Kognitiv web app. On iPhone, open it in '
          'Safari, tap Share, then Add to Home Screen, and turn notifications '
          'on from there.',
    _Device.insecure =>
      'Notifications need the secure (https) address of Kognitiv. Open the '
          'app from that address to turn them on.',
    _Device.iosBrowser =>
      'On iPhone, notifications only work in the app on your Home Screen. '
          'Tap Share, then Add to Home Screen, open Kognitiv from there, and '
          'come back here.',
    _Device.unsupported => "This browser can't show notifications.",
    _Device.blocked =>
      'Notifications are blocked for Kognitiv. Allow them in your settings '
          '(on iPhone: Settings, Notifications, Kognitiv), then come back.',
    _Device.off => "This device doesn't get notifications yet.",
    _Device.on => 'This device gets notifications.',
  };

  Widget _tile({
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppText.listTitle)),
            trailing,
          ],
        ),
      ),
    );
  }
}
