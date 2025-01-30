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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(4),
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

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Native Binary Runner'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This app demonstrates running native binaries from different languages:'),
            SizedBox(height: 8),
            Text('• C Binary: Simple Hello World'),
            Text('• C++ Binary: Basic console output'),
            Text('• Rust Binary: Command line program'),
            Text('• Go Binary: Terminal application'),
            SizedBox(height: 8),
            Text('Each binary is compiled for your specific platform and architecture.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Binary Runner'),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Show information about the binaries',
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
              _buildSystemInfo(context, snapshot.data!),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: binaries.length,
                  itemBuilder: (context, index) =>
                      _BinaryCard(
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

  Widget _buildSystemInfo(BuildContext context, String arch) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoItem(
            icon: Icons.computer,
            label: 'Platform',
            value: platformDir.toUpperCase(),
          ),
          _InfoItem(
            icon: Icons.architecture,
            label: 'Architecture',
            value: arch.toUpperCase(),
          ),
        ],
      ),
    );
  }
}

class _BinaryCard extends StatefulWidget {
  final String name;
  final Future<String> Function(String) onRun;

  const _BinaryCard({required this.name, required this.onRun});

  @override
  State<_BinaryCard> createState() => _BinaryCardState();
}

class _BinaryCardState extends State<_BinaryCard> {
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton.icon(
                icon: _isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 16),
                label: Text(
                  _isRunning ? 'Running...' : 'Run',
                  style: const TextStyle(fontSize: 13),
                ),
                onPressed: _isRunning ? null : _executeBinary,
              ),
            ),
            if (_output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Text(
                          _output,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: _output.startsWith('Error:')
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        tooltip: 'Copy output',
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: _output)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
