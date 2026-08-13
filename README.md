# Academia Flow — Flutter / GitHub Build

Aplicativo Flutter de organização universitária acadêmica com build automático de APK pelo GitHub Actions.

## Build automático

O repositório inclui:

- `.github/workflows/build-android.yml` — build Release automático em push para `main`/`master` e execução manual.
- `.github/workflows/build-debug-apk.yml` — build Debug manual para diagnóstico.

O workflow instala Java 17 e Flutter Stable, gera a plataforma Android caso ela ainda não exista, instala dependências, analisa/testa o projeto, compila o APK e publica o arquivo como Artifact.

## Como baixar o APK

Após enviar o projeto ao GitHub:

1. Abra o repositório.
2. Entre em **Actions**.
3. Abra **Build Android APK**.
4. Abra a execução mais recente.
5. Em **Artifacts**, baixe **academia-flow-apk**.
6. Extraia o arquivo baixado para obter `app-release.apk`.

## Enviar a um repositório novo

```bash
git init
git add .
git commit -m "Academia Flow - build GitHub"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
git push -u origin main
```

Se já existir `origin`:

```bash
git remote set-url origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
git push -u origin main
```

## Build local opcional

```bash
flutter create . --platforms=android
flutter pub get
flutter run
```

Build APK local:

```bash
flutter build apk --release
```
