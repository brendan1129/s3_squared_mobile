import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class StorageService {
  static const String _apiBaseUrl =
      'https://bkc6flglnh.execute-api.us-east-1.amazonaws.com';

  // FIX: MIME map now covers every type the backend ALLOWED_MIME_TYPES accepts.
  // Previously gif/mov/pdf were missing — any of those file types would fall through
  // to 'image/jpeg', the backend's MIME check would reject them with a 403.
  static const Map<String, String> _mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'pdf': 'application/pdf',
  };

  // FIX: was FileType.media which hides PDFs (images/video only).
  // FileType.custom with an explicit allowedExtensions list matches the backend
  // whitelist exactly so the picker and the server stay in sync.
  static Future<FilePickerResult?> pickFile() {
    return FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'pdf'],
    );
  }

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
        // Extension not in whitelist — backend will reject it; fail fast here
        print('Unsupported file extension: .$ext');
        return false;
      }

      final http.Response response = await http.post(
        Uri.parse('$_apiBaseUrl/request-upload'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': jwtToken,
        },
        body: jsonEncode({
          'fileName': '$virtualPath$fileName',
          'mimeType': mimeType,
        }),
      );

      if (response.statusCode != 200) {
        print('Upload token rejection: ${response.body}');
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final String uploadUrl = data['uploadUrl'];

      // Direct S3 transfer — no auth headers, credentials are in the signed URL
      final http.Response s3Response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': mimeType},
        body: await file.readAsBytes(),
      );

      return s3Response.statusCode == 200;
    } catch (e) {
      print('Upload pipeline error: $e');
      return false;
    }
  }

  static Future<Map<String, List<dynamic>>> fetchDirectoryContents(
    String jwtToken, {
    String virtualPath = "",
  }) async {
    try {
      final Uri url = Uri.parse('$_apiBaseUrl/list-files?prefix=$virtualPath');

      final http.Response response = await http.get(
        url,
        headers: {'Authorization': jwtToken},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {'folders': data['folders'] ?? [], 'files': data['files'] ?? []};
      } else {
        print('Directory fetch failed: ${response.body}');
        return {'folders': [], 'files': []};
      }
    } catch (e) {
      print('Directory fetch error: $e');
      return {'folders': [], 'files': []};
    }
  }
}
