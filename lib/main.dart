import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // Add this import for Directory, File, and Process

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Binary Runner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BinaryRunnerScreen(),
    );
  }
}

class BinaryRunnerScreen extends StatefulWidget {
  const BinaryRunnerScreen({super.key});

  @override
  State<BinaryRunnerScreen> createState() => _BinaryRunnerScreenState();
}

class _BinaryRunnerScreenState extends State<BinaryRunnerScreen> {
  final binaries = [
    'hello_c',
    'hello_cpp',
    'hello_rust',
    'hello_go',
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Binary Runner'),
      ),
      body: ListView.builder(
        itemCount: binaries.length,
        itemBuilder: (context, index) {
          return FutureBuilder<String>(
            future: runBinary(binaries[index]),
            builder: (context, snapshot) {
              return ListTile(
                title: Text(binaries[index]),
                subtitle: Text(snapshot.data ?? 'Loading...'),
              );
            },
          );
        },
      ),
    );
  }
}
