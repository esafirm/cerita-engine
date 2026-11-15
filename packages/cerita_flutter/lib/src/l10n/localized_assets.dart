import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/services.dart';

/// Finds the per-locale variant of an asset (`vo.en.mp3` for `vo.mp3`) in the bundle's asset manifest.
class LocalizedAssets {
  final AssetBundle bundle;
  Future<Set<String>>? _loading;
  Set<String>? _assets;

  LocalizedAssets([AssetBundle? bundle]) : bundle = bundle ?? rootBundle;

  /// Loads the manifest once. `StoryLanguage.load` and story screens call it, so [resolveNow] is ready
  /// by the first voiced line.
  Future<void> preload() => _manifest();

  /// [path] in [locale] if the bundle has it, else [path] itself.
  Future<String> resolve(String path, String locale) async {
    await _manifest();
    return resolveNow(path, locale);
  }

  /// Like [resolve], without waiting: [path] itself while the manifest is still loading.
  String resolveNow(String path, String locale) {
    final localized = localizedAssetName(path, locale);
    return (_assets?.contains(localized) ?? false) ? localized : path;
  }

  Future<Set<String>> _manifest() => _loading ??= AssetManifest.loadFromAssetBundle(bundle)
      .then((manifest) => manifest.listAssets().toSet())
      .catchError((Object _) => <String>{})
      .then((assets) => _assets = assets);
}
