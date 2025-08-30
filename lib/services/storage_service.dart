import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const String _fileName = 'user_data.json';

  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  static Future<void> saveUserType(String userType) async {
    try {
      final file = await _localFile;
      final data = {'userType': userType};
      await file.writeAsString(json.encode(data));
      print("Stored user type: $userType");
    } catch (e) {
      print("Error saving user type: $e");
    }
  }

  static Future<String> getUserType() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = json.decode(contents);
        return data['userType'] ?? 'customer';
      }
    } catch (e) {
      print("Error reading user type: $e");
    }
    return 'customer';
  }

  static Future<void> clearUserType() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
        print("Cleared user type");
      }
    } catch (e) {
      print("Error clearing user type: $e");
    }
  }
}