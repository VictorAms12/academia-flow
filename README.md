# Academia Flow

Aplicativo acadêmico offline-first em Flutter para organizar rotina universitária, matérias, atividades, notas, frequência, horários, aulas, anotações, materiais e integração opcional com Google Classroom.

## Versão atual

**2.6.1+20 — Rotina Inteligente**

A linha 2.6 evolui o uso diário do app com Hoje 2.0, planejador semanal, foco inteligente de tarefas, Presença 2.0, Notas 2.0, nota rápida vinculada à aula e central de avisos. A 2.6.1 adiciona um fluxo de salvamento de horários mais confiável e feedback explícito para ações rápidas.

## Principais recursos

- Dashboard Hoje 2.0 com aula atual, prioridades, carga acadêmica, frequência e avisos.
- Matérias com professor, local, frequência mínima e planejamento de carga.
- Horários semanais com geração de sessões de aula, lembretes e quantidade de aulas por bloco.
- Presença por sessão: presente, falta, pendente ou cancelada.
- Presença 2.0 com projeção, faltas restantes, histórico editável, observações e desfazer.
- Atividades em Kanban/calendário, prioridades, tipos, checklist, lembretes e vínculo com aula.
- Foco de Atividades com ranking de urgência e atalhos para adiar, duplicar ou concluir.
- Notas e médias ponderadas com simulador e Laboratório de Notas 2.0.
- Planejador semanal de blocos de estudo com duração, matéria, horário e conclusão.
- Anotações e materiais por matéria e por aula.
- Nota rápida automática durante a aula atual.
- Central de avisos acadêmicos para atrasos, provas próximas, presença pendente e risco de frequência/desempenho.
- Busca global.
- Tema claro/escuro.
- SQLite local como fonte principal dos dados.
- Integração Google/Classroom opcional e somente leitura.
- Android e Windows usando a mesma base Flutter.

## Academia Flow 2.6.1

### Salvamento de horários

Ao criar ou editar um horário, o app agora:

1. bloqueia cliques repetidos enquanto salva;
2. mostra progresso enquanto recalcula as próximas sessões de aula;
3. informa erros diretamente no diálogo;
4. confirma quando o horário e as próximas aulas foram atualizados.

Isso evita a impressão de que o botão Salvar não respondeu durante a atualização da rotina.

### Foco de Atividades

As ações de adiar prazo, duplicar e concluir passam a emitir feedback imediato. Adiamentos e conclusão também oferecem **Desfazer** pelo SnackBar.

## Rotina acadêmica

Cada horário pode representar uma ou mais aulas (`classCount`). O Academia Flow gera sessões futuras e permite registrar presença por sessão. A frequência projetada da matéria considera os registros resolvidos e o total planejado configurado.

Aulas futuras não podem ser marcadas como presente/falta antes de começar. Cancelamentos futuros continuam permitidos.

## Google Classroom

A integração é opcional. O aplicativo pode autenticar uma conta Google, listar turmas e importar atividades do Classroom para o banco local. O fluxo é read-only: o Academia Flow não envia trabalhos ou alterações para o Classroom.

Consulte `docs/GOOGLE_SETUP.md` para configuração OAuth.

## Dados

O banco SQLite local continua sendo a fonte de verdade do aplicativo. O app funciona sem conexão para os recursos acadêmicos principais.

## Build Android

O workflow `.github/workflows/build-android.yml` gera o projeto Android, restaura a assinatura persistente, aplica configurações de launcher/notificações/Google, executa analyzer e testes e gera a APK Release.

A assinatura deve ser preservada entre versões para permitir instalação de atualizações sobre a APK anterior sem limpar dados.

## Build Windows

O workflow `.github/workflows/build-windows.yml` valida a mesma base Dart/Flutter e gera o pacote portátil Windows x64.

## Estrutura principal

```text
lib/
  data/          SQLite
  integrations/  Google / Classroom
  models/        modelos acadêmicos e recursos da 2.6
  screens/       telas
  services/      notificações
  state/         estado e controladores
  theme/         design system
  widgets/       componentes e diálogos
```

## Qualidade

Antes de uma release, a CI executa:

```bash
flutter analyze
flutter test
flutter build apk --release
```

O objetivo é manter o aplicativo offline-first, rápido e previsível, especialmente em operações críticas como presença, edição de horários e persistência de tarefas.
