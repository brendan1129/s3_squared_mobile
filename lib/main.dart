import 'dart:io';
import 'package:amplify_core/amplify_core.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';
import 'widgets/folder_picker.dart';
import 'widgets/file_preview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initializeAmplify();
  runApp(const CloudWrapperApp());
}

class CloudWrapperApp extends StatelessWidget {
  const CloudWrapperApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark(),
      home: const MainGateScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth gate
// ─────────────────────────────────────────────────────────────────────────────

class MainGateScreen extends StatefulWidget {
  const MainGateScreen({super.key});
  @override
  State<MainGateScreen> createState() => _MainGateScreenState();
}

class _MainGateScreenState extends State<MainGateScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  String? _jwtToken;
  bool _isLoadingSession = true;
  bool _needsVerification = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (session.isSignedIn) {
        final token = session.userPoolTokensResult.value.idToken.raw;
        setState(() => _jwtToken = token);
      }
    } catch (_) {
    } finally {
      setState(() => _isLoadingSession = false);
    }
  }

  void _handleSignUp() async {
    final ok = await AuthService.signUpUser(
      _emailCtrl.text,
      _passwordCtrl.text,
    );
    if (ok) {
      setState(() => _needsVerification = true);
      _snack('Check your email for a verification code.');
    } else
      _snack('Sign up failed. Try again.');
  }

  void _handleVerify() async {
    final ok = await AuthService.confirmSignUp(_emailCtrl.text, _codeCtrl.text);
    if (ok) {
      setState(() => _needsVerification = false);
      _snack('Verified! You can sign in now.');
    } else
      _snack('Invalid code. Try again.');
  }

  void _handleLogin() async {
    final token = await AuthService.signInUser(
      _emailCtrl.text,
      _passwordCtrl.text,
    );
    if (token != null)
      setState(() => _jwtToken = token);
    else
      _snack('Authentication failed.');
  }

  void _handleLogout() async {
    await Amplify.Auth.signOut();
    setState(() => _jwtToken = null);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.cyan,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_jwtToken != null) {
      return CloudExplorerDashboard(
        jwtToken: _jwtToken!,
        onLogout: _handleLogout,
      );
    }
    if (_needsVerification) return _buildVerifyScreen();
    return _buildLoginScreen();
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Logo area
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyanGlow,
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.cloud_done_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'S9 Cloud',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Serverless cloud storage',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 52),

              const Text(
                'Email',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(
                    Icons.mail_outline,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Password',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Sign in — gradient button
              _GradientButton(label: 'Sign In', onPressed: _handleLogin),
              const SizedBox(height: 14),

              // Register — outlined
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderMid),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  onPressed: _handleSignUp,
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyScreen() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 48,
                color: AppColors.cyan,
              ),
              const SizedBox(height: 20),
              const Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the 6-digit code sent to your inbox.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  letterSpacing: 6,
                  fontSize: 22,
                ),
                decoration: const InputDecoration(hintText: '000000'),
              ),
              const SizedBox(height: 28),
              _GradientButton(
                label: 'Verify Account',
                onPressed: _handleVerify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Explorer dashboard
// ─────────────────────────────────────────────────────────────────────────────

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
  String _currentPath = "";

  List<dynamic> _folders = [];
  List<dynamic> _files = [];

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final c = await StorageService.fetchDirectoryContents(
      widget.jwtToken,
      virtualPath: _currentPath,
    );
    if (!mounted) return;
    setState(() {
      _folders = c['folders']!;
      _files = c['files']!;
      _isLoading = false;
    });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goTo(String path) {
    setState(() => _currentPath = path);
    _refresh();
  }

  void _goUp() {
    if (_currentPath.isEmpty) return;
    final segs = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
    segs.removeLast();
    _goTo(segs.isEmpty ? "" : "${segs.join('/')}/");
  }

  // ── Upload ──────────────────────────────────────────────────────────────────

  void _showUploadPicker() {
    final isMobile = Platform.isIOS || Platform.isAndroid;
    if (!isMobile) {
      _uploadFromFiles();
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add file',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: _iconPill(Icons.photo_library_outlined, AppColors.cyan),
              title: const Text('Photo library'),
              subtitle: const Text('Choose an image or video'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadFromLibrary();
              },
            ),
            ListTile(
              leading: _iconPill(Icons.camera_alt_outlined, AppColors.violet),
              title: const Text('Camera'),
              subtitle: const Text('Take a new photo'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadFromCamera();
              },
            ),
            ListTile(
              leading: _iconPill(Icons.folder_open_outlined, AppColors.filePdf),
              title: const Text('Browse files'),
              subtitle: const Text('Documents, PDFs and more'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadFromFiles();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFromLibrary() async {
    final xf = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (xf != null) await _doUpload(File(xf.path));
  }

  Future<void> _uploadFromCamera() async {
    final xf = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (xf != null) await _doUpload(File(xf.path));
  }

  Future<void> _uploadFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'pdf'],
    );
    if (result?.files.single.path != null)
      await _doUpload(File(result!.files.single.path!));
  }

  Future<void> _doUpload(File file) async {
    setState(() => _isUploading = true);
    final ok = await StorageService.uploadFile(
      file,
      widget.jwtToken,
      virtualPath: _currentPath,
    );
    setState(() => _isUploading = false);
    if (ok)
      _refresh();
    else
      _snack('Upload failed.');
  }

  // ── File actions ────────────────────────────────────────────────────────────

  void _showFileActions(Map<String, dynamic> file) {
    final fileKey = '$_currentPath${file['name']}';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            // File info header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _iconPill(
                    FileTypeHelper.getIcon(file['name'] as String),
                    FileTypeHelper.getColor(file['name'] as String),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file['name'] as String,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${((file['size'] as int) / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (FileTypeHelper.isPreviewable(file['name'] as String))
              ListTile(
                leading: _iconPill(Icons.visibility_outlined, AppColors.cyan),
                title: const Text('Preview'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPreview(file, fileKey);
                },
              ),
            ListTile(
              leading: _iconPill(
                Icons.download_outlined,
                AppColors.textSecondary,
              ),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(ctx);
                _doDownload(fileKey);
              },
            ),
            ListTile(
              leading: _iconPill(
                Icons.drive_file_rename_outline,
                AppColors.textSecondary,
              ),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(file, fileKey);
              },
            ),
            ListTile(
              leading: _iconPill(Icons.folder_copy_outlined, AppColors.violet),
              title: const Text('Move to…'),
              onTap: () {
                Navigator.pop(ctx);
                _showMovePicker(file, fileKey);
              },
            ),
            ListTile(
              leading: _iconPill(Icons.delete_outline, AppColors.error),
              title: const Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(file, fileKey);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openPreview(Map<String, dynamic> file, String fileKey) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePreviewPage(
          fileName: file['name'] as String,
          fileKey: fileKey,
          jwtToken: widget.jwtToken,
        ),
      ),
    );
  }

  Future<void> _doDownload(String fileKey) async {
    final url = await StorageService.getDownloadUrl(widget.jwtToken, fileKey);
    if (url == null) {
      _snack('Could not get download link.');
      return;
    }
    // ignore: deprecated_member_use
    if (await canLaunchUrl(Uri.parse(url))) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showRenameDialog(Map<String, dynamic> file, String fileKey) {
    final ctrl = TextEditingController(text: file['name'] as String);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty && name != file['name']) {
                Navigator.pop(ctx);
                _doRename(fileKey, name);
              }
            },
            child: const Text(
              'Rename',
              style: TextStyle(color: AppColors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doRename(String fileKey, String newName) async {
    final ok = await StorageService.renameFile(
      widget.jwtToken,
      fileKey,
      newName,
    );
    _snack(ok ? 'Renamed.' : 'Rename failed.');
    if (ok) _refresh();
  }

  void _showMovePicker(Map<String, dynamic> file, String fileKey) async {
    // Determine which folder the file currently lives in
    final sourceFolder = fileKey.contains('/')
        ? fileKey.substring(0, fileKey.lastIndexOf('/') + 1)
        : '';

    final selectedFolder = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FolderPickerSheet(
        jwtToken: widget.jwtToken,
        excludeFolder: sourceFolder,
      ),
    );

    if (selectedFolder != null) {
      final ok = await StorageService.moveFile(
        widget.jwtToken,
        fileKey,
        selectedFolder,
      );
      _snack(ok ? 'Moved successfully.' : 'Move failed.');
      if (ok) _refresh();
    }
  }

  void _showDeleteConfirm(Map<String, dynamic> file, String fileKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file'),
        content: Text(
          'Permanently delete "${file['name']}"?\nThis cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _doDelete(fileKey);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(String fileKey) async {
    final ok = await StorageService.deleteFile(widget.jwtToken, fileKey);
    _snack(ok ? 'Deleted.' : 'Delete failed.');
    if (ok) _refresh();
  }

  // ── New folder ──────────────────────────────────────────────────────────────

  void _showNewFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Folder name'),
          onChanged: (v) {
            if (v.contains('/')) {
              ctrl.text = v.replaceAll('/', '');
              ctrl.selection = TextSelection.collapsed(
                offset: ctrl.text.length,
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                _doCreateFolder(name);
              }
            },
            child: const Text(
              'Create',
              style: TextStyle(color: AppColors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doCreateFolder(String name) async {
    final ok = await StorageService.createFolder(
      widget.jwtToken,
      '$_currentPath$name/',
    );
    _snack(ok ? 'Folder created.' : 'Could not create folder.');
    if (ok) _refresh();
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _sheetHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.borderMid,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _iconPill(IconData icon, Color color) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: color, size: 18),
  );

  // ── Breadcrumb ──────────────────────────────────────────────────────────────

  Widget _buildBreadcrumb() {
    final segs = _currentPath.isEmpty
        ? <String>[]
        : _currentPath.split('/').where((s) => s.isNotEmpty).toList();

    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.storage_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: segs.isEmpty ? null : () => _goTo(""),
                    child: Text(
                      'Root',
                      style: TextStyle(
                        fontSize: 13,
                        color: segs.isEmpty
                            ? AppColors.textPrimary
                            : AppColors.cyan,
                        fontWeight: segs.isEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  ...segs.asMap().entries.map((e) {
                    final isLast = e.key == segs.length - 1;
                    final path = '${segs.sublist(0, e.key + 1).join('/')}/';
                    return Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.chevron_right,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                        GestureDetector(
                          onTap: isLast ? null : () => _goTo(path),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 13,
                              color: isLast
                                  ? AppColors.textPrimary
                                  : AppColors.cyan,
                              fontWeight: isLast
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _currentPath.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: _goUp,
              )
            : null,
        title: const Text('S9 Cloud'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 22),
            tooltip: 'New folder',
            onPressed: _showNewFolderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 22),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumb(),
          Container(height: 0.5, color: AppColors.borderSubtle),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.cyan,
                      strokeWidth: 2,
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.cyan,
                    backgroundColor: AppColors.bgElevated,
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      children: [
                        // Folders
                        if (_folders.isNotEmpty) ...[
                          _sectionLabel('Folders', Icons.folder_outlined),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: 58,
                                ),
                            itemCount: _folders.length,
                            itemBuilder: (ctx, i) {
                              final folder = _folders[i] as String;
                              final name = folder
                                  .split('/')
                                  .reversed
                                  .skip(1)
                                  .first;
                              return GestureDetector(
                                onTap: () => _goTo(folder),
                                child: Container(
                                  decoration: AppTheme.folderCard(),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      const Icon(
                                        Icons.folder,
                                        color: AppColors.cyan,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                        ],

                        // Files
                        _sectionLabel(
                          'Files',
                          Icons.insert_drive_file_outlined,
                        ),
                        const SizedBox(height: 10),

                        if (_files.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: const [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 40,
                                  color: AppColors.textHint,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No files here yet',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tap + below to upload',
                                  style: TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.borderSubtle,
                                width: 0.5,
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _files.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 60,
                                color: AppColors.borderSubtle,
                              ),
                              itemBuilder: (ctx, i) {
                                final file = _files[i] as Map<String, dynamic>;
                                final name = file['name'] as String;
                                final sizeKb = ((file['size'] as int) / 1024)
                                    .toStringAsFixed(1);
                                final typeColor = FileTypeHelper.getColor(name);

                                return InkWell(
                                  borderRadius: i == 0
                                      ? const BorderRadius.vertical(
                                          top: Radius.circular(14),
                                        )
                                      : i == _files.length - 1
                                      ? const BorderRadius.vertical(
                                          bottom: Radius.circular(14),
                                        )
                                      : BorderRadius.zero,
                                  onTap: FileTypeHelper.isPreviewable(name)
                                      ? () => _openPreview(
                                          file,
                                          '$_currentPath$name',
                                        )
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        // Type icon in pill
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: typeColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            FileTypeHelper.getIcon(name),
                                            color: typeColor,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$sizeKb KB',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Preview hint badge for previewable files
                                        if (FileTypeHelper.isPreviewable(name))
                                          Container(
                                            margin: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: typeColor.withOpacity(
                                                0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              FileTypeHelper.isImage(name)
                                                  ? 'IMG'
                                                  : FileTypeHelper.isVideo(name)
                                                  ? 'VID'
                                                  : 'PDF',
                                              style: TextStyle(
                                                color: typeColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.more_vert,
                                            size: 18,
                                            color: AppColors.textSecondary,
                                          ),
                                          onPressed: () =>
                                              _showFileActions(file),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _isUploading
              ? Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.cyan,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Uploading…',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : _GradientButton(
                  label: '＋  Add File',
                  onPressed: _showUploadPicker,
                ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable gradient CTA button
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.primaryGradient : null,
        color: enabled ? null : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: enabled ? null : Border.all(color: AppColors.borderSubtle),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.cyanGlow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white12,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
