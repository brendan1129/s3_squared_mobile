import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class StorageService {
  static const String _apiBaseUrl =
      'https://mu4zwvl8i0.execute-api.us-east-1.amazonaws.com';

  // Inject the user's active login token into the upload pipeline parameters
  static Future<bool> uploadFile(
    File file,
    String jwtToken, {
    String virtualPath = "",
  }) async {
    try {
      final String fileName = file.path.split('/').last;
      final String ext = fileName.split('.').last.toLowerCase();

      // Enforce file extension parameter sync mapping matching the backend configuration rules
      String mimeType = 'image/jpeg';
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'mp4') mimeType = 'video/mp4';

      final http.Response response = await http.post(
        Uri.parse('$_apiBaseUrl/request-upload'),
        headers: {
          'Content-Type': 'application/json',
          // Pass the JWT token explicitly to passing authorizer checks
          'Authorization': jwtToken,
        },
        body: jsonEncode({
          'fileName': '$virtualPath$fileName',
          'mimeType': mimeType,
        }),
      );

      if (response.statusCode != 200) {
        print(
          'Authorization upload token generation rejection error: ${response.body}',
        );
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final String uploadUrl = data['uploadUrl'];

      // Direct S3 transfer requires no authorization headers (handled inside query parameters)
      final http.Response s3Response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': mimeType},
        body: await file.readAsBytes(),
      );

      return s3Response.statusCode == 200;
    } catch (e) {
      print('Pipeline failure tracking details: $e');
      return false;
    }
  }

  /// Fetches files and virtual subfolders from S3 for the current directory path
  static Future<Map<String, List<dynamic>>> fetchDirectoryContents(
    String jwtToken, {
    String virtualPath = "",
  }) async {
    try {
      // Pass the current folder depth as a URL query parameter
      final Uri url = Uri.parse('$_apiBaseUrl/list-files?prefix=$virtualPath');

      final http.Response response = await http.get(
        url,
        headers: {'Authorization': jwtToken},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {'folders': data['folders'] ?? [], 'files': data['files'] ?? []};
      } else {
        print('Failed to read cloud drive directory status: ${response.body}');
        return {'folders': [], 'files': []};
      }
    } catch (e) {
      print('Directory lookup pipeline crash exception tracking: $e');
      return {'folders': [], 'files': []};
    }
  }
}
