import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

DatabaseFactory get databaseFactoryOrNull => sqflite.databaseFactory;

Future<String> Function() get getDatabasesPathOrNull =>
    sqflite.getDatabasesPath;
