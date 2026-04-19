import 'dart:io';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/tools/shamor_zachor/providers/shamor_zachor_data_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('falls back to main-isolate loading when worker loading fails',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('sz_provider_test_');
    final dbPath = '${tempDir.path}/${DatabaseConstants.databaseFileName}';

    SharedPreferences.setMockInitialValues({});
    await Settings.init();
    await Settings.setValue<String>('key-library-path', tempDir.path);
    await Settings.setValue<String>('key-library-folder-name', '');
    await Settings.setValue<String>('key-db-effective-path', '');

    await File(dbPath).create(recursive: true);

    final sqliteProvider = SqliteDataProvider.instance;
    await sqliteProvider.initialize();

    try {
      final db = await sqliteProvider.repository!.database.database;
      db
        ..execute('INSERT INTO source (id, name) VALUES (?, ?)', [1, 'test'])
        ..execute(
          'INSERT INTO category (id, parentId, title, level, orderIndex) VALUES (?, ?, ?, ?, ?)',
          [1, null, 'בדיקה', 0, 1],
        )
        ..execute(
          'INSERT INTO book (id, categoryId, sourceId, title, orderIndex, totalLines, isBaseBook, fileType) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [10, 1, 1, 'ספר בסיס', 1, 1, 1, 'txt'],
        );

      final provider = ShamorZachorDataProvider(
        sqliteDataProvider: sqliteProvider,
        categoryTreeLoader: ({
          required String dbPath,
          required List<int> trackedBookIds,
          required bool includeDebugCategories,
        }) async {
          throw StateError('forced worker failure');
        },
      );

      await provider.loadAllData();

      expect(provider.error, isNull);
      expect(provider.hasData, isTrue);
      expect(provider.getBookDetails('בדיקה', 'ספר בסיס'), isNotNull);
    } finally {
      await sqliteProvider.dispose();
      await tempDir.delete(recursive: true);
    }
  });
}
