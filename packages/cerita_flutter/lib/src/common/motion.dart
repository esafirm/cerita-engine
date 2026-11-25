import 'package:flutter/widgets.dart';

/// Whether the player asked the platform to reduce motion (the accessibility setting that removes animations).
/// Shakes, weather, `{shake}` / `{wave}` text and camera moves then hold still.
bool get reduceMotion => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
