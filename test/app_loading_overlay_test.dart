import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kistbook/core/widgets/app_loading_overlay.dart';

void main() {
  const barrierKey = Key('app-loading-overlay-barrier');

  tearDown(AppLoadingOverlay.hide);

  testWidgets('blocks background taps and prevents stacked overlays', (
    tester,
  ) async {
    late BuildContext context;
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('background-button'),
                  onPressed: () => tapCount++,
                  child: const Text('Tap me'),
                ),
              ),
            );
          },
        ),
      ),
    );

    AppLoadingOverlay.show(context, message: 'Logging in...');
    await tester.pump();

    expect(AppLoadingOverlay.isVisible, isTrue);
    expect(find.byKey(barrierKey), findsOneWidget);
    expect(find.text('Logging in...'), findsOneWidget);

    AppLoadingOverlay.show(context, message: 'Signing out...');
    await tester.pump();

    expect(find.byKey(barrierKey), findsOneWidget);
    expect(find.text('Logging in...'), findsNothing);
    expect(find.text('Signing out...'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('background-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(tapCount, 0);

    AppLoadingOverlay.hide();
    AppLoadingOverlay.hide();
    await tester.pump();

    expect(AppLoadingOverlay.isVisible, isFalse);
    expect(find.byKey(barrierKey), findsNothing);
  });

  testWidgets('run keeps one overlay visible until concurrent tasks finish', (
    tester,
  ) async {
    late BuildContext context;
    final firstTask = Completer<String>();
    final secondTask = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    final firstResult = AppLoadingOverlay.run(
      context,
      message: 'Please wait...',
      task: () => firstTask.future,
    );
    final secondResult = AppLoadingOverlay.run(
      context,
      message: 'Loading profile...',
      task: () => secondTask.future,
    );
    await tester.pump();

    expect(find.byKey(barrierKey), findsOneWidget);
    expect(find.text('Loading profile...'), findsOneWidget);

    firstTask.complete('first');
    expect(await firstResult, 'first');
    await tester.pump();
    expect(AppLoadingOverlay.isVisible, isTrue);

    secondTask.complete('second');
    expect(await secondResult, 'second');
    await tester.pump();
    expect(AppLoadingOverlay.isVisible, isFalse);
  });

  testWidgets('run hides the overlay before rethrowing task errors', (
    tester,
  ) async {
    late BuildContext context;
    final task = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    final result = AppLoadingOverlay.run(context, task: () => task.future);
    await tester.pump();
    expect(AppLoadingOverlay.isVisible, isTrue);

    task.completeError(StateError('failed'));
    await expectLater(result, throwsStateError);
    await tester.pump();

    expect(AppLoadingOverlay.isVisible, isFalse);
  });
}
