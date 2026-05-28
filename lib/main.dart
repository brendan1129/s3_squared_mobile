import 'dart:io';
import 'package:amplify_core/amplify_core.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure AWS connections are established before mounting the application UI tree
  await AuthService.initializeAmplify();

  runApp(const CloudWrapperApp());
}

class CloudWrapperApp extends StatelessWidget {
  const CloudWrapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark(useMaterial3: true),
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  String? _jwtToken;
  bool _isLoadingSession = true; // Tracks background cache lookup
  bool _needsVerification = false;
  bool _isUploading = false;
  String _currentVirtualFolder = "";

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  void _handleSignUp() async {
    bool success = await AuthService.signUpUser(
      _emailController.text,
      _passwordController.text,
    );
    if (success) {
      setState(() => _needsVerification = true);
      _showSnackBar('Verification code sent to your email!');
    } else {
      _showSnackBar('Sign up failed.');
    }
  }

  void _handleVerifyCode() async {
    bool success = await AuthService.confirmSignUp(
      _emailController.text,
      _codeController.text,
    );
    if (success) {
      setState(() => _needsVerification = false);
      _showSnackBar('Account verified! You can now log in.');
    } else {
      _showSnackBar('Verification code invalid.');
    }
  }

  void _handleLogin() async {
    String? token = await AuthService.signInUser(
      _emailController.text,
      _passwordController.text,
    );
    if (token != null) {
      setState(() => _jwtToken = token);
      _showSnackBar('Securely authenticated!');
    } else {
      _showSnackBar('Authentication failed.');
    }
  }

  /// Checks if a valid JWT session token already exists on the device storage
  Future<void> _checkExistingSession() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      // If the user is authenticated, extract their cached identity token
      // Inside lib/main.dart (_checkExistingSession)
      if (session.isSignedIn) {
        final token = session.userPoolTokensResult.value.idToken.raw;
        setState(() {
          _jwtToken = token;
        });
      }
    } catch (e) {
      print('No existing user session found in device cache: $e');
    } finally {
      setState(() {
        _isLoadingSession = false; // Stop loading spinner
      });
    }
  }

  void _handleLogout() async {
    // Force tell AWS Amplify client engine to purge tokens from device storage
    await Amplify.Auth.signOut();
    setState(() {
      _jwtToken = null;
    });
    _showSnackBar('Logged out securely.');
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
    );

    if (result != null &&
        result.files.single.path != null &&
        _jwtToken != null) {
      File file = File(result.files.single.path!);
      setState(() => _isUploading = true);

      // We now pass the authentic JWT token retrieved straight from Cognito session state
      bool success = await StorageService.uploadFile(
        file,
        _jwtToken!,
        virtualPath: _currentVirtualFolder,
      );

      setState(() => _isUploading = false);
      _showSnackBar(
        success ? 'Direct S3 Sync Success!' : 'Upload Blocked/Failed.',
      );
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // State 0: Show a loading spinner while we check the local disk cache for keys
    if (_isLoadingSession) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking cloud session authentication...'),
            ],
          ),
        ),
      );
    }

    // State 1: Active Secure Logged In Dashboard
    if (_jwtToken != null) {
      return CloudExplorerDashboard(
        jwtToken: _jwtToken!,
        onLogout: _handleLogout, // Pass our updated logout handler down
      );
    }

    // State 2: Verification Screen Code Challenge Flow
    if (_needsVerification) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter Email Verification Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '6-Digit Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleVerifyCode,
                child: const Text('Verify Account'),
              ),
            ],
          ),
        ),
      );
    }

    // State 3: Production Login / Signup Core Landing Interface
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 64, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text(
              'Production Auth Gateway',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _handleLogin,
                  child: const Text('Sign In'),
                ),
                OutlinedButton(
                  onPressed: _handleSignUp,
                  child: const Text('Register Account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CloudExplorerDashboard extends StatefulWidget {
  final String jwtToken;
  final VoidCallback onLogout;

  const CloudExplorerDashboard({
    super.key,
    required this.jwtToken,
    required this.onLogout,
  });

  @override
  State<CloudExplorerDashboard> createState() => _CloudExplorerDashboardState();
}

class _CloudExplorerDashboardState extends State<CloudExplorerDashboard> {
  bool _isLoading = true;
  bool _isUploading = false;
  String _currentPath = ""; // Track folder depth state. e.g. "Photos/"

  List<dynamic> _folders = [];
  List<dynamic> _files = [];

  @override
  void initState() {
    super.initState();
    _refreshDriveContents();
  }

  Future<void> _refreshDriveContents() async {
    setState(() => _isLoading = true);
    final contents = await StorageService.fetchDirectoryContents(
      widget.jwtToken,
      virtualPath: _currentPath,
    );
    setState(() {
      _folders = contents['folders']!;
      _files = contents['files']!;
      _isLoading = false;
    });
  }

  Future<void> _handleUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      setState(() => _isUploading = true);

      bool success = await StorageService.uploadFile(
        file,
        widget.jwtToken,
        virtualPath: _currentPath,
      );

      setState(() => _isUploading = false);

      // Auto-refresh the view immediately on success so the new item pops up!
      if (success) _refreshDriveContents();
    }
  }

  void _navigateToFolder(String folderPath) {
    setState(() {
      _currentPath = folderPath;
    });
    _refreshDriveContents();
  }

  void _navigateUp() {
    if (_currentPath.isEmpty) return;
    // Strip out trailing slash and pop the last directory element off the stack
    List<String> segments = _currentPath.split('/');
    segments
        .removeLast(); // Removes trailing empty string due to trailing slash
    if (segments.isNotEmpty)
      segments.removeLast(); // Removes actual parent directory string

    setState(() {
      _currentPath = segments.isEmpty ? "" : "${segments.join('/')}/";
    });
    _refreshDriveContents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentPath.isEmpty ? 'Root Cloud Drive' : '.../$_currentPath',
        ),
        leading: _currentPath.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateUp,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDriveContents,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshDriveContents,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Section 1: Folders Rendering Row
                  if (_folders.isNotEmpty) ...[
                    const Text(
                      'Folders',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 60,
                          ),
                      itemCount: _folders.length,
                      itemBuilder: (context, index) {
                        final folder = _folders[index];
                        // Extract localized name string from raw absolute path
                        final displayTitle = folder
                            .split('/')
                            .reversed
                            .skip(1)
                            .first;
                        return InkWell(
                          onTap: () => _navigateToFolder(folder),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.folder, color: Colors.amber),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    displayTitle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Section 2: Files Rendering Row
                  const Text(
                    'Files',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_files.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No files in this directory.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final sizeInKb = (file['size'] / 1024).toStringAsFixed(
                          1,
                        );
                        return ListTile(
                          leading: const Icon(
                            Icons.insert_drive_file,
                            color: Colors.blue,
                          ),
                          title: Text(file['name']),
                          subtitle: Text('$sizeInKb KB'),
                          trailing: const Icon(Icons.more_vert),
                        );
                      },
                    ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isUploading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Syncing data to S3...'),
                  ],
                )
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                  onPressed: _handleUpload,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add File to Current Folder'),
                ),
        ),
      ),
    );
  }
}
