import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../audio_helper.dart';
import '../l10n/localized_assets.dart';
import '../l10n/story_language.dart';
import 'story_sheet.dart';

/// A picture at full size, pinch to zoom, with its caption under it. [open] shows it in a full-screen sheet in the
/// skin's frame, grown out of the thumbnail that was tapped.
class ImageViewerPage extends StatelessWidget {
  /// The picture flying between its thumbnail and the viewer, while the viewer opens or closes.
  static const flightKey = ValueKey("picture flight");

  final String asset;
  final String? caption;

  /// Set by [open] when the picture flies in: the viewer leaves its own copy out until it lands, and says where
  /// that is.
  final PictureFlight? flight;

  const ImageViewerPage({super.key, required this.asset, this.caption, this.flight});

  /// Opens [asset]. With [from], the context of the thumbnail tapped, the picture grows out of that thumbnail and
  /// shrinks back into it on close, while the frame fades in around it.
  static Future<void> open(BuildContext context, String asset, {String? caption, BuildContext? from}) {
    final navigator = Navigator.of(context);
    final origin = _rectOf(from, navigator.overlay?.context.findRenderObject());
    return navigator.push(_PictureRoute(
      asset: asset,
      flight: origin == null ? null : PictureFlight(origin),
      title: StoryLanguage.of(context).strings.photo,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      caption: caption,
    ));
  }

  /// Where [context]'s box is in [ancestor], or null when either has no layout.
  static Rect? _rectOf(BuildContext? context, RenderObject? ancestor) {
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    final route = ModalRoute.of(context);
    final viewer = ClipRect(
      child: InteractiveViewer(maxScale: 5, child: Center(child: Image.asset(asset))),
    );
    final flight = this.flight;
    final animation = route?.animation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: flight == null || animation == null
                ? viewer
                : _LandingSpot(
                    flight: flight,
                    overlay: Navigator.of(context).overlay,
                    // The flying copy stands in for the picture until it lands.
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, viewer) =>
                          animation.status == AnimationStatus.completed ? viewer! : const SizedBox.expand(),
                      child: viewer,
                    ),
                  ),
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Text(caption, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          ),
      ],
    );
  }
}

/// A picture's way from its thumbnail to the viewer: where it starts, and where the viewer's picture box turns
/// out to be once laid out. Both are in the navigator's overlay.
class PictureFlight {
  final Rect origin;
  final ValueNotifier<Rect?> landing = ValueNotifier(null);

  PictureFlight(this.origin);
}

/// Reports where its child sits to [flight], after each layout.
class _LandingSpot extends StatelessWidget {
  final PictureFlight flight;
  final OverlayState? overlay;
  final Widget child;

  const _LandingSpot({required this.flight, required this.overlay, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final rect = ImageViewerPage._rectOf(context, overlay?.context.findRenderObject());
        if (rect != null) flight.landing.value = rect;
      });
      return child;
    });
  }
}

/// The picture viewer's route: the sheet frame fades in over a dimmed screen, and the picture flies above it,
/// so the fade doesn't touch the picture.
class _PictureRoute extends PopupRoute<void> {
  final String asset;
  final String? caption;
  final String title;
  final PictureFlight? flight;

  _PictureRoute({
    required this.asset,
    required this.title,
    required this.barrierLabel,
    this.caption,
    this.flight,
  });

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: StorySheet.frame(
          context,
          title: title,
          icon: Icons.image_outlined,
          fullScreen: true,
          builder: (_) => ImageViewerPage(asset: asset, caption: caption, flight: flight),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final frame = FadeTransition(
      opacity: animation.drive(CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut))),
      child: child,
    );
    final flight = this.flight;
    if (flight == null) return frame;
    return Stack(
      fit: StackFit.expand,
      children: [frame, IgnorePointer(child: _Flight(asset: asset, flight: flight, animation: animation))],
    );
  }

  @override
  void dispose() {
    flight?.landing.dispose();
    super.dispose();
  }
}

/// The picture on its way: from the thumbnail's box to the picture's fitted box in the viewer, cropped like the
/// thumbnail at the start and whole at the end.
class _Flight extends StatefulWidget {
  final String asset;
  final PictureFlight flight;
  final Animation<double> animation;

  const _Flight({required this.asset, required this.flight, required this.animation});

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener((image, _) {
    if (mounted) setState(() => _size = Size(image.image.width.toDouble(), image.image.height.toDouble()));
  });
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    // The thumbnail loaded it already, so this is usually answered from the cache right away.
    _stream = AssetImage(widget.asset).resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.animation;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, widget.flight.landing]),
      child: Image.asset(widget.asset, fit: BoxFit.cover, gaplessPlayback: true),
      builder: (context, image) {
        final box = widget.flight.landing.value;
        final status = animation.status;
        if (box == null || status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          return const SizedBox.shrink();
        }
        final size = _size;
        final landing = size == null
            ? box
            : Alignment.center.inscribe(applyBoxFit(BoxFit.contain, size, box.size).destination, box);
        final t = Curves.easeInOutCubic.transform(animation.value);
        return Stack(
          children: [
            Positioned.fromRect(
              key: ImageViewerPage.flightKey,
              rect: Rect.lerp(widget.flight.origin, landing, t)!,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * (1 - t)),
                child: image,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Voice note player: play/pause, progress bar, duration and a transcript toggle.
/// With [assets], it plays the clip of the active language when the story has one.
class VoiceNotePlayer extends StatefulWidget {
  final String asset;
  final String? transcript;
  /// Ducked while the note plays. Its voice volume is the note's volume.
  final AudioHelper? audio;

  /// The volume without an [audio], e.g. the player's voice volume in the Gallery.
  final double? volume;
  final LocalizedAssets? assets;
  final Color? color;

  const VoiceNotePlayer({
    super.key,
    required this.asset,
    this.transcript,
    this.audio,
    this.volume,
    this.assets,
    this.color,
  });

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
  String? _source;

  @override
  void initState() {
    super.initState();
    _player.setVolume(widget.audio?.voiceVolume ?? widget.volume ?? 1);
    _subscriptions.addAll([
      _player.onPositionChanged.listen((position) {
        if (mounted) setState(() => _position = position);
      }),
      _player.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      }),
      _player.onPlayerComplete.listen((_) => _setPlaying(false, reset: true)),
    ]);
  }

  @override
  void didUpdateWidget(VoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final volume = widget.audio?.voiceVolume ?? widget.volume ?? 1;
    final oldVolume = oldWidget.audio?.voiceVolume ?? oldWidget.volume ?? 1;
    if (volume != oldVolume) _player.setVolume(volume);
    if (oldWidget.asset != widget.asset) {
      if (_playing) {
        _player.stop();
        _setPlaying(false, reset: true);
      }
      _source = null;
      _load(StoryLanguage.of(context).localizer.activeLocale);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Picks the clip again after a language switch, unless it is playing.
    if (!_playing) _load(StoryLanguage.of(context).localizer.activeLocale);
  }

  Future<void> _load(String locale) async {
    final source = await widget.assets?.resolve(widget.asset, locale) ?? widget.asset;
    if (!mounted || source == _source) return;
    _source = source;
    try {
      await _player.setSource(AssetSource(source));
      final duration = await _player.getDuration();
      if (mounted && duration != null) setState(() => _duration = duration);
    } catch (_) {
      // A missing clip leaves the player empty rather than breaking the bubble.
    }
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
    final strings = StoryLanguage.of(context).strings;
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
            Text(_format(_playing ? _position : _duration), style: TextStyle(fontSize: 12, color: widget.color)),
          ],
        ),
        if (widget.transcript != null)
          TextButton.icon(
            style: widget.color == null ? null : TextButton.styleFrom(foregroundColor: widget.color),
            onPressed: () => setState(() => _showTranscript = !_showTranscript),
            icon: const Icon(Icons.subtitles_outlined, size: 16),
            label: Text(_showTranscript ? strings.hideTranscript : strings.showTranscript),
          ),
        if (_showTranscript && widget.transcript != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(widget.transcript!, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: widget.color)),
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
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    StoryLanguage.of(context).strings.video,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
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
      _controller
        ..setVolume(widget.audio?.voiceVolume ?? 1)
        ..play();
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
