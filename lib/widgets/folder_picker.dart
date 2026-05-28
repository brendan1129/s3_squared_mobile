import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/storage_service.dart';

/// A bottom sheet that lets the user navigate their S3 folder tree and
/// select a destination. Returns the chosen path string (trailing slash,
/// or "" for root) via Navigator.pop when "Move here" is tapped.
class FolderPickerSheet extends StatefulWidget {
  final String jwtToken;

  /// The folder that already contains the file being moved.
  /// That folder will be shown as disabled so you can't "move" to where it is.
  final String excludeFolder;

  const FolderPickerSheet({
    super.key,
    required this.jwtToken,
    required this.excludeFolder,
  });

  @override
  State<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<FolderPickerSheet> {
  String _browsePath = "";
  List<String> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _loading = true);
    final contents = await StorageService.fetchDirectoryContents(
      widget.jwtToken,
      virtualPath: _browsePath,
    );
    if (mounted) {
      setState(() {
        _folders = List<String>.from(contents['folders']!);
        _loading = false;
      });
    }
  }

  void _navigateTo(String path) {
    setState(() => _browsePath = path);
    _loadFolders();
  }

  void _navigateUp() {
    if (_browsePath.isEmpty) return;
    final segments = _browsePath.split('/').where((s) => s.isNotEmpty).toList();
    segments.removeLast();
    _navigateTo(segments.isEmpty ? "" : "${segments.join('/')}/");
  }

  bool get _isCurrentFolder => _browsePath == widget.excludeFolder;

  // The display label for where we're currently browsing
  String get _currentLabel {
    if (_browsePath.isEmpty) return 'Root';
    final parts = _browsePath.split('/').where((s) => s.isNotEmpty).toList();
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                if (_browsePath.isNotEmpty)
                  GestureDetector(
                    onTap: _navigateUp,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    'Move to: $_currentLabel',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Breadcrumb path display
          if (_browsePath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '/ ${_browsePath.replaceAll('/', ' / ').trimRight()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const Divider(height: 1),

          // Folder list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.cyan,
                      strokeWidth: 2,
                    ),
                  )
                : _folders.isEmpty
                ? const Center(
                    child: Text(
                      'No subfolders here',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _folders.length,
                    itemBuilder: (ctx, i) {
                      final folder = _folders[i];
                      final name = folder.split('/').reversed.skip(1).first;
                      return ListTile(
                        leading: const Icon(
                          Icons.folder_outlined,
                          color: AppColors.cyan,
                          size: 20,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onTap: () => _navigateTo(folder),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // Move here button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: _GradientButton(
              label: _browsePath.isEmpty ? 'Move to Root' : 'Move Here',
              enabled: !_isCurrentFolder,
              disabledLabel: 'File is already here',
              onPressed: () => Navigator.pop(context, _browsePath),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared gradient button used in this sheet and the main screen ─────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final String? disabledLabel;
  final bool enabled;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.disabledLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.primaryGradient : null,
        color: enabled ? null : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: enabled ? null : Border.all(color: AppColors.borderSubtle),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.cyanGlow,
                  blurRadius: 14,
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
          child: Center(
            child: Text(
              enabled ? label : (disabledLabel ?? label),
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
