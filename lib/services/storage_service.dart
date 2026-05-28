import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class StorageService {
  static const String _apiBaseUrl =
      'https://bkc6flglnh.execute-api.us-east-1.amazonaws.com';

  static const Map<String, String> _mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'pdf': 'application/pdf',
  };

  static Map<String, String> _authHeaders(String jwt) => {'Authorization': jwt};

  static Map<String, String> _jsonHeaders(String jwt) => {
    'Content-Type': 'application/json',
    'Authorization': jwt,
  };

  // ── Upload ──────────────────────────────────────────────────────────────────

  static Future<bool> uploadFile(
    File file,
    String jwtToken, {
    String virtualPath = "",
  }) async {
    try {
      final String fileName = file.path.split('/').last;
      final String ext = fileName.split('.').last.toLowerCase();
      final String? mimeType = _mimeTypes[ext];
      if (mimeType == null) {
        print('Unsupported extension: .$ext');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/request-upload'),
        headers: _jsonHeaders(jwtToken),
        body: jsonEncode({
          'fileName': '$virtualPath$fileName',
          'mimeType': mimeType,
        }),
      );
      if (response.statusCode != 200) {
        print('Upload token rejection: ${response.body}');
        return false;
      }

      final String uploadUrl = jsonDecode(response.body)['uploadUrl'];
      final s3Response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': mimeType},
        body: await file.readAsBytes(),
      );
      return s3Response.statusCode == 200;
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  // ── List ────────────────────────────────────────────────────────────────────

  static Future<Map<String, List<dynamic>>> fetchDirectoryContents(
    String jwtToken, {
    String virtualPath = "",
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/list-files?prefix=$virtualPath'),
        headers: _authHeaders(jwtToken),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'folders': data['folders'] ?? [], 'files': data['files'] ?? []};
      }
      print('List failed: ${response.body}');
      return {'folders': [], 'files': []};
    } catch (e) {
      print('List error: $e');
      return {'folders': [], 'files': []};
    }
  }

  // ── Download URL ────────────────────────────────────────────────────────────

  static Future<String?> getDownloadUrl(String jwtToken, String fileKey) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/download-url?key=${Uri.encodeComponent(fileKey)}',
        ),
        headers: _authHeaders(jwtToken),
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body)['downloadUrl'] as String;
      print('Download URL failed: ${response.body}');
      return null;
    } catch (e) {
      print('Download URL error: $e');
      return null;
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  static Future<bool> deleteFile(String jwtToken, String fileKey) async {
    try {
      final response = await http.delete(
        Uri.parse('$_apiBaseUrl/delete-file'),
        headers: _jsonHeaders(jwtToken),
        body: jsonEncode({'fileKey': fileKey}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }

  // ── Rename ──────────────────────────────────────────────────────────────────

  static Future<bool> renameFile(
    String jwtToken,
    String fileKey,
    String newName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/rename-file'),
        headers: _jsonHeaders(jwtToken),
        body: jsonEncode({'fileKey': fileKey, 'newName': newName}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Rename error: $e');
      return false;
    }
  }

  // ── Move ────────────────────────────────────────────────────────────────────

  /// [destinationFolder] is the target folder path with trailing slash,
  /// or empty string "" to move to the root.
  static Future<bool> moveFile(
    String jwtToken,
    String sourceKey,
    String destinationFolder,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/move-file'),
        headers: _jsonHeaders(jwtToken),
        body: jsonEncode({
          'sourceKey': sourceKey,
          'destinationFolder': destinationFolder,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Move error: $e');
      return false;
    }
  }

  // ── Create folder ───────────────────────────────────────────────────────────

  static Future<bool> createFolder(String jwtToken, String folderPath) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/create-folder'),
        headers: _jsonHeaders(jwtToken),
        body: jsonEncode({'folderPath': folderPath}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Create folder error: $e');
      return false;
    }
  }
}
