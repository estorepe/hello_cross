import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<String> runBinary(String name) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final binDir = Directory(join(dir.path, 'bin'));
    
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    final executable = File(join(binDir.path, name));
    
    if (!await executable.exists()) {
      final byteData = await rootBundle.load('assets/native/linux/$name');
      await executable.writeAsBytes(byteData.buffer.asUint8List());
      await executable.setPermissions(await executable.stat().then((stats) => stats.mode | 0x100));
    }

    final result = await Process.run(executable.path, []);
    return result.stdout;
  } catch (e) {
    return 'Error: $e';
  }
}
