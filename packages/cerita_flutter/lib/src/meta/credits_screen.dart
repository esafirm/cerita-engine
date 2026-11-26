import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../l10n/story_language.dart';
import '../skin/story_skin.dart';
import '../story_setup.dart';

/// The story's credits (`credits.json`, data schema §9) and a link to the open-source licenses. Apps show it
/// from the title screen when `setup.loader.loadCredits()` finds credits.
class CreditsScreen extends StatefulWidget {
  final StorySetup setup;

  const CreditsScreen({super.key, required this.setup});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  late Future<Credits?> _credits = widget.setup.loader.loadCredits();

  @override
  void didUpdateWidget(CreditsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setup != widget.setup) _credits = widget.setup.loader.loadCredits();
  }

  @override
  Widget build(BuildContext context) {
    final strings = StoryLanguage.of(context).strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.credits)),
      body: FutureBuilder(
        future: _credits,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("${snapshot.error}"));
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final credits = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              if (credits != null) StorySkin.of(context).credits(context, credits, rolling: false),
              const SizedBox(height: 32),
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: Text(strings.openSourceLicenses),
                  onPressed: () => showLicensePage(context: context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The default look of [StorySkin.credits]: each section with its people and roles, then the third-party
/// assets with title, author, source, license and note. Centered, in white over black when [rolling].
class CreditsList extends StatelessWidget {
  final Credits credits;
  final bool rolling;

  const CreditsList({super.key, required this.credits, this.rolling = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    final foreground = rolling ? Colors.white : theme.colorScheme.onSurface;
    final muted = foreground.withAlpha(170);
    final heading = theme.textTheme.titleMedium?.copyWith(
      color: rolling ? Colors.white : theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    );
    final name = theme.textTheme.bodyLarge?.copyWith(color: foreground, fontWeight: FontWeight.w600);
    final detail = theme.textTheme.bodySmall?.copyWith(color: muted);

    Widget section(String title, List<Widget> entries) => Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            children: [
              Text(title.toUpperCase(), style: heading, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ...entries,
            ],
          ),
        );

    Widget entry(String title, List<String?> lines) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              if (lines.first case final role?) Text(role, style: detail, textAlign: TextAlign.center),
              Text(title, style: name, textAlign: TextAlign.center),
              for (final line in lines.skip(1).nonNulls) Text(line, style: detail, textAlign: TextAlign.center),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in credits.sections)
          section(language.text(group.title), [
            for (final person in group.people) entry(language.text(person.name), [language.maybe(person.role)]),
          ]),
        if (credits.assets.isNotEmpty)
          section(strings.thirdPartyAssets, [
            for (final asset in credits.assets)
              entry(language.text(asset.title), [
                null,
                strings.creditAuthor(asset.author),
                strings.creditSource(asset.source),
                strings.creditLicense(asset.license),
                language.maybe(asset.note),
              ]),
          ]),
      ],
    );
  }
}

/// Credits scrolling up over black, after an ending listed in `roll_after`. A tap skips them. [onDone] runs
/// once, when they have scrolled past or are skipped.
class RollingCredits extends StatefulWidget {
  /// Scroll speed in logical pixels per second.
  static const speed = 40.0;

  final Credits credits;
  final VoidCallback onDone;

  const RollingCredits({super.key, required this.credits, required this.onDone});

  @override
  State<RollingCredits> createState() => _RollingCreditsState();
}

class _RollingCreditsState extends State<RollingCredits> {
  final _scroll = ScrollController();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      final distance = _scroll.position.maxScrollExtent;
      final seconds = distance / RollingCredits.speed;
      await _scroll.animateTo(
        distance,
        duration: Duration(milliseconds: (seconds * 1000).round().clamp(1000, 600000)),
        curve: Curves.linear,
      );
      _finish();
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = StoryLanguage.of(context).strings;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: ColoredBox(
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              // Starts below the screen and scrolls until the last line has left at the top.
              SingleChildScrollView(
                controller: _scroll,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: constraints.maxHeight),
                child: StorySkin.of(context).credits(context, widget.credits, rolling: true),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: Text(strings.tapToSkip, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
