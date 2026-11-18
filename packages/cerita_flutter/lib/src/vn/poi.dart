import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../skin/story_skin.dart';
import 'stage_transitions.dart';
import 'weather_layer.dart';

/// A character on the [Poi] stage.
class PoiActor {
  /// Profile id. A character keeps its widget while it moves between slots or changes expression.
  final String id;

  /// Sprite asset path.
  final String sprite;
  final SpritePosition position;

  /// How tall the character is ([Profile.height]). Null takes them as tall as the tallest one in the [PoiCast].
  final double? height;

  /// Where the face is on the sprite ([Profile.face]). Null takes the sprite as head to toe.
  final SpriteFace? face;

  const PoiActor({required this.id, required this.sprite, required this.position, this.height, this.face});

  /// [height] and [face] from [profile].
  PoiActor.of(Profile profile, {required this.sprite, required this.position})
      : id = profile.id,
        height = profile.height,
        face = profile.face;
}

/// The measures that size every sprite on the stage alike, like one camera on the whole cast: a taller character
/// stands taller with a bigger face, and a sprite cut higher up the body stands lower, so every cut stays under the
/// stage's bottom edge.
class PoiCast {
  /// The tallest character's height.
  final double tallest;

  /// How high above the floor the highest sprite reaches, its hair included.
  final double top;

  /// The highest cut: how far above the floor the sprite cut highest up the body ends.
  final double highestCut;

  const PoiCast({this.tallest = 1, double? top, this.highestCut = 0}) : top = top ?? tallest;

  /// The measures of [cast]. A null height is as tall as the tallest.
  factory PoiCast.of(Iterable<({double? height, SpriteFace? face})> cast) {
    final heights = [for (final member in cast) ?member.height];
    final tallest = heights.isEmpty ? 1.0 : heights.reduce(max);
    var top = 0.0;
    var highestCut = 0.0;
    for (final member in cast) {
      final reach = span(member.height ?? tallest, member.face);
      top = max(top, reach.top);
      highestCut = max(highestCut, reach.bottom);
    }
    return PoiCast(tallest: tallest, top: cast.isEmpty ? tallest : top, highestCut: highestCut);
  }

  /// The measures of the characters in [profiles] that have sprites.
  factory PoiCast.ofProfiles(Iterable<Profile> profiles) => PoiCast.of([
    for (final profile in profiles)
      if (profile.sprites.isNotEmpty) (height: profile.height, face: profile.face),
  ]);

  /// How high above the floor the top and bottom edges of a sprite reach, for a character [height] tall whose face
  /// is at [face] on it. Its eyes sit at the height of a person's eyes, and its eyes to chin is a person's
  /// ([SpriteFace.eyeToChin]): that sets how long the whole sprite is. Without [face], the sprite is head to toe.
  static ({double top, double bottom}) span(double height, SpriteFace? face) {
    if (face == null) return (top: height, bottom: 0);
    final eyeToChin = SpriteFace.eyeToChin * height;
    final length = eyeToChin / max(face.chin - face.eyes, 0.01);
    final top = height - eyeToChin + face.eyes * length;
    return (top: top, bottom: top - length);
  }

  /// [actor]'s span, a null height as tall as the tallest.
  ({double top, double bottom}) _spanOf(PoiActor actor) => span(actor.height ?? tallest, actor.face);
}

/// [Poi] draws the VN stage: background, up to five characters, weather and the camera
/// (zoom, shake, flash). The active speaker is full opacity and slightly larger; others are dimmed.
///
/// [direction] is the `STAGE` item being played. Its transitions are used for the changes it
/// makes, and its shake / flash play once when it arrives.
class Poi extends StatefulWidget {
  final String? background;
  final List<PoiActor> actors;

  /// Profile id of the speaker. Null makes every character active.
  final String? speakerId;
  final StageItemType? direction;
  final double zoom;
  final SpritePosition zoomFocus;
  final String? weather;

  /// Applies every change without animating, e.g. while skipping.
  final bool instant;

  /// The measures of the whole cast, so a character keeps their size whoever is on stage. Null measures the
  /// [actors] on stage.
  final PoiCast? cast;

  const Poi({
    super.key,
    this.background,
    this.actors = const [],
    this.speakerId,
    this.direction,
    this.zoom = 1,
    this.zoomFocus = SpritePosition.center,
    this.weather,
    this.instant = false,
    this.cast,
  });

  /// Slot x positions while only the three inner slots are used: wide apart. See [_PoiState._slotCenter].
  static const _wideX = {SpritePosition.left: -1.3, SpritePosition.center: 0.0, SpritePosition.right: 1.3};

  /// How high the tallest head of the cast reaches, as a share of the stage height, with [present] characters on
  /// stage. A fractional [present] is between two counts, while the share eases from one to the other. On a
  /// [narrow] (portrait) stage the camera barely pulls back for a crowd: the characters overlap instead of
  /// shrinking into dolls against the background.
  static double heightShare(num present, {bool narrow = false}) =>
      narrow ? _between(present, 0.82, 0.8, 0.66) : _between(present, 0.82, 0.82, 0.66);

  /// How far apart, as a share of the stage width, [count] characters stand on a narrow stage.
  static double spacing(int count) => switch (count) {
    <= 2 => 0.5,
    3 => 0.34,
    4 => 0.27,
    _ => 0.22,
  };

  static double _between(num present, double one, double two, double more) {
    final count = present.clamp(1, 3).toDouble();
    return count <= 2 ? one + (two - one) * (count - 1) : two + (more - two) * (count - 2);
  }

  static const _fiveX = {
    SpritePosition.farLeft: -1.5,
    SpritePosition.left: -0.75,
    SpritePosition.center: 0.0,
    SpritePosition.right: 0.75,
    SpritePosition.farRight: 1.5,
  };

  @override
  State<Poi> createState() => _PoiState();
}

class _ActorEntry {
  PoiActor actor;
  final AnimationController controller;
  StageTransition? transition;
  bool leaving = false;

  /// The center x on a narrow stage, kept while the character leaves.
  double? narrowX;

  _ActorEntry(this.actor, this.controller);
}

class _PoiState extends State<Poi> with TickerProviderStateMixin {
  static const _moveDuration = Duration(milliseconds: 300);

  final Map<String, _ActorEntry> _entries = {};
  late final AnimationController _shake = AnimationController(vsync: this);
  late final AnimationController _flash = AnimationController(vsync: this, value: 1);
  double _shakeIntensity = 0;
  Color _flashColor = Colors.white;

  /// Characters on stage that size the sprites, 1 to 3. See [Poi.heightShare].
  int _crowd = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // First build: needs the skin, so it can't run in initState.
    if (_entries.isEmpty && widget.actors.isNotEmpty) _syncActors(initial: true);
  }

  @override
  void initState() {
    super.initState();
    _playCues();
  }

  @override
  void didUpdateWidget(Poi oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncActors();
    if (!identical(widget.direction, oldWidget.direction)) _playCues();
  }

  @override
  void dispose() {
    for (final entry in _entries.values) {
      entry.controller.dispose();
    }
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  /// The last action of type [T] in [Poi.direction] that matches [test].
  T? _action<T extends StageAction>([bool Function(T action)? test]) =>
      widget.direction?.actions.whereType<T>().where(test ?? (_) => true).lastOrNull;

  Duration _duration(StageAction? action, Duration fallback) =>
      widget.instant ? Duration.zero : (action == null ? fallback : Duration(milliseconds: action.durationMs));

  /// Starts enter animations for new characters and exit animations for removed ones.
  /// On the [initial] build, only characters shown by [Poi.direction] animate in.
  void _syncActors({bool initial = false}) {
    final skin = StorySkin.of(context);
    final ids = {for (final actor in widget.actors) actor.id};

    for (final actor in widget.actors) {
      final entry = _entries[actor.id];
      if (entry != null && !entry.leaving) {
        entry.actor = actor;
        continue;
      }
      final show = _action<ShowAction>((action) => action.profile.id == actor.id);
      final added = entry ?? _ActorEntry(actor, AnimationController(vsync: this));
      _entries[actor.id] = added
        ..actor = actor
        ..leaving = false
        ..transition = show?.transition;
      added.controller.duration = _duration(show, skin.spriteTransitionDuration);
      if (widget.instant || (initial && show == null)) {
        added.controller.value = 1;
      } else {
        added.controller.forward();
      }
    }

    for (final MapEntry(key: id, value: entry) in _entries.entries.toList()) {
      if (ids.contains(id) || entry.leaving) continue;
      final hide = _action<HideAction>((action) => action.profileId == null || action.profileId == id);
      entry
        ..leaving = true
        ..transition = hide?.transition;
      entry.controller.duration = _duration(hide, skin.spriteTransitionDuration);
      if (widget.instant) {
        _remove(id);
      } else {
        entry.controller.reverse().whenComplete(() {
          if (mounted && entry.leaving && identical(_entries[id], entry)) setState(() => _remove(id));
        });
      }
    }
  }

  void _remove(String id) => _entries.remove(id)?.controller.dispose();

  void _playCues() {
    if (widget.instant) return;
    final shake = _action<ShakeAction>();
    if (shake != null) {
      _shakeIntensity = shake.intensity;
      _shake.duration = Duration(milliseconds: shake.durationMs);
      _shake.forward(from: 0);
    }
    final flash = _action<FlashAction>();
    if (flash != null) {
      _flashColor = _parseColor(flash.color);
      _flash.duration = Duration(milliseconds: flash.durationMs);
      _flash.forward(from: 0);
    }
  }

  static Color _parseColor(String hex) {
    final digits = hex.replaceFirst("#", "");
    final value = int.tryParse(digits, radix: 16) ?? 0xFFFFFF;
    return Color(digits.length > 6 ? value : 0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final skin = StorySkin.of(context);
    final backgroundAction = _action<BackgroundAction>();
    final backgroundTransition = backgroundAction?.transition;
    final zoom = _action<ZoomAction>();

    final stage = AnimatedScale(
      scale: widget.zoom,
      alignment: Alignment((Poi._fiveX[widget.zoomFocus]! / 1.5).clamp(-1.0, 1.0), 0),
      duration: _duration(zoom, const Duration(milliseconds: 500)),
      curve: Curves.easeInOut,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: _duration(backgroundAction, skin.backgroundTransitionDuration),
            transitionBuilder: (child, animation) => backgroundTransition == null
                ? skin.backgroundTransition(animation, child)
                : stageTransition(backgroundTransition, animation, child, keepOutgoing: true),
            layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: widget.background == null
                ? Container(key: const ValueKey("no-bg"), color: Colors.black)
                : Image.asset(widget.background!, key: ValueKey(widget.background), fit: BoxFit.cover, gaplessPlayback: true),
          ),
          LayoutBuilder(builder: (context, box) => _characters(skin, box)),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        AnimatedBuilder(
          animation: _shake,
          child: Stack(
            fit: StackFit.expand,
            children: [
              stage,
              if (widget.weather != null) WeatherLayer(weather: widget.weather!),
            ],
          ),
          builder: (context, child) {
            final t = _shake.value;
            final dx = sin(t * pi * 10) * _shakeIntensity * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) => _flash.value >= 1
                ? const SizedBox.shrink()
                : ColoredBox(color: _flashColor.withValues(alpha: 1 - Curves.easeOut.transform(_flash.value))),
          ),
        ),
      ],
    );
  }

  /// The characters on a stage of size [box].
  Widget _characters(StorySkin skin, BoxConstraints box) {
    final entries = _entries.values.toList();
    final present = entries.where((e) => !e.leaving).toList();
    // While the last characters leave, they keep their size.
    if (present.isNotEmpty) _crowd = min(present.length, 3);
    final width = box.maxWidth;
    final narrow = width < box.maxHeight;
    final xs = entries.any((e) => !Poi._wideX.containsKey(e.actor.position)) ? Poi._fiveX : Poi._wideX;
    final speaker = widget.speakerId;
    final cast =
        widget.cast ?? PoiCast.of([for (final e in entries) (height: e.actor.height, face: e.actor.face)]);

    // Eases the size over the sprite transition, so the others don't jump when a character enters or leaves.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _crowd.toDouble()),
      duration: widget.instant ? Duration.zero : skin.spriteTransitionDuration,
      curve: Curves.easeInOut,
      builder: (context, crowd, _) {
        // One scale for everyone: the highest head of the cast reaches the crowd's share of the stage height.
        final scale = box.maxHeight * Poi.heightShare(crowd, narrow: narrow) / max(cast.top - cast.highestCut, 1e-6);
        double spriteHeight(_ActorEntry entry) {
          final reach = cast._spanOf(entry.actor);
          return (reach.top - reach.bottom) * scale;
        }
        if (narrow) _spread(present, width, spriteHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            // A fixed paint order: moving the speaker to the front made the sprites swap places in one frame.
            for (final entry in entries)
              _character(skin, entry, cast, scale, spriteHeight(entry), width, narrow, xs, speaker),
          ],
        );
      },
    );
  }

  Widget _character(
    StorySkin skin,
    _ActorEntry entry,
    PoiCast cast,
    double scale,
    double spriteHeight,
    double stageWidth,
    bool narrow,
    Map<SpritePosition, double> xs,
    String? speaker,
  ) {
    final actor = entry.actor;
    // How far the sprite's bottom edge sits below the stage's: the cut highest up the body sits right on it.
    final drop = (cast.highestCut - cast._spanOf(actor).bottom) * scale;
    final center = (narrow ? entry.narrowX : null) ?? _slotCenter(xs[actor.position] ?? 0, stageWidth);
    return Positioned(
      key: ValueKey(actor.id),
      left: 0,
      right: 0,
      bottom: -drop,
      height: spriteHeight,
      child: AnimatedAlign(
        duration: _duration(_action<MoveAction>((action) => action.profileId == actor.id), _moveDuration),
        curve: Curves.easeInOut,
        alignment: Alignment(stageWidth == 0 ? 0 : 2 * center / stageWidth - 1, 1),
        // A zero-wide anchor at the character's center, the sprite as wide as it is drawn around it.
        child: SizedBox(
          width: 0,
          height: spriteHeight,
          child: OverflowBox(
            maxWidth: double.infinity,
            alignment: Alignment.bottomCenter,
            child: entry.transition == null
                ? skin.spriteTransition(entry.controller, _sprite(entry, speaker))
                : stageTransition(entry.transition!, entry.controller, _sprite(entry, speaker)),
          ),
        ),
      ),
    );
  }

  /// The center of slot [x] on a stage [stageWidth] wide: the far slots (±1.5) a twelfth of the width in from the
  /// edges, so a character there is half on screen, the middle one in the middle.
  static double _slotCenter(double x, double stageWidth) => stageWidth * (0.5 + x / 3.6);

  /// Places the [present] characters on a narrow stage, as centers in [stageWidth]. There the slots can't keep
  /// their spacing: a `far_*` slot would push its character off the edge and the inner ones would cover each other.
  /// So they stand evenly around the middle, left to right in slot order, as close as [Poi.spacing] says and
  /// overlapping a little like people in one shot. A lone character stands at its slot, kept on screen.
  void _spread(List<_ActorEntry> present, double stageWidth, double Function(_ActorEntry) spriteHeight) {
    final ordered = present.toList()..sort((a, b) => a.actor.position.index.compareTo(b.actor.position.index));
    final xs = ordered.any((e) => !Poi._wideX.containsKey(e.actor.position)) ? Poi._fiveX : Poi._wideX;
    final gap = stageWidth * Poi.spacing(ordered.length);
    for (final (rank, entry) in ordered.indexed) {
      if (ordered.length == 1) {
        // Kept on screen: a sprite of the usual 1:2 shape stays inside the edges.
        final half = min(spriteHeight(entry) / 4, stageWidth / 2);
        entry.narrowX = _slotCenter(xs[entry.actor.position]!, stageWidth).clamp(half, stageWidth - half);
        continue;
      }
      entry.narrowX = stageWidth / 2 + (rank - (ordered.length - 1) / 2) * gap;
    }
  }

  Widget _sprite(_ActorEntry entry, String? speaker) =>
      _SpriteSlot(sprite: entry.actor.sprite, active: speaker == null || speaker == entry.actor.id);
}

/// One character. Cross-fades expression changes and dims when someone else speaks.
///
/// A new expression waits until its image is decoded before the cross-fade starts. A pose not shown before takes
/// a moment to decode on a phone, and the old one used to fade out on time over an empty slot, so the character
/// blinked out mid-change.
class _SpriteSlot extends StatefulWidget {
  final String sprite;
  final bool active;

  const _SpriteSlot({required this.sprite, required this.active});

  @override
  State<_SpriteSlot> createState() => _SpriteSlotState();
}

class _SpriteSlotState extends State<_SpriteSlot> {
  /// The expression on screen, which [_SpriteSlot.sprite] replaces once it is decoded.
  late String _shown = widget.sprite;
  ImageStream? _loading;
  ImageStreamListener? _listener;

  @override
  void didUpdateWidget(_SpriteSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sprite != oldWidget.sprite) _load(widget.sprite);
  }

  void _load(String sprite) {
    _stopLoading();
    if (sprite == _shown) return;
    void ready(bool synchronous) {
      _stopLoading();
      if (!mounted || widget.sprite != sprite) return;
      // A cached image answers while this widget updates, before its build: no setState then.
      synchronous ? _shown = sprite : setState(() => _shown = sprite);
    }

    final listener = ImageStreamListener(
      (image, synchronous) {
        image.dispose();
        ready(synchronous);
      },
      // A missing sprite shows as nothing, at once.
      onError: (error, stackTrace) => ready(false),
    );
    _listener = listener;
    _loading = AssetImage(sprite).resolve(createLocalImageConfiguration(context))..addListener(listener);
  }

  void _stopLoading() {
    if (_listener case final listener?) _loading?.removeListener(listener);
    _loading = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopLoading();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = StorySkin.of(context);
    final active = widget.active;
    return AnimatedScale(
      scale: active ? 1.04 : 0.97,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 250),
      child: AnimatedSwitcher(
        duration: skin.spriteTransitionDuration,
        // Stands on the stage floor. The default layout centers the sprite in its slot, which is taller than the
        // sprite on a portrait stage, so the cut-off legs floated above the bottom edge.
        layoutBuilder: (current, previous) =>
            Stack(alignment: Alignment.bottomCenter, children: [...previous, ?current]),
        // The new expression fades in over the old one in the first half, and the old one fades out under it in
        // the second. A plain cross-fade leaves both half see-through midway, which shows what's behind.
        // drive() adds no listeners until the transition listens, so nothing is left to dispose.
        transitionBuilder: (child, animation) =>
            skin.spriteTransition(animation.drive(CurveTween(curve: const Interval(0, 0.5))), child),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_shown),
          tween: Tween(end: active ? 0 : 0.45),
          duration: const Duration(milliseconds: 250),
          builder: (context, dim, child) => ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withAlpha((dim * 255).round()), BlendMode.srcATop),
            child: child,
          ),
          child: Image.asset(
            _shown,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            gaplessPlayback: true,
            // A missing sprite should not break the scene.
            // As tall as the slot, however small the image file is.
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
