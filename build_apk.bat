@echo off
title Academia Flow - Build APK
echo.
echo === Gerando APK Release ===
flutter pub get
if errorlevel 1 goto erro
flutter build apk --release
if errorlevel 1 goto erro
echo.
echo APK gerado em:
echo build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0

:erro
echo.
echo Build falhou. Execute "flutter doctor -v" e revise a mensagem acima.
pause
exit /b 1
