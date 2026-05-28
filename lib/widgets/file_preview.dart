import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../theme.dart';
import '../services/storage_service.dart';

/// Full-screen preview for images, videos, and PDFs.
/// Tap an image to enter/exit; videos have play/pause/scrub controls.
/// PDFs open in the device browser (presigned URL already grants access).
class FilePreviewPage extends StatefulWidget {
  final String fileName;
  final String fileKey;
  final String jwtToken;

  const FilePreviewPage({
    super.key,
    required this.fileName,
    required this.fileKey,
    required this.jwtToken,
  });

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  String? _url;
  bool _loading = true;
  String? _error;

  VideoPlayerController? _videoCtrl;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchUrl();
  }

  Future<void> _fetchUrl() async {
    final url = await StorageService.getDownloadUrl(
      widget.jwtToken,
      widget.fileKey,
    );
    if (!mounted) return;

    if (url == null) {
      setState(() {
        _loading = false;
        _error = 'Could not generate download link.';
      });
      return;
    }

    setState(() => _url = url);

    // For PDFs: auto-launch browser immediately
    if (FileTypeHelper.isPdf(widget.fileName)) {
      setState(() => _loading = false);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri))
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    // For videos: initialize controller
    if (FileTypeHelper.isVideo(widget.fileName)) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await _videoCtrl!.initialize();
        if (mounted)
          setState(() {
            _loading = false;
            _videoInitialized = true;
          });
      } catch (e) {
        if (mounted)
          setState(() {
            _loading = false;
            _error = 'Could not load video: $e';
          });
      }
      return;
    }

    // Images: just set loading false and let Image.network handle the rest
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.6),
        foregroundColor: Colors.white,
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_url != null)
            IconButton(
              icon: const Icon(
                Icons.open_in_browser_outlined,
                color: Colors.white70,
              ),
              tooltip: 'Open in browser',
              onPressed: () async {
                final uri = Uri.parse(_url!);
                if (await canLaunchUrl(uri))
                  launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.cyan,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading ${widget.fileName}…',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (FileTypeHelper.isImage(widget.fileName)) return _buildImageViewer();
    if (FileTypeHelper.isVideo(widget.fileName)) return _buildVideoPlayer();
    if (FileTypeHelper.isPdf(widget.fileName)) return _buildPdfPlaceholder();
    return _buildUnsupported();
  }

  // ── Image viewer ─────────────────────────────────────────────────────────

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6.0,
      child: Center(
        child: Image.network(
          _url!,
          fit: BoxFit.contain,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            final pct = progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null;
            return Center(
              child: CircularProgressIndicator(
                value: pct,
                color: AppColors.cyan,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (ctx, err, _) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: Colors.white30,
                ),
                SizedBox(height: 12),
                Text(
                  'Image could not be loaded',
                  style: TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Video player ──────────────────────────────────────────────────────────

  Widget _buildVideoPlayer() {
    if (!_videoInitialized || _videoCtrl == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2),
      );
    }

    return Column(
      children: [
        // Video
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _videoCtrl!.value.isPlaying
                  ? _videoCtrl!.pause()
                  : _videoCtrl!.play();
            }),
            child: Center(
              child: AspectRatio(
                aspectRatio: _videoCtrl!.value.aspectRatio,
                child: VideoPlayer(_videoCtrl!),
              ),
            ),
          ),
        ),

        // Controls
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            children: [
              // Progress + scrubbing
              VideoProgressIndicator(
                _videoCtrl!,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                colors: const VideoProgressColors(
                  playedColor: AppColors.cyan,
                  bufferedColor: Color(0x3300C8FA),
                  backgroundColor: Color(0xFF1A2847),
                ),
              ),

              // Play/pause + time
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoCtrl!,
                builder: (ctx, val, _) {
                  return Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          val.isPlaying
                              ? Icons.pause_circle_outlined
                              : Icons.play_circle_outlined,
                          color: AppColors.cyan,
                          size: 36,
                        ),
                        onPressed: () => setState(() {
                          val.isPlaying
                              ? _videoCtrl!.pause()
                              : _videoCtrl!.play();
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_fmt(val.position)} / ${_fmt(val.duration)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── PDF placeholder ───────────────────────────────────────────────────────

  Widget _buildPdfPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.filePdf.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.filePdf,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'In-app PDF rendering coming soon.\nOpening in your browser now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              icon: const Icon(Icons.open_in_browser, color: AppColors.filePdf),
              label: const Text(
                'Open in browser',
                style: TextStyle(color: AppColors.filePdf),
              ),
              onPressed: () async {
                final uri = Uri.parse(_url!);
                if (await canLaunchUrl(uri))
                  launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupported() {
    return Center(
      child: Text(
        'Preview not available for ${FileTypeHelper.isImage(widget.fileName) ? 'this image' : 'this file type'}.',
        style: const TextStyle(color: Colors.white38),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
