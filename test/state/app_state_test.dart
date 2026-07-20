import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasmaster/services/preferences.dart';
import 'package:gasmaster/state/app_state.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'unit_system': 'imperial'});
    await Preferences.init();
  });

  test('unitSystemProvider updates state and persists the preference',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(unitSystemProvider), 'imperial');

    await container.read(unitSystemProvider.notifier).set('metric');

    expect(container.read(unitSystemProvider), 'metric');
    expect(Preferences.unitSystem, 'metric');
  });

  test('communitySharingProvider is off by default and persists opt-in',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(communitySharingProvider), isFalse);

    await container.read(communitySharingProvider.notifier).set(true);

    expect(container.read(communitySharingProvider), isTrue);
    expect(Preferences.communitySharingEnabled, isTrue);
  });
}
