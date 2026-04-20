import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void configureSqlitePlatform() {
  // SharedWorker + postMessage на проде часто дают ответ null → «unsupported result null»
  // (прокси, HTTPS, политики, несовместимость воркера). Режим без worker: только sqlite3.wasm в UI-потоке.
  final root = Uri.base;
  databaseFactory = createDatabaseFactoryFfiWeb(
    noWebWorker: true,
    options: SqfliteFfiWebOptions(
      sqlite3WasmUri: root.resolve('sqlite3.wasm'),
    ),
  );
}
