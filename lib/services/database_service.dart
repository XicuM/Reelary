import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  static const String _dbName = 'recipes.db';

  static Future<String> get _dbPath async {
    return join(await getDatabasesPath(), _dbName);
  }

  static Future<void> exportDatabase(BuildContext context) async {
    try {
      final dbPath = await _dbPath;
      final file = File(dbPath);

      if (await file.exists()) {
        final tempDir = await getTemporaryDirectory();
        final backupFile = File(join(tempDir.path, 'reelary_backup.db'));
        await file.copy(backupFile.path);

        final xFile = XFile(backupFile.path);
        await Share.shareXFiles(
          [xFile],
          text: 'Here is my Reelary database backup.',
        );
      } else {
        _showSnackBar(context, 'Database not found.', isError: true);
      }
    } catch (e) {
      _showSnackBar(context, 'Error exporting database: $e', isError: true);
    }
  }

  static Future<void> importDatabase(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final dbPath = await _dbPath;

        // Close the existing database before replacing it
        // This is important to avoid file locking issues
        // You'll need to implement a way to close your database in DatabaseHelper
        // For now, we'll just copy the file.
        // await DatabaseHelper.instance.close();

        await pickedFile.copy(dbPath);

        _showSnackBar(context, 'Database imported successfully! Please restart the app.');
      } else {
        _showSnackBar(context, 'No file selected.');
      }
    } catch (e) {
      _showSnackBar(context, 'Error importing database: $e', isError: true);
    }
  }

  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
