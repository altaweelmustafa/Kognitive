import 'package:flutter/material.dart';

import 'app.dart';
import 'data/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.instance.restore();
  runApp(const KognitivApp());
}
