import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final course = TextEditingController();
  final period = TextEditingController();
  final semester = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    course.dispose();
    period.dispose();
    semester.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final intro = _IntroPanel(dark: state.isDark, onTheme: state.toggleTheme);
                  final form = _ProfileForm(
                    formKey: formKey,
                    name: name,
                    course: course,
                    period: period,
                    semester: semester,
                    saving: saving,
                    onSave: () => _save(state),
                  );
                  if (wide) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: intro),
                      const SizedBox(width: 18),
                      Expanded(child: form),
                    ]);
                  }
                  return Column(children: [intro, const SizedBox(height: 16), form]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(AppState state) async {
    if (saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      await state.saveProfile(
        name: name.text,
        courseName: course.text,
        periodName: period.text,
        semesterName: semester.text,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar seu perfil: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.dark, required this.onTheme});
  final bool dark;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.petroleum, Color(0xFF123A44), AppColors.petroleumDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.gold.withValues(alpha: .18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.school_rounded, color: AppColors.gold)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Academia Flow', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
            IconButton(onPressed: onTheme, color: Colors.white, icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
          ]),
          const SizedBox(height: 34),
          const Text('Sua vida acadêmica,\nsem planilhas soltas.', style: TextStyle(color: Colors.white, fontSize: 31, height: 1.12, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
          const SizedBox(height: 12),
          const Text('Organize matérias, notas, faltas, tarefas, materiais e horários em um único aplicativo offline.', style: TextStyle(color: Color(0xFFD5E2E5), height: 1.55)),
          const SizedBox(height: 26),
          const _Feature(icon: Icons.offline_bolt_rounded, text: 'Dados salvos no aparelho e disponíveis offline'),
          const SizedBox(height: 12),
          const _Feature(icon: Icons.insights_rounded, text: 'Médias, frequência e riscos calculados automaticamente'),
          const SizedBox(height: 12),
          const _Feature(icon: Icons.check_circle_outline_rounded, text: 'Tarefas com prazos, status e checklist'),
        ]),
      );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
      ]);
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({required this.formKey, required this.name, required this.course, required this.period, required this.semester, required this.saving, required this.onSave});
  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController course;
  final TextEditingController period;
  final TextEditingController semester;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(26), border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .35))),
        child: Form(
          key: formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Configure seu espaço', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.8)),
            const SizedBox(height: 6),
            Text('Esses dados podem ser alterados depois nas configurações.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 22),
            TextFormField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Seu nome *', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (v) => v == null || v.trim().isEmpty ? 'Informe seu nome' : null),
            const SizedBox(height: 12),
            TextFormField(controller: course, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Curso *', hintText: 'Ex.: Análise e Desenvolvimento de Sistemas', prefixIcon: Icon(Icons.school_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'Informe seu curso' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: period, decoration: const InputDecoration(labelText: 'Período', hintText: 'Ex.: 2º'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: semester, decoration: const InputDecoration(labelText: 'Semestre', hintText: 'Ex.: 2026.2'))),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_rounded),
                label: Text(saving ? 'Salvando...' : 'Começar a organizar'),
              ),
            ),
          ]),
        ),
      );
}
