import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// sqflite en web requiere factory FFI; en móvil usa el plugin nativo.
Future<void> initSqflite() async {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
}
