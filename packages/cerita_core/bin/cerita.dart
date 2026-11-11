import 'dart:io';

import 'package:cerita_core/io.dart';

/// `dart run cerita_core:cerita lint <story folder>`, see the authoring tools spec §3.
Future<void> main(List<String> args) async {
  exitCode = await runCli(args, out: stdout, err: stderr);
}
