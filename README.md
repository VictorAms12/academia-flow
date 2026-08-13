# Academia Flow 2.0 — Pronto para uso

Aplicativo Flutter de organização universitária com armazenamento local SQLite e build automático pelo GitHub Actions.

## O que mudou na versão 2.0

Esta versão inicia **sem dados fictícios**. No primeiro acesso o usuário configura nome, curso, período e semestre.

Os dados cadastrados ficam salvos localmente no aparelho:

- matérias;
- professor e sala/local;
- quantidade de aulas e faltas;
- tarefas, provas e trabalhos;
- prioridades, prazos, status e checklists;
- notas e pesos;
- horários semanais;
- anotações, resumos e links de materiais;
- preferências do usuário e critérios de risco.

## Recursos

### Dashboard
- resumo calculado com dados reais;
- média geral;
- frequência média;
- atividades concluídas e pendentes;
- próximos prazos;
- agenda do dia;
- atalhos rápidos.

### Matérias
- adicionar, editar e excluir;
- média ponderada por disciplina;
- controle de frequência;
- horários por matéria;
- tarefas e provas;
- notas e pesos;
- anotações e links.

### Atividades
- Kanban: A Fazer, Em Andamento e Concluído;
- calendário acadêmico;
- prioridade alta, média e baixa;
- prazo;
- descrição;
- checklist por etapas;
- animação ao concluir.

### Analytics
- média geral;
- frequência média;
- desempenho por matéria;
- notas recentes;
- alertas de risco configuráveis.

### Horários
- agenda por dia;
- visão semanal;
- edição e exclusão dos horários.

### Configurações
- editar perfil;
- alterar média mínima e frequência mínima;
- modo claro/escuro;
- apagar somente dados acadêmicos;
- redefinir totalmente o aplicativo com confirmação por texto.

## Armazenamento

O aplicativo usa SQLite por meio do pacote `sqflite`.

Os dados ficam no armazenamento privado do aplicativo. Desinstalar o app ou usar "Limpar dados" nas configurações do Android remove o banco local.

## Build pelo GitHub

O projeto contém:

```text
.github/workflows/build-android.yml
```

Ao enviar para a branch `main`, o GitHub executa automaticamente:

```text
Checkout
Java 17
Flutter Stable
flutter create . --platforms=android
flutter pub get
flutter analyze
flutter test
flutter build apk --release
Upload do APK
```

### Baixar o APK

No repositório:

1. Abra **Actions**.
2. Entre em **Build Android APK**.
3. Abra a execução concluída.
4. Vá até **Artifacts**.
5. Baixe **academia-flow-apk**.
6. Extraia `app-release.apk`.

## Enviar pelo Termux

Dentro da pasta do projeto:

```bash
git init -b main
git add .
git commit -m "Academia Flow 2.0 - pronto para uso"
git remote add origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
git push -u origin main
```

Se o `origin` já existir:

```bash
git remote set-url origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
git push -u origin main
```
