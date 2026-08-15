import 'package:flutter/material.dart';

import '../integrations/google/google_integration_controller.dart';
import '../integrations/google/google_models.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class GoogleIntegrationScreen extends StatefulWidget {
  const GoogleIntegrationScreen({super.key});

  @override
  State<GoogleIntegrationScreen> createState() => _GoogleIntegrationScreenState();
}

class _GoogleIntegrationScreenState extends State<GoogleIntegrationScreen> {
  final controller = GoogleIntegrationController.instance;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final state = AppStateScope.of(context);
    controller.initialize(state).catchError((Object error) {
      if (!mounted) return;
      _message('Não foi possível preparar a integração Google: $error', error: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Google & Classroom')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PageHeader(
                        title: 'Conta & Classroom',
                        subtitle: 'Conecte sua conta Google e transforme atividades do Classroom em prazos do Academia Flow.',
                      ),
                      const SizedBox(height: 16),
                      if (!controller.supported) _UnsupportedCard(message: controller.configurationMessage),
                      if (controller.supported && !controller.configured) ...[
                        _ConfigurationCard(message: controller.configurationMessage),
                        const SizedBox(height: 13),
                      ],
                      _AccountCard(
                        controller: controller,
                        onSignIn: () => _guard(controller.signIn, success: 'Conta Google conectada.'),
                        onSignOut: () => _guard(controller.signOut, success: 'Conta desconectada deste aparelho.'),
                      ),
                      if (controller.account != null) ...[
                        const SizedBox(height: 13),
                        _ClassroomCard(
                          controller: controller,
                          onConnect: () => _guard(controller.connectClassroom, success: 'Google Classroom conectado.'),
                          onRefresh: () => _guard(controller.refreshCourses, success: 'Turmas atualizadas.'),
                          onSync: () async {
                            try {
                              final report = await controller.syncClassroom();
                              if (!mounted) return;
                              _message(
                                '${report.created} novas • ${report.updated} atualizadas • ${report.completed} concluídas'
                                '${report.skippedWithoutDueDate > 0 ? ' • ${report.skippedWithoutDueDate} sem prazo ignoradas' : ''}',
                              );
                            } catch (_) {
                              if (mounted) _message(controller.error ?? 'Falha ao sincronizar o Classroom.', error: true);
                            }
                          },
                        ),
                      ],
                      if (controller.account?.classroomConnected == true) ...[
                        const SizedBox(height: 13),
                        _CoursesCard(controller: controller, state: state, onLink: _showCourseLinkDialog),
                        const SizedBox(height: 13),
                        _ImportedTasksCard(controller: controller, state: state),
                      ],
                      const SizedBox(height: 13),
                      const _PrivacyCard(),
                    ],
                  ),
                ),
              ),
            ),
            if (controller.busy)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 3, color: Theme.of(context).colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _guard(Future<void> Function() action, {required String success}) async {
    try {
      await action();
      if (mounted) _message(success);
    } catch (_) {
      if (mounted) _message(controller.error ?? 'Não foi possível concluir a operação.', error: true);
    }
  }

  Future<void> _showCourseLinkDialog(ClassroomCourse course) async {
    final state = AppStateScope.of(context);
    final suggested = controller.suggestedSubject(course);
    int? subjectId = suggested?.id ?? (state.subjects.isNotEmpty ? state.subjects.first.id : null);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Vincular • ${course.name}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggested != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text('Correspondência sugerida: ${suggested.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.subjects.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: subjectId,
                    decoration: const InputDecoration(labelText: 'Matéria existente'),
                    items: state.subjects
                        .where((subject) => subject.id != null)
                        .map((subject) => DropdownMenuItem(value: subject.id!, child: Text(subject.name)))
                        .toList(),
                    onChanged: (value) => setLocal(() => subjectId = value),
                  )
                else
                  Text('Ainda não existem matérias locais. O Academia Flow pode criar uma usando o nome da turma.', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await controller.linkCourse(course);
                  if (mounted) _message('Matéria criada e vinculada ao Classroom.');
                } catch (_) {
                  if (mounted) _message(controller.error ?? 'Falha ao criar a matéria.', error: true);
                }
              },
              child: const Text('Criar matéria'),
            ),
            FilledButton(
              onPressed: subjectId == null
                  ? null
                  : () async {
                      final subject = state.subjectById(subjectId);
                      Navigator.pop(dialogContext);
                      if (subject == null) return;
                      try {
                        await controller.linkCourse(course, subject: subject);
                        if (mounted) _message('Turma vinculada a ${subject.name}.');
                      } catch (_) {
                        if (mounted) _message(controller.error ?? 'Falha ao vincular a turma.', error: true);
                      }
                    },
              child: const Text('Vincular'),
            ),
          ],
        ),
      ),
    );
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.controller, required this.onSignIn, required this.onSignOut});
  final GoogleIntegrationController controller;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final account = controller.account;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Conta Google'),
          const SizedBox(height: 12),
          if (account == null)
            Row(
              children: [
                const _GoogleMark(),
                const SizedBox(width: 12),
                Expanded(child: Text('O login é opcional. Seus dados locais continuam funcionando sem uma conta Google.', style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: controller.busy || !controller.configured ? null : onSignIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Entrar com Google'),
                ),
              ],
            )
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
                  backgroundImage: account.photoUrl.isEmpty ? null : NetworkImage(account.photoUrl),
                  child: account.photoUrl.isEmpty ? Text(_initial(account.displayName.isEmpty ? account.email : account.displayName)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.displayName.isEmpty ? account.email : account.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      if (account.displayName.isNotEmpty) Text(account.email, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 3),
                      Text(controller.authenticated ? '● Sessão conectada' : '○ Reconecte para acessar o Google', style: TextStyle(fontSize: 11, color: controller.authenticated ? AppColors.success : AppColors.gold)),
                    ],
                  ),
                ),
                if (!controller.authenticated)
                  FilledButton(onPressed: controller.busy || !controller.configured ? null : onSignIn, child: const Text('Reconectar'))
                else
                  TextButton(onPressed: controller.busy ? null : onSignOut, child: const Text('Sair')),
              ],
            ),
        ],
      ),
    );
  }

  static String _initial(String value) => value.trim().isEmpty ? 'G' : value.trim()[0].toUpperCase();
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.controller, required this.onConnect, required this.onRefresh, required this.onSync});
  final GoogleIntegrationController controller;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final account = controller.account!;
    final connected = account.classroomConnected;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.school_rounded, color: AppColors.gold),
            const SizedBox(width: 9),
            const Expanded(child: Text('Google Classroom', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: (connected ? AppColors.success : AppColors.gold).withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
              child: Text(connected ? 'CONECTADO' : 'NÃO CONECTADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: connected ? AppColors.success : AppColors.gold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            connected
                ? '${controller.courseLinks.length} turma${controller.courseLinks.length == 1 ? '' : 's'} vinculada${controller.courseLinks.length == 1 ? '' : 's'} • ${controller.taskLinks.length} atividade${controller.taskLinks.length == 1 ? '' : 's'} acompanhada${controller.taskLinks.length == 1 ? '' : 's'}'
                : 'Autorize somente leitura para listar suas turmas, atividades, prazos e status das suas entregas.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          if (account.lastSyncAt != null) ...[
            const SizedBox(height: 5),
            Text('Última sincronização: ${_dateTime(account.lastSyncAt!)}', style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!connected)
                FilledButton.icon(onPressed: controller.busy || !controller.authenticated ? null : onConnect, icon: const Icon(Icons.link_rounded), label: const Text('Conectar Classroom'))
              else ...[
                FilledButton.icon(onPressed: controller.busy || controller.courseLinks.isEmpty ? null : onSync, icon: const Icon(Icons.sync_rounded), label: const Text('Sincronizar agora')),
                OutlinedButton.icon(onPressed: controller.busy ? null : onRefresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Atualizar turmas')),
              ],
            ],
          ),
          if (controller.lastReport != null) ...[
            const SizedBox(height: 12),
            Text(
              'Último resultado: ${controller.lastReport!.created} novas, ${controller.lastReport!.updated} atualizadas, ${controller.lastReport!.completed} concluídas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _CoursesCard extends StatelessWidget {
  const _CoursesCard({required this.controller, required this.state, required this.onLink});
  final GoogleIntegrationController controller;
  final AppState state;
  final Future<void> Function(ClassroomCourse course) onLink;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Turmas do Classroom'),
          const SizedBox(height: 6),
          Text('Vincule cada turma a uma matéria existente ou deixe o Academia Flow criar a matéria automaticamente.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          if (controller.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Nenhuma turma foi carregada nesta sessão. Toque em “Atualizar turmas” acima.', style: Theme.of(context).textTheme.bodySmall)),
              ]),
            ),
          for (final course in controller.courses)
            Builder(builder: (context) {
              final link = controller.linkForCourse(course.id);
              final subject = state.subjectById(link?.subjectId);
              final suggested = link == null ? controller.suggestedSubject(course) : null;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .10), child: const Icon(Icons.class_rounded, size: 19)),
                title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(
                  link != null
                      ? 'Vinculada a ${subject?.name ?? 'matéria local'}'
                      : suggested != null
                          ? 'Sugestão: ${suggested.name}'
                          : (course.section.isEmpty ? 'Não vinculada' : '${course.section} • não vinculada'),
                ),
                trailing: link == null
                    ? FilledButton.tonal(onPressed: controller.busy ? null : () => onLink(course), child: const Text('Vincular'))
                    : PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'open') await controller.openClassroom(course.alternateLink);
                          if (value == 'unlink') await controller.unlinkCourse(course);
                        },
                        itemBuilder: (_) => [
                          if (course.alternateLink.isNotEmpty) const PopupMenuItem(value: 'open', child: Text('Abrir no Classroom')),
                          const PopupMenuItem(value: 'unlink', child: Text('Desvincular')),
                        ],
                      ),
              );
            }),
        ],
      ),
    );
  }
}

class _ImportedTasksCard extends StatelessWidget {
  const _ImportedTasksCard({required this.controller, required this.state});
  final GoogleIntegrationController controller;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final links = controller.taskLinks.take(10).toList();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Atividades importadas'),
          const SizedBox(height: 8),
          if (links.isEmpty)
            Text('Depois da primeira sincronização, as atividades com prazo aparecerão aqui e também no Kanban.', style: Theme.of(context).textTheme.bodySmall),
          for (final link in links)
            Builder(builder: (context) {
              AcademicTask? task;
              for (final candidate in state.tasks) {
                if (candidate.id == link.taskId) {
                  task = candidate;
                  break;
                }
              }
              if (task == null) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(task!.status == TaskStatus.done ? Icons.task_alt_rounded : Icons.assignment_outlined, color: task!.status == TaskStatus.done ? AppColors.success : null),
                title: Text(task!.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${state.subjectName(task!.subjectId)} • ${_submission(link.submissionState)}'),
                trailing: link.alternateLink.isEmpty ? null : IconButton(tooltip: 'Abrir no Classroom', onPressed: () => controller.openClassroom(link.alternateLink), icon: const Icon(Icons.open_in_new_rounded)),
              );
            }),
        ],
      ),
    );
  }
}

class _ConfigurationCard extends StatelessWidget {
  const _ConfigurationCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => SoftCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.key_off_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('OAuth ainda não configurado neste build', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45)),
            const SizedBox(height: 4),
            Text('Consulte docs/GOOGLE_SETUP.md no repositório.', style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
      );
}

class _UnsupportedCard extends StatelessWidget {
  const _UnsupportedCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => SoftCard(child: Text(message));
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();
  @override
  Widget build(BuildContext context) => SoftCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Acesso mínimo', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('A integração é somente leitura: lista turmas, atividades e o status das suas próprias entregas. O Academia Flow não entrega trabalhos, não altera turmas e não modifica notas no Classroom.', style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
            ]),
          ),
        ]),
      );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).dividerColor)),
        child: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      );
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _submission(String state) => switch (state) {
      'TURNED_IN' => 'Entregue',
      'RETURNED' => 'Devolvida pelo professor',
      'RECLAIMED_BY_STUDENT' => 'Entrega cancelada pelo aluno',
      'STUDENT_EDITED_AFTER_TURN_IN' => 'Editada após entrega',
      'CREATED' => 'Não entregue',
      _ => 'Status do Classroom indisponível',
    };
