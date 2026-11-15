import 'dart:io';

import 'package:cerita_tools/cerita_tools.dart';

Future<void> main(List<String> args) async {
  exitCode = await CeritaCli(stdout, stderr).run(args);
}
