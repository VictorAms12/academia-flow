# Google + Classroom — configuração OAuth

A integração da v2.5 é opcional. Sem credenciais OAuth, o Academia Flow continua funcionando normalmente com SQLite local; a tela Google & Classroom apenas informa que o build ainda não foi configurado.

## 1. Criar/selecionar um projeto no Google Cloud

1. Abra o Google Cloud Console.
2. Crie ou selecione um projeto para o Academia Flow.
3. Ative a **Google Classroom API**.
4. Configure a tela de consentimento OAuth.
5. Durante desenvolvimento, adicione as contas que usarão o app como usuários de teste quando isso for exigido pelo modo de publicação do projeto.

A integração solicita somente identidade básica e leitura do Classroom:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/classroom.courses.readonly`
- `https://www.googleapis.com/auth/classroom.coursework.me.readonly`
- `https://www.googleapis.com/auth/classroom.student-submissions.me.readonly`

Ela não cria/edita turmas, não entrega atividades e não modifica notas.

## 2. Android

O package name do app é:

```text
com.example.academia_flow
```

No Google Cloud, registre o app Android com esse package name e com o SHA-1 do certificado que assina os APKs Release do Academia Flow.

Além do cliente Android, crie um **OAuth Client ID do tipo Web application**. O plugin `google_sign_in` usa esse Web Client ID como `serverClientId` quando o projeto não usa `google-services.json`.

No GitHub, crie o secret:

```text
GOOGLE_ANDROID_SERVER_CLIENT_ID
```

O workflow passa esse valor ao Flutter usando `--dart-define`.

Build local:

```bash
flutter build apk --release \
  --dart-define=GOOGLE_ANDROID_SERVER_CLIENT_ID="SEU_WEB_CLIENT_ID.apps.googleusercontent.com"
```

## 3. Windows

Crie um OAuth Client ID do tipo **Desktop app**.

No GitHub, crie:

```text
GOOGLE_DESKTOP_CLIENT_ID
GOOGLE_DESKTOP_CLIENT_SECRET
```

O `GOOGLE_DESKTOP_CLIENT_SECRET` pode ficar vazio se o cliente criado não fornecer/necessitar desse campo.

No Windows, o Academia Flow usa o fluxo OAuth 2.0 de aplicativo instalado:

1. abre o navegador padrão;
2. usa PKCE;
3. recebe o código em `127.0.0.1` numa porta temporária;
4. troca o código por tokens;
5. guarda o refresh token no armazenamento seguro da plataforma.

Build local (PowerShell):

```powershell
flutter build windows --release `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID="SEU_DESKTOP_CLIENT_ID" `
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="SEU_DESKTOP_CLIENT_SECRET"
```

## 4. Fluxo no aplicativo

Depois de instalar um build configurado:

```text
Configurações
  → Google & Classroom
  → Entrar com Google
  → Conectar Classroom
  → Atualizar turmas
  → Vincular turma a uma matéria existente
       ou criar matéria automaticamente
  → Sincronizar agora
```

A sincronização importa apenas itens do Classroom que tenham prazo definido, pois o modelo atual de atividades do Academia Flow exige uma data de vencimento.

Atividades já importadas são identificadas pelos IDs originais de curso/trabalho e não são duplicadas em sincronizações seguintes. Quando uma entrega é marcada como `TURNED_IN` ou `RETURNED` no Classroom, a atividade importada é marcada como concluída no Academia Flow.

## 5. Contas institucionais

Contas de instituições Google Workspace for Education podem bloquear aplicativos OAuth externos. Se o login funcionar, mas o Classroom responder com acesso negado, confira as políticas do administrador da instituição.

## Referências oficiais

- OAuth para aplicativos instalados: https://developers.google.com/identity/protocols/oauth2/native-app
- Google Sign-In Flutter: https://pub.dev/packages/google_sign_in
- Classroom `courses.list`: https://developers.google.com/workspace/classroom/reference/rest/v1/courses/list
- Classroom `courseWork.list`: https://developers.google.com/workspace/classroom/reference/rest/v1/courses.courseWork/list
- Classroom `studentSubmissions.list`: https://developers.google.com/workspace/classroom/reference/rest/v1/courses.courseWork.studentSubmissions/list
