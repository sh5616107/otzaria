import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/app_menu.dart';

void main() {
  testWidgets('right click opens context menu without layout exceptions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppContextMenuRegion(
              menuBuilder: (_) => const [
                AppContextMenuEntry(
                  label: 'פעולה ראשית',
                  icon: FluentIcons.book_24_regular,
                  trailing: Icon(FluentIcons.copy_24_regular),
                ),
                AppContextMenuEntry(
                  label: 'תת תפריט',
                  children: [
                    AppContextMenuEntry(label: 'פעולת משנה'),
                  ],
                ),
              ],
              child: const SizedBox(
                key: Key('context-menu-target'),
                width: 120,
                height: 40,
                child: Center(
                  child: Text(
                    'יעד',
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final target = find.byKey(const Key('context-menu-target'));
    expect(target, findsOneWidget);

    await tester.tapAt(
      tester.getCenter(target),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('פעולה ראשית'), findsOneWidget);
    expect(find.text('תת תפריט'), findsOneWidget);
    expect(find.byIcon(FluentIcons.book_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.copy_24_regular), findsOneWidget);

    await tester.tap(find.text('תת תפריט'));
    await tester.pumpAndSettle();

    expect(find.text('פעולת משנה'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submenu width is capped for long labels', (tester) async {
    const longLabel =
        'קישור ארוך מאוד מאוד מאוד עם תיאור מפורט במיוחד שלא אמור לפתוח תת תפריט רחב מדי';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppContextMenuRegion(
              menuBuilder: (_) => const [
                AppContextMenuEntry(
                  label: 'קישורים',
                  children: [
                    AppContextMenuEntry(label: longLabel),
                  ],
                ),
              ],
              child: const SizedBox(
                key: Key('long-label-context-menu-target'),
                width: 120,
                height: 40,
                child: Center(
                  child: Text(
                    'יעד',
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final target = find.byKey(const Key('long-label-context-menu-target'));
    expect(target, findsOneWidget);

    await tester.tapAt(
      tester.getCenter(target),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('קישורים'));
    await tester.pumpAndSettle();

    final submenuItem = find.widgetWithText(MenuItemButton, longLabel);
    expect(submenuItem, findsOneWidget);

    final submenuBox = tester.renderObject<RenderBox>(submenuItem);
    expect(submenuBox.size.width, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });
}
