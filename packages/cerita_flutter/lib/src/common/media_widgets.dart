import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../audio_helper.dart';

/// Full-screen pinch-to-zoom image viewer.
class ImageViewerPage extends StatelessWidget {
  final String asset;
  final String? caption;

  const ImageViewerPage({super.key, required this.asset, this.caption});

  static Future<void> open(BuildContext context, String asset, {String? caption}) {
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ImageViewerPage(asset: asset, caption: caption),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(maxScale: 5, child: Center(child: Image.asset(asset))),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(caption!, style: const TextStyle(color: Colors.white70)),
            ),
        ],
      ),
    );
  }
}

/// Voice note player: play/pause, progress bar, duration and a transcript toggle.
class VoiceNotePlayer extends StatefulWidget {
  final String asset;
  final String? transcript;
  final AudioHelper? audio;
  final Color? color;

  const VoiceNotePlayer({super.key, required this.asset, this.transcript, this.audio, this.color});

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioHelper.createPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _showTranscript = false;

  @override
  void initState() {
    super.initState();
    _player.setSource(AssetSource(widget.asset)).then((_) async {
      final duration = await _player.getDuration();
      if (mounted && duration != null) setState(() => _duration = duration);
    }).catchError((_) {});
    _subscriptions.addAll([
      _player.onPositionChanged.listen((position) => setState(() => _position = position)),
      _player.onDurationChanged.listen((duration) => setState(() => _duration = duration)),
      _player.onPlayerComplete.listen((_) => _setPlaying(false, reset: true)),
    ]);
  }

  void _setPlaying(bool playing, {bool reset = false}) {
    if (_playing == playing) return;
    playing ? widget.audio?.duck() : widget.audio?.unduck();
    if (!mounted) return;
    setState(() {
      _playing = playing;
      if (reset) _position = Duration.zero;
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      _setPlaying(false);
    } else {
      await _player.resume();
      _setPlaying(true);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    if (_playing) widget.audio?.unduck();
    _player.dispose();
    super.dispose();
  }

  String _format(Duration duration) =>
      "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, "0")}";

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final progress = _duration.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / _duration.inMilliseconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _toggle,
              icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: color, size: 36),
            ),
            SizedBox(
              width: 140,
              child: _Waveform(progress: progress.clamp(0, 1), color: color),
            ),
            const SizedBox(width: 8),
            Text(_format(_playing ? _position : _duration), style: const TextStyle(fontSize: 12)),
          ],
        ),
        if (widget.transcript != null)
          TextButton.icon(
            onPressed: () => setState(() => _showTranscript = !_showTranscript),
            icon: const Icon(Icons.subtitles_outlined, size: 16),
            label: Text(_showTranscript ? "Hide transcript" : "Show transcript"),
          ),
        if (_showTranscript && widget.transcript != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(widget.transcript!, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
          ),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  static const _bars = [0.3, 0.6, 0.9, 0.5, 0.7, 1.0, 0.4, 0.8, 0.6, 0.3, 0.7, 0.9, 0.5, 0.4, 0.8, 0.6, 0.3, 0.5];

  final double progress;
  final Color color;

  const _Waveform({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _bars.length; i++)
            Container(
              width: 3,
              height: 28 * _bars[i],
              decoration: BoxDecoration(
                color: i / _bars.length <= progress ? color : color.withAlpha(70),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline video preview with a play overlay. Tapping opens [VideoPlayerPage].
class VideoPreview extends StatelessWidget {
  final String asset;
  final String? caption;
  final AudioHelper? audio;

  const VideoPreview({super.key, required this.asset, this.caption, this.audio});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => VideoPlayerPage.open(context, asset, caption: caption, audio: audio),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2B3A67), Color(0xFF0E1428)],
                ),
              ),
            ),
            const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 56)),
            const Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                children: [
                  Icon(Icons.videocam, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text("Video", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String asset;
  final String? caption;
  final AudioHelper? audio;

  const VideoPlayerPage({super.key, required this.asset, this.caption, this.audio});

  static Future<void> open(BuildContext context, String asset, {String? caption, AudioHelper? audio}) {
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VideoPlayerPage(asset: asset, caption: caption, audio: audio),
    ));
  }

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller = VideoPlayerController.asset(
    widget.asset,
    // Without this the video takes audio focus and the BGM pauses for good (see AudioHelper.createPlayer).
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );

  @override
  void initState() {
    super.initState();
    widget.audio?.duck();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.audio?.unduck();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: value.isInitialized
                  ? GestureDetector(
                      onTap: () => value.isPlaying ? _controller.pause() : _controller.play(),
                      child: AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(_controller)),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
          if (value.isInitialized) VideoProgressIndicator(_controller, allowScrubbing: true),
          if (widget.caption != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.caption!, style: const TextStyle(color: Colors.white70)),
            ),
        ],
      ),
    );
  }
}
