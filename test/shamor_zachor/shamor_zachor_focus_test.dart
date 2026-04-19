import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/tools/shamor_zachor/models/book_model.dart';
import 'package:otzaria/tools/shamor_zachor/models/error_model.dart';
import 'package:otzaria/tools/shamor_zachor/models/progress_model.dart';
import 'package:otzaria/tools/shamor_zachor/providers/shamor_zachor_data_provider.dart';
import 'package:otzaria/tools/shamor_zachor/providers/shamor_zachor_progress_provider.dart';
import 'package:otzaria/tools/shamor_zachor/screens/shamor_zachor_main_screen.dart';
import 'package:otzaria/tools/shamor_zachor/shamor_zachor_widget.dart';
import 'package:otzaria/tools/shamor_zachor/widgets/book_card_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.init();
  });

  group('Shamor Zachor focus controller', () {
    late SettingsBloc settingsBloc;
    late FocusNode outsideFocusNode;

    setUp(() {
      settingsBloc = SettingsBloc(repository: SettingsRepository())
        ..add(LoadSettings());
      outsideFocusNode = FocusNode(debugLabel: 'outside-focus');
    });

    tearDown(() {
      outsideFocusNode.dispose();
      settingsBloc.close();
    });

    testWidgets('keyboard shortcut works again after focus is restored',
        (tester) async {
      final focusController = ShamorZachorFocusController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShamorZachorDataProvider>(
              create: (_) => _FakeShamorZachorDataProvider(),
            ),
            ChangeNotifierProvider<ShamorZachorProgressProvider>(
              create: (_) => _FakeShamorZachorProgressProvider(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BlocProvider.value(
                value: settingsBloc,
                child: Column(
                  children: [
                    Expanded(
                      child: ShamorZachorMainScreen(
                        focusController: focusController,
                      ),
                    ),
                    Focus(
                      focusNode: outsideFocusNode,
                      child: const SizedBox(width: 1, height: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ספר פעיל'), findsOneWidget);
      expect(find.text('ספר הושלם'), findsOneWidget);

      outsideFocusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('ספר פעיל'), findsOneWidget);
      expect(find.text('ספר הושלם'), findsOneWidget);

      focusController.requestKeyboardFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('ספר פעיל'), findsOneWidget);
      expect(find.text('ספר הושלם'), findsNothing);
    });

    testWidgets('book card stays stable with long category path',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShamorZachorProgressProvider>(
              create: (_) => _FakeShamorZachorProgressProvider(),
            ),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: BookCardWidget(
                    topLevelCategoryKey: 'בדיקה',
                    categoryName:
                        'נתיב קטגוריה ארוך מאוד עם הרבה מילים כדי לבדוק יציבות במסך צר במיוחד',
                    bookName: 'ספר בדיקה',
                    bookDetails: BookDetails(
                      id: 1,
                      contentType: 'text',
                      parts: const [
                        BookPart(name: 'ראשי', startPage: 1, endPage: 1),
                      ],
                      categoryPath:
                          'נתיב קטגוריה ארוך מאוד עם הרבה מילים כדי לבדוק יציבות במסך צר במיוחד',
                    ),
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ספר בדיקה'), findsOneWidget);
    });

    testWidgets('search keeps duplicate book names from different categories',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShamorZachorDataProvider>(
              create: (_) => _FakeShamorZachorDataProvider(),
            ),
            ChangeNotifierProvider<ShamorZachorProgressProvider>(
              create: (_) => _FakeShamorZachorProgressProvider(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BlocProvider.value(
                value: settingsBloc,
                child: const ShamorZachorMainScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText).first, 'ספר כפול');
      await tester.pumpAndSettle();

      expect(find.byType(BookCardWidget), findsNWidgets(2));
      expect(find.text('קטגוריה א'), findsWidgets);
      expect(find.text('קטגוריה ב'), findsWidgets);
    });

    testWidgets('retry reloads progress error state', (tester) async {
      final progressProvider = _RetryableShamorZachorProgressProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShamorZachorDataProvider>(
              create: (_) => _FakeShamorZachorDataProvider(),
            ),
            ChangeNotifierProvider<ShamorZachorProgressProvider>.value(
              value: progressProvider,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BlocProvider.value(
                value: settingsBloc,
                child: const ShamorZachorMainScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('שגיאה בטעינת הנתונים'), findsOneWidget);

      await tester.tap(find.text('נסה שוב'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(progressProvider.retryCallCount, 1);
      expect(find.text('שגיאה בטעינת הנתונים'), findsNothing);
      expect(find.text('ספר פעיל'), findsOneWidget);
    });

    testWidgets('retry reloads data error and reruns progress', (tester) async {
      final dataProvider = _RetryableShamorZachorDataProvider();
      final progressProvider = _CountingShamorZachorProgressProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShamorZachorDataProvider>.value(
              value: dataProvider,
            ),
            ChangeNotifierProvider<ShamorZachorProgressProvider>.value(
              value: progressProvider,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BlocProvider.value(
                value: settingsBloc,
                child: const ShamorZachorMainScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('שגיאה בטעינת הנתונים'), findsOneWidget);

      await tester.tap(find.text('נסה שוב'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(dataProvider.loadAllDataCallCount, 1);
      expect(progressProvider.retryCallCount, 1);
      expect(find.text('שגיאה בטעינת הנתונים'), findsNothing);
      expect(find.text('ספר פעיל'), findsOneWidget);
    });

    testWidgets('book card recomputes state for a different book widget',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShamorZachorProgressProvider>(
              create: (_) => _FakeShamorZachorProgressProvider(),
            ),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: BookCardWidget(
                    topLevelCategoryKey: 'בדיקה',
                    categoryName: 'בדיקה',
                    bookName: 'ספר פעיל',
                    bookDetails: _FakeShamorZachorDataProvider._activeBook,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('הושלם'), findsNothing);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShamorZachorProgressProvider>(
              create: (_) => _FakeShamorZachorProgressProvider(),
            ),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: BookCardWidget(
                    topLevelCategoryKey: 'בדיקה',
                    categoryName: 'בדיקה',
                    bookName: 'ספר הושלם',
                    bookDetails: _FakeShamorZachorDataProvider._completedBook,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('הושלם'), findsOneWidget);
    });
  });
}

class _FakeShamorZachorDataProvider extends ShamorZachorDataProvider {
  static final BookDetails _activeBook = BookDetails(
    id: 1,
    contentType: 'text',
    parts: const [
      BookPart(name: 'ראשי', startPage: 1, endPage: 1),
    ],
    categoryPath: 'בדיקה',
  );

  static final BookDetails _completedBook = BookDetails(
    id: 2,
    contentType: 'text',
    parts: const [
      BookPart(name: 'ראשי', startPage: 1, endPage: 1),
    ],
    categoryPath: 'בדיקה',
  );

  static final BookDetails _duplicateBookA = BookDetails(
    id: 3,
    contentType: 'text',
    parts: const [
      BookPart(name: 'ראשי', startPage: 1, endPage: 1),
    ],
    categoryPath: 'קטגוריה א',
  );

  static final BookDetails _duplicateBookB = BookDetails(
    id: 4,
    contentType: 'text',
    parts: const [
      BookPart(name: 'ראשי', startPage: 1, endPage: 1),
    ],
    categoryPath: 'קטגוריה ב',
  );

  static final Map<String, BookCategory> _categories = {
    'בדיקה': BookCategory(
      name: 'בדיקה',
      contentType: 'text',
      books: {
        'ספר פעיל': _activeBook,
        'ספר הושלם': _completedBook,
      },
      defaultStartPage: 1,
      isCustom: false,
      sourceFile: 'test',
      schemaVersion: 1,
    ),
    'כפולים': BookCategory(
      name: 'כפולים',
      contentType: 'text',
      books: const {},
      subcategories: [
        BookCategory(
          name: 'קטגוריה א',
          contentType: 'text',
          books: {
            'ספר כפול': _duplicateBookA,
          },
          defaultStartPage: 1,
          isCustom: false,
          sourceFile: 'test',
          schemaVersion: 1,
        ),
        BookCategory(
          name: 'קטגוריה ב',
          contentType: 'text',
          books: {
            'ספר כפול': _duplicateBookB,
          },
          defaultStartPage: 1,
          isCustom: false,
          sourceFile: 'test',
          schemaVersion: 1,
        ),
      ],
      defaultStartPage: 1,
      isCustom: false,
      sourceFile: 'test',
      schemaVersion: 1,
    ),
  };

  @override
  Map<String, BookCategory> get allBookData => _categories;

  @override
  bool get isLoading => false;

  @override
  ShamorZachorError? get error => null;

  @override
  Future<void> ensureLoaded() async {}

  @override
  BookDetails? getBookDetails(String categoryName, String bookName) {
    return _categories[categoryName]?.books[bookName];
  }

  @override
  List<BookSearchResult> searchBooks(String query) {
    if (query.isEmpty) return const [];

    final results = <BookSearchResult>[];
    for (final entry in _categories.entries) {
      _collectSearchResults(entry.value, query, results, entry.key);
    }
    return results;
  }

  void _collectSearchResults(
    BookCategory category,
    String query,
    List<BookSearchResult> results,
    String topLevelCategoryName,
  ) {
    for (final book in category.books.entries) {
      if (book.key.contains(query)) {
        results.add(
          BookSearchResult(
            book.value,
            category.name,
            category,
            book.key,
            topLevelCategoryName,
          ),
        );
      }
    }

    for (final subcategory
        in category.subcategories ?? const <BookCategory>[]) {
      _collectSearchResults(
        subcategory,
        query,
        results,
        topLevelCategoryName,
      );
    }
  }
}

class _RetryableShamorZachorDataProvider extends _FakeShamorZachorDataProvider {
  ShamorZachorError? _currentError = ShamorZachorError(
    type: ShamorZachorErrorType.storageUnavailable,
    message: 'data load failed',
  );
  int loadAllDataCallCount = 0;

  @override
  ShamorZachorError? get error => _currentError;

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> loadAllData() async {
    loadAllDataCallCount++;
    _currentError = null;
    notifyListeners();
  }
}

class _FakeShamorZachorProgressProvider extends ShamorZachorProgressProvider {
  static final Map<int, Map<String, PageProgress>> _progressByBookId = {
    1: {
      '0': PageProgress(learn: true),
    },
    2: {
      '0': PageProgress(
          learn: true, review1: true, review2: true, review3: true),
    },
    3: {
      '0': PageProgress(),
    },
    4: {
      '0': PageProgress(),
    },
  };

  _FakeShamorZachorProgressProvider() : super();
  @override
  bool get isLoading => false;

  @override
  ShamorZachorError? get error => null;

  @override
  Future<void> ensureLoaded() async {}

  @override
  Map<String, PageProgress> getProgressForBookById(int bookId) {
    return _progressByBookId[bookId] ?? const {};
  }

  @override
  PageProgress getProgressForItemById(int bookId, int absoluteIndex) {
    return _progressByBookId[bookId]?[absoluteIndex.toString()] ??
        PageProgress();
  }

  @override
  double getLearnProgressPercentageById(int bookId, BookDetails bookDetails) {
    final progress = _progressByBookId[bookId] ?? const {};
    if (progress.isEmpty || bookDetails.totalLearnableItems == 0) {
      return 0.0;
    }

    final learned = progress.values.where((item) => item.learn).length;
    return learned / bookDetails.totalLearnableItems;
  }

  @override
  int getNumberOfCompletedCyclesById(int bookId, BookDetails bookDetails) {
    return isBookCompletedById(bookId, bookDetails) ? 1 : 0;
  }

  @override
  bool isBookCompletedById(int bookId, BookDetails bookDetails) {
    final progress = _progressByBookId[bookId] ?? const {};
    if (progress.isEmpty) return false;
    return progress.values.every((item) => item.isComplete);
  }

  @override
  bool isBookConsideredInProgressById(int bookId, BookDetails bookDetails) {
    final progress = _progressByBookId[bookId] ?? const {};
    if (progress.isEmpty) return false;
    return progress.values.any((item) => !item.isEmpty) &&
        !isBookCompletedById(bookId, bookDetails);
  }

  @override
  String? getCompletionDateSyncById(int bookId) {
    return bookId == 2 ? 'א׳ ניסן תשפ"ו' : null;
  }
}

class _CountingShamorZachorProgressProvider
    extends _FakeShamorZachorProgressProvider {
  int retryCallCount = 0;

  @override
  Future<void> retry() async {
    retryCallCount++;
    notifyListeners();
  }
}

class _RetryableShamorZachorProgressProvider
    extends _FakeShamorZachorProgressProvider {
  ShamorZachorError? _currentError = ShamorZachorError(
    type: ShamorZachorErrorType.storageUnavailable,
    message: 'progress load failed',
  );
  int retryCallCount = 0;

  @override
  ShamorZachorError? get error => _currentError;

  @override
  Future<void> retry() async {
    retryCallCount++;
    _currentError = null;
    notifyListeners();
  }
}
