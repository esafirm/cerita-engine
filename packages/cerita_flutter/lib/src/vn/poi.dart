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

  const PoiActor({required this.id, required this.sprite, required this.position});
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
  });

  /// Slot x positions while only the three inner slots are used: wide apart, partly off-screen.
  static const _wideX = {SpritePosition.left: -1.3, SpritePosition.center: 0.0, SpritePosition.right: 1.3};

  /// The widest a sprite may be, as a share of the stage width, with [present] characters on stage. Only
  /// narrow stages hit it: there a lone character keeps the full width and two or more stand side by side,
  /// overlapping a little in the middle.
  static double widthShare(int present) => switch (present) {
        <= 1 => 1.0,
        2 => 0.62,
        _ => 0.46,
      };

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

  _ActorEntry(this.actor, this.controller);
}

class _PoiState extends State<Poi> with TickerProviderStateMixin {
  static const _moveDuration = Duration(milliseconds: 300);

  final Map<String, _ActorEntry> _entries = {};
  late final AnimationController _shake = AnimationController(vsync: this);
  late final AnimationController _flash = AnimationController(vsync: this, value: 1);
  double _shakeIntensity = 0;
  Color _flashColor = Colors.white;

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
    final entries = _entries.values.toList();
    final xs = entries.any((e) => !Poi._wideX.containsKey(e.actor.position)) ? Poi._fiveX : Poi._wideX;
    final present = entries.where((e) => !e.leaving).length;
    final backgroundAction = _action<BackgroundAction>();
    final backgroundTransition = backgroundAction?.transition;
    final zoom = _action<ZoomAction>();
    final speaker = widget.speakerId;

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
          // A fixed paint order: moving the speaker to the front made the sprites swap places in one frame.
          for (final entry in entries)
            AnimatedAlign(
              key: ValueKey(entry.actor.id),
              duration: _duration(
                _action<MoveAction>((action) => action.profileId == entry.actor.id),
                _moveDuration,
              ),
              curve: Curves.easeInOut,
              alignment: Alignment(xs[entry.actor.position] ?? 0, 1),
              // On a narrow (portrait) stage a sprite would be as wide as the stage, so every slot would put it in
              // the middle. Capping its width lets the characters on stage stand side by side.
              child: LayoutBuilder(
                builder: (context, box) => ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * Poi.widthShare(present)),
                  child: FractionallySizedBox(
                    heightFactor: present > 2 ? 0.66 : 0.82,
                    child: entry.transition == null
                        ? skin.spriteTransition(entry.controller, _sprite(entry, speaker))
                        : stageTransition(entry.transition!, entry.controller, _sprite(entry, speaker)),
                  ),
                ),
              ),
            ),
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

  Widget _sprite(_ActorEntry entry, String? speaker) =>
      _SpriteSlot(sprite: entry.actor.sprite, active: speaker == null || speaker == entry.actor.id);
}

/// One character. Cross-fades expression changes and dims when someone else speaks.
class _SpriteSlot extends StatelessWidget {
  final String sprite;
  final bool active;

  const _SpriteSlot({required this.sprite, required this.active});

  @override
  Widget build(BuildContext context) {
    final skin = StorySkin.of(context);
    return AnimatedScale(
      scale: active ? 1.04 : 0.97,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 250),
      child: AnimatedSwitcher(
        duration: skin.spriteTransitionDuration,
        // The new expression fades in over the old one in the first half, and the old one fades out under it in
        // the second. A plain cross-fade leaves both half see-through midway, which shows what's behind.
        transitionBuilder: (child, animation) =>
            skin.spriteTransition(CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)), child),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(sprite),
          tween: Tween(end: active ? 0 : 0.45),
          duration: const Duration(milliseconds: 250),
          builder: (context, dim, child) => ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withAlpha((dim * 255).round()), BlendMode.srcATop),
            child: child,
          ),
          child: Image.asset(
            sprite,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            gaplessPlayback: true,
            // A missing sprite should not break the scene.
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
