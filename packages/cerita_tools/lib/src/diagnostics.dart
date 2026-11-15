/// A position in a story source file. [file] is relative to the story folder, with `/` separators.
class SourceSpan implements Comparable<SourceSpan> {
  final String file;
  final int line;

  const SourceSpan(this.file, this.line);

  @override
  int compareTo(SourceSpan other) {
    final byFile = file.compareTo(other.file);
    return byFile != 0 ? byFile : line.compareTo(other.line);
  }

  @override
  bool operator ==(Object other) => other is SourceSpan && other.file == file && other.line == line;

  @override
  int get hashCode => Object.hash(file, line);

  @override
  String toString() => "$file:$line";
}

enum Severity { error, warning, note }

class Diagnostic {
  final Severity severity;
  final String message;
  final SourceSpan? span;

  const Diagnostic(this.severity, this.message, [this.span]);

  /// `file:line: severity: message`, with the file mapped through [displayPath].
  String format([String Function(String file)? displayPath]) {
    final span = this.span;
    final where = span == null ? "" : "${displayPath?.call(span.file) ?? span.file}:${span.line}: ";
    return "$where${severity.name}: $message";
  }

  @override
  String toString() => format();
}

/// Collects every problem found, so one run reports all of them and not just the first.
class Diagnostics {
  final List<Diagnostic> _items = [];

  List<Diagnostic> get items => List.unmodifiable(_items);

  void error(SourceSpan? span, String message) => _items.add(Diagnostic(Severity.error, message, span));

  void warning(SourceSpan? span, String message) => _items.add(Diagnostic(Severity.warning, message, span));

  void note(SourceSpan? span, String message) => _items.add(Diagnostic(Severity.note, message, span));

  void add(Diagnostic diagnostic) => _items.add(diagnostic);

  void addAll(Diagnostics other) => _items.addAll(other._items);

  int count(Severity severity) => sorted().where((d) => d.severity == severity).length;

  bool get hasErrors => _items.any((d) => d.severity == Severity.error);

  bool get isEmpty => _items.isEmpty;

  /// Sorted by file and line. Problems without a position come first. Duplicates are dropped.
  List<Diagnostic> sorted() {
    final seen = <String>{};
    final unique = _items.where((d) => seen.add("${d.span}|${d.severity}|${d.message}")).toList();
    int bySpan(SourceSpan? a, SourceSpan? b) {
      if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
      return a.compareTo(b);
    }

    // List.sort isn't stable, so ties are broken on every field to keep the output deterministic.
    unique.sort((a, b) {
      final span = bySpan(a.span, b.span);
      if (span != 0) return span;
      final severity = a.severity.index.compareTo(b.severity.index);
      return severity != 0 ? severity : a.message.compareTo(b.message);
    });
    return unique;
  }
}
