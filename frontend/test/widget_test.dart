import 'package:flutter_test/flutter_test.dart';
import 'package:elder_medication_reminder/app/app.dart';

void main() {
  test('SmartReminderApp can be created', () {
    const app = SmartReminderApp();

    expect(app, isNotNull);
    expect(app, isA<SmartReminderApp>());
  });
}
