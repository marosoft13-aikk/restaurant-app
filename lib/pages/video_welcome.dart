// Debug-friendly, asset-first VideoWelcomePage.
// Shows clear errors and allows trying a public test video.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoWelcomePage extends StatefulWidget {
  const VideoWelcomePage({super.key});

  @override
  State<VideoWelcomePage> createState() => _VideoWelcomePageState();
}

class _VideoWelcomePageState extends State<VideoWelcomePage> {
  VideoPlayerController? _controller;
  bool _isEnded = false;
  bool _loading = true;
  String? _error;

  // test video to check player capability if asset fails
  static const _testVideo =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    _initAsset();
  }

  Future<void> _initAsset() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // try asset first
      _controller = VideoPlayerController.asset('assets/videos/welcome.mp4');
      await _controller!.initialize();
      _controller!..play();
      _controller!.addListener(_listener);
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      debugPrint('Asset init failed: $e\n$st');
      setState(() {
        _loading = false;
        _error = 'Failed to initialize asset video: $e';
      });
    }
  }

  Future<void> _playTestNetwork() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _disposeController();
      _controller = VideoPlayerController.network(_testVideo);
      await _controller!.initialize();
      _controller!..play();
      _controller!.addListener(_listener);
      setState(() {
        _loading = false;
        _error = 'Playing test network video (configured asset failed).';
      });
    } catch (e, st) {
      debugPrint('Test network init failed: $e\n$st');
      setState(() {
        _loading = false;
        _error = 'Test video also failed: $e';
      });
    }
  }

  void _listener() {
    if (_controller == null) return;
    if (_controller!.value.isInitialized) {
      if (_controller!.value.position >= _controller!.value.duration &&
          !_isEnded) {
        _isEnded = true;
        _goToMenu();
      }
      // update UI for progress/play
      if (mounted) setState(() {});
    }
  }

  Future<void> _disposeController() async {
    try {
      _controller?.removeListener(_listener);
      await _controller?.pause();
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  void _goToMenu() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/menu');
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Widget _playerWidget() {
    final c = _controller!;
    final dur = c.value.duration;
    final pos = c.value.position;
    return GestureDetector(
      onTap: () {
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
              child: AspectRatio(
                  aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
          if (!c.value.isPlaying)
            const Center(
                child: Icon(Icons.play_arrow, color: Colors.white70, size: 64)),
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: Column(
              children: [
                VideoProgressIndicator(c,
                    allowScrubbing: true,
                    colors: VideoProgressColors(playedColor: Colors.orange)),
                const SizedBox(height: 6),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(pos),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      Text(_formatDuration(dur),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: (_controller != null && _controller!.value.isInitialized)
                  ? _playerWidget()
                  : _buildErrorPane(),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: ElevatedButton.icon(
                onPressed: _goToMenu,
                icon: const Icon(Icons.skip_next),
                label: const Text('تخطي'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('مرحبًا بك في بروستاكي',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('استمتع بأفضل الوجبات',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPane() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off, color: Colors.white54, size: 80),
          const SizedBox(height: 12),
          Text(_error ?? 'Video is unavailable',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _initAsset,
            icon: const Icon(Icons.refresh),
            label: const Text('Try asset again'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
          const SizedBox(width: 12, height: 12),
          ElevatedButton.icon(
            onPressed: _playTestNetwork,
            icon: const Icon(Icons.play_circle),
            label: const Text('Play test network video'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _goToMenu,
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip to Menu'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}
