import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class StorageService {
  // Replace this with your actual live API Gateway Stage URL from Serverless deploy
  static const String _apiBaseUrl =
      'https://kv1ipkc3ya.execute-api.us-east-2.amazonaws.com';

  /// Requests a pre-signed URL from Lambda and uploads the binary file directly to S3.
  static Future<bool> uploadFile(File file, {String virtualPath = ""}) async {
    try {
      final String fileName = file.path.split('/').last;

      // Look up a clean MIME type mapping based on extensions (simplistic fallback)
      final String mimeType = fileName.endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      // Step 1: Request the secure upload URL from your API Gateway Lambda function
      final http.Response response = await http.post(
        Uri.parse('$_apiBaseUrl/request-upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // If virtualPath is "Vacation2026/", it becomes "Vacation2026/my_file.jpg"
          'fileName': '$virtualPath$fileName',
          'mimeType': mimeType,
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to fetch pre-signed URL: ${response.body}');
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final String uploadUrl = data['uploadUrl'];

      print(
        'Pre-signed URL generated successfully. Initiating direct S3 binary push...',
      );

      // Step 2: Push raw file byte streaming straight to Amazon S3 bypasses your server entirely
      final http.Response s3Response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': mimeType},
        body: await file.readAsBytes(),
      );

      if (s3Response.statusCode == 200) {
        print('Success! File uploaded directly to S3 multi-tenant directory.');
        return true;
      } else {
        print(
          'S3 direct upload failed with status code: ${s3Response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('Error encountered during storage flow pipeline: $e');
      return false;
    }
  }
}
