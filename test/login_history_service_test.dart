import 'package:flutter_test/flutter_test.dart';
import 'package:in_salah/services/login_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginHistoryService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves most recent emails first and limits history to five', () async {
      final service = LoginHistoryService();

      await service.saveEmail('one@example.com');
      await service.saveEmail('two@example.com');
      await service.saveEmail('three@example.com');
      await service.saveEmail('four@example.com');
      await service.saveEmail('five@example.com');
      final history = await service.saveEmail('six@example.com');

      expect(history, [
        'six@example.com',
        'five@example.com',
        'four@example.com',
        'three@example.com',
        'two@example.com',
      ]);
    });

    test(
      'saving an existing email moves it to the top without duplicates',
      () async {
        final service = LoginHistoryService();

        await service.saveEmail('first@example.com');
        await service.saveEmail('second@example.com');
        final history = await service.saveEmail('FIRST@example.com');

        expect(history, ['FIRST@example.com', 'second@example.com']);
      },
    );
  });
}
