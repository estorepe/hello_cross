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
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6F42C1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6F42C1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
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

      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      final binaryName = getBinaryName(name);
      final executable = File(path.join(binDir.path, binaryName));
      final assetPath = 'assets/native/$platformDir/$arch/$binaryName';

      final byteData = await rootBundle.load(assetPath);
      await executable.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', executable.path]);
      }

      final result = await Process.run(executable.path, [],
          runInShell: Platform.isWindows);

      if (result.exitCode != 0) {
        throw Exception('Execution failed: ${result.stderr}');
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
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: archDir,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildPlatformInfo(snapshot.data!),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: binaries.length,
                  itemBuilder: (context, index) => _BinaryListItem(
                    name: binaries[index],
                    onRun: runBinary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlatformInfo(String arch) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Platform: ${platformDir.toUpperCase()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Architecture: ${arch.toUpperCase()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Text(
          'Runs pre-compiled native binaries from different programming languages.\n\n'
          'Binaries are executed in a temporary directory with appropriate permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _BinaryListItem extends StatefulWidget {
  final String name;
  final Future<String> Function(String) onRun;

  const _BinaryListItem({required this.name, required this.onRun});

  @override
  State<_BinaryListItem> createState() => _BinaryListItemState();
}

class _BinaryListItemState extends State<_BinaryListItem> {
  String _output = '';
  bool _isRunning = false;

  Future<void> _executeBinary() async {
    setState(() {
      _isRunning = true;
      _output = '';
    });

    try {
      final result = await widget.onRun(widget.name);
      setState(() => _output = result);
    } catch (e) {
      setState(() => _output = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _executeBinary,
                    child: _isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Run'),
                  ),
                ),
              ],
            ),
            if (_output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _output,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: _output.startsWith('Error:')
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _output)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
