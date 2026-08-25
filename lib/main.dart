import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'services/attachment_repository.dart';
import 'services/backup_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final state = AppState();
  runApp(_AcademiaFlowStartup(state: state));
}

class _AcademiaFlowStartup extends StatefulWidget {
  const _AcademiaFlowStartup({required this.state});

  final AppState state;

  @override
  State<_AcademiaFlowStartup> createState() => _AcademiaFlowStartupState();
}

class _AcademiaFlowStartupState extends State<_AcademiaFlowStartup> {
  late Future<void> _initialization;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  void _startInitialization() {
    final generation = ++_initializationGeneration;
    final future = widget.state.initialize().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception(
        'A inicialização ultrapassou 20 segundos. Verifique acesso ao banco local e tente novamente.',
      ),
    );
    _initialization = future;
    unawaited(
      future.then((_) async {
        if (generation != _initializationGeneration) return;
        try {
          await AttachmentRepository.instance.initialize();
          await BackupService.instance.maybeCreateAutomaticBackup();
        } catch (_) {
          // Manutenção e backup em segundo plano nunca impedem a entrada no app.
        }
      }).catchError((_) {}),
    );
  }

  void _retry() => setState(_startInitialization);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
          return AcademiaFlowApp(state: widget.state);
        }

        final error = snapshot.error;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Academia Flow',
          theme: ThemeData(brightness: Brightness.dark, colorSchemeSeed: const Color(0xFF0F4C5C), useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(color: const Color(0xFF0F4C5C), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.school_rounded, color: Color(0xFFD4AF37), size: 34),
                    ),
                    const SizedBox(height: 22),
                    const Text('Academia Flow', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    if (error == null) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Preparando seu espaço acadêmico...'),
                    ] else ...[
                      const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 34),
                      const SizedBox(height: 14),
                      const Text('Não foi possível concluir a inicialização.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 10),
                      SelectableText('$error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.45)),
                      const SizedBox(height: 18),
                      FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar novamente')),
                      const SizedBox(height: 10),
                      const Text('Se o erro persistir, feche o Academia Flow completamente e copie a mensagem acima para diagnóstico.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
