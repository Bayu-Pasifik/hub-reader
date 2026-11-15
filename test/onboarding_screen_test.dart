import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/i18n/strings.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/onboarding_provider.dart';
import 'package:hub_reader/ui/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences)> pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  expect(container.read(onboardingDoneProvider), isFalse); // instalasi baru
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: OnboardingScreen()),
  ));
  await tester.pump();
  return (container, prefs);
}

void main() {
  setUp(() => currentLanguage = AppLanguage.id);

  testWidgets('tiga halaman: Lanjut, Lanjut, Mulai membaca menyelesaikan onboarding', (tester) async {
    final (c, prefs) = await pump(tester);
    expect(find.text('Selamat datang di Hub Reader'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Cara kerjanya'), findsOneWidget);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Atur sesuai kebutuhan'), findsOneWidget);
    expect(find.text('Lewati'), findsNothing); // halaman terakhir
    expect(c.read(onboardingDoneProvider), isFalse);

    await tester.tap(find.text('Mulai membaca'));
    await tester.pump();
    expect(c.read(onboardingDoneProvider), isTrue);
    expect(prefs.getBool(OnboardingState.doneKey), isTrue);
    expect(prefs.getBool(OnboardingState.pendingKey), isNull);
  });

  testWidgets('tombol kembali mundur satu halaman, tidak menutup onboarding', (tester) async {
    final (c, _) = await pump(tester);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Cara kerjanya'), findsOneWidget);

    await tester.binding.handlePopRoute(); // tombol kembali sistem
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang di Hub Reader'), findsOneWidget);
    expect(c.read(onboardingDoneProvider), isFalse);
  });

  testWidgets('Lewati langsung menyelesaikan', (tester) async {
    final (c, prefs) = await pump(tester);
    await tester.tap(find.text('Lewati'));
    await tester.pump();
    expect(c.read(onboardingDoneProvider), isTrue);
    expect(prefs.getBool(OnboardingState.doneKey), isTrue);
  });

  testWidgets('pilihan bahasa mengganti teks langsung', (tester) async {
    await pump(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(currentLanguage, AppLanguage.en);
  });

  testWidgets('font sangat besar: halaman tetap bisa digulir tanpa overflow', (tester) async {
    tester.view.physicalSize = const Size(540, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)), child: child!),
        home: const OnboardingScreen(),
      ),
    ));
    for (var i = 0; i < OnboardingScreen.pageCount; i++) {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'halaman $i');
      if (i < OnboardingScreen.pageCount - 1) {
        await tester.tap(find.text('Lanjut'));
      }
    }
  });
}
