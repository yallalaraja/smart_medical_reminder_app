import 'app/app.dart';
import 'package:flutter/material.dart';
import 'services/auth_session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthSessionService.instance.initialize();
  runApp(const SmartReminderApp());
}
