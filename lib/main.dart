import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/storage_service.dart';

void main() {
  runApp(const CloudWrapperApp());
}

class CloudWrapperApp extends StatelessWidget {
  const CloudWrapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Storage Wrapper',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainGateScreen(),
    );
  }
}

class MainGateScreen extends StatefulWidget {
  const MainGateScreen({super.key});

  @override
  State<MainGateScreen> createState() => _MainGateScreenState();
}

class _MainGateScreenState extends State<MainGateScreen> {
  bool _isLoggedIn = false;
  bool _isUploading = false;
  String _currentVirtualFolder = ""; // Default root bucket pathing

  void _simulateLogin() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  Future<void> _pickAndUploadFile() async {
    // Open native OS file picker interface
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media, // Limits choices to photos/videos for prototyping
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);

      setState(() {
        _isUploading = true;
      });

      // Execute our serverless storage operation
      bool success = await StorageService.uploadFile(
        file,
        virtualPath: _currentVirtualFolder,
      );

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Upload Complete!' : 'Upload Failed.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gate 1: Simple Auth Screen Setup
    if (!_isLoggedIn) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_queue, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'S3 Storage Frontend',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your files. Your bucket. Total control.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _simulateLogin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                  ),
                  child: const Text('Login (Prototype Auth)'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Gate 2: The Main Cloud File Area View Dashboard
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentVirtualFolder.isEmpty
              ? 'My Root Cloud Storage'
              : 'Folder: $_currentVirtualFolder',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => setState(() => _isLoggedIn = false),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row allowing prototype directory toggle configurations
            const Text(
              'Virtual S3 Subdirectories:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Root /'),
                  selected: _currentVirtualFolder.isEmpty,
                  onSelected: (_) => setState(() => _currentVirtualFolder = ""),
                ),
                ChoiceChip(
                  label: const Text('Photos/'),
                  selected: _currentVirtualFolder == "Photos/",
                  onSelected: (_) =>
                      setState(() => _currentVirtualFolder = "Photos/"),
                ),
                ChoiceChip(
                  label: const Text('Documents/'),
                  selected: _currentVirtualFolder == "Documents/",
                  onSelected: (_) =>
                      setState(() => _currentVirtualFolder = "Documents/"),
                ),
              ],
            ),
            const Divider(height: 40),
            Expanded(
              child: Center(
                child: _isUploading
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Streaming binary bytes straight to Amazon S3...',
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.drive_folder_upload,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickAndUploadFile,
                            icon: const Icon(Icons.add),
                            label: const Text('Select & Upload File'),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
