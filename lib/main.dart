import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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

  // Platform and architecture detection
  String get platformDir {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'linux';
  }

  Future<String> get archDir async {
    if (Platform.isLinux) {
      final result = await Process.run('uname', ['-m']);
      return result.stdout.toString().trim() == 'aarch64' ? 'arm64' : 'x64';
    }
    // Windows and macOS are x64 only in our configuration
    return 'x64';
  }

  String getBinaryName(String base) {
    if (Platform.isWindows) return '$base.exe';
    return base;
  }

  Future<String> runBinary(String name) async {
    try {
      final arch = await archDir;
      final tempDir = await getTemporaryDirectory();
      final binDir = Directory(path.join(tempDir.path, 'flutter_bin'));

      // Create binary directory if it doesn't exist
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      final binaryName = getBinaryName(name);
      final executable = File(path.join(binDir.path, binaryName));
      final assetPath = 'assets/native/$platformDir/$arch/$binaryName';

      debugPrint('Platform: $platformDir');
      debugPrint('Architecture: $arch');
      debugPrint('Binary name: $binaryName');
      debugPrint('Asset path: $assetPath');
      debugPrint('Executable path: ${executable.path}');

      // Copy binary from assets if it doesn't exist or is outdated
      try {
        final byteData = await rootBundle.load(assetPath);
        await executable.writeAsBytes(
          byteData.buffer.asUint8List(),
          flush: true,
        );
        debugPrint('Binary copied successfully');

        // Set execute permissions on Unix-like systems
        if (!Platform.isWindows) {
          final result = await Process.run('chmod', ['+x', executable.path]);
          if (result.exitCode != 0) {
            throw Exception('Failed to set execute permissions: ${result.stderr}');
          }
        }
      } catch (e) {
        throw Exception('Failed to copy binary: $e');
      }

      // Run the binary
      final result = await Process.run(
        executable.path,
        [],
        runInShell: Platform.isWindows,
      );

      if (result.exitCode != 0) {
        throw Exception('Binary execution failed: ${result.stderr}');
      }

      return result.stdout.toString().trim();
    } catch (e) {
      debugPrint('Error running binary: $e');
      return 'Error: ${e.toString()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Binary Runner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<String>(
        future: archDir,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error detecting architecture: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'System Information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('Platform: $platformDir'),
                        Text('Architecture: ${snapshot.data}'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: binaries.length,
                  itemBuilder: (context, index) {
                    final binaryName = binaries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
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
                            leading: Icon(
                              snapshot.hasError
                                  ? Icons.error_outline
                                  : Icons.terminal,
                              color: snapshot.hasError ? Colors.red : null,
                            ),
                            trailing: snapshot.connectionState ==
                                    ConnectionState.waiting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
