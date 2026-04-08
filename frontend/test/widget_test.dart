import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder_app/app/app.dart';

void main() {
  test('SmartReminderApp can be created', () {
    const app = SmartReminderApp();

    expect(app, isNotNull);
    expect(app, isA<SmartReminderApp>());
  });
}
