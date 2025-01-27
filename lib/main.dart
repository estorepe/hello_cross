import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
      // Use system temp directory (works without app ID configuration)
      final tempDir = Directory.systemTemp;
      final binDir = Directory(join(tempDir.path, 'flutter_bin'));

      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      final executable = File(join(binDir.path, name));

      // Debugging output
      debugPrint('Binary path: ${executable.path}');

      if (!await executable.exists()) {
        // Load from bundled assets
        final byteData = await rootBundle.load('assets/native/linux/$name');
        await executable.writeAsBytes(
          byteData.buffer.asUint8List(),
          flush: true,
        );
        debugPrint('Copied binary to temp directory');
      }

      // Set execute permissions
      await Process.run('chmod', ['+x', executable.path]);

      // Execute and return output
      final result = await Process.run(executable.path, []);
      return result.stdout.toString().trim();
    } catch (e) {
      return 'Error: ${e.toString()}';
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
          final binaryName = binaries[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: FutureBuilder<String>(
              future: runBinary(binaryName),
              builder: (context, snapshot) {
                final content = snapshot.hasData
                    ? snapshot.data!
                    : snapshot.hasError
                        ? 'Error: ${snapshot.error}'
                        : 'Loading...';
                
                return ListTile(
                  title: Text(
                    binaryName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(content),
                  leading: const Icon(Icons.terminal),
                  trailing: snapshot.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator()
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
