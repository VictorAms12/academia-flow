import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
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
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = widget.state.initialize().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception(
        'A inicialização ultrapassou 20 segundos. Verifique acesso ao banco local e reinicie o aplicativo.',
      ),
    );
  }

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
          theme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF0F4C5C),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F4C5C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.school_rounded, color: Color(0xFFD4AF37), size: 34),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Academia Flow',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      if (error == null) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Preparando seu espaço acadêmico...'),
                      ] else ...[
                        const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 34),
                        const SizedBox(height: 14),
                        const Text(
                          'Não foi possível concluir a inicialização.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          '$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, height: 1.45),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Feche o Academia Flow pelo Gerenciador de Tarefas, abra novamente e, se o erro persistir, copie a mensagem acima.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
