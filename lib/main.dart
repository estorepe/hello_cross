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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(8),
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
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
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
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.4,
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isRunning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 20),
                label: Text(_isRunning ? 'Running...' : 'Run Binary'),
                onPressed: _isRunning ? null : _executeBinary,
              ),
            ),
            if (_output.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
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
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _output)),
                    ),
                  ],
                ),
              ),
            ],
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
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}
