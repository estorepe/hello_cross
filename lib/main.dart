import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
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
      title: 'Native Code Runner',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
  final List<BinaryInfo> binaries = [
    BinaryInfo('Execute C Code', 'hello_c'),
    BinaryInfo('Run C++ Program', 'hello_cpp'),
    BinaryInfo('Run Rust Code', 'hello_rust'),
    BinaryInfo('Execute Go Program', 'hello_go'),
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
        title: const Text('Native Code Runner'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.info_circle),
            onPressed: _showInfoDialog,
          ).animate().shake(delay: 1000.ms),
        ],
      ).animate().fadeIn(duration: 300.ms),
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
                    info: binaries[index],
                    onRun: runBinary,
                  )
                      .animate(delay: (100 * index).ms)
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: 0.2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlatformInfo(String arch) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Iconsax.cpu, size: 16),
              const SizedBox(width: 8),
              Text(
                'Platform: ${platformDir.toUpperCase()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Iconsax.diagram, size: 16),
              const SizedBox(width: 8),
              Text(
                'Architecture: ${arch.toUpperCase()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Iconsax.info_circle, size: 24),
            SizedBox(width: 12),
            Text('About'),
          ],
        ),
        content: const Text(
          'Execute pre-compiled native binaries from various programming languages.\n\n'
          'Binaries run in isolated temporary storage with appropriate permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ).animate().scaleXY(begin: 0.8),
    );
  }
}

class BinaryInfo {
  final String title;
  final String name;

  BinaryInfo(this.title, this.name);
}

class _BinaryListItem extends StatefulWidget {
  final BinaryInfo info;
  final Future<String> Function(String) onRun;

  const _BinaryListItem({required this.info, required this.onRun});

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
      final result = await widget.onRun(widget.info.name);
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
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.info.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.info.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _executeBinary,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRunning)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .spin(duration: 800.ms)
                        else
                          const Icon(Iconsax.play, size: 18),
                        if (!_isRunning) const SizedBox(width: 8),
                        if (!_isRunning) const Text('Run'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _output,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontFamily: 'monospace',
                                color: _output.startsWith('Error:')
                                    ? Colors.redAccent
                                    : Colors.lightGreenAccent,
                              ),
                        ).animate().fadeIn().slideY(begin: -0.2),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.copy, size: 16),
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
              ),
          ],
        ),
      ),
    );
  }
}
