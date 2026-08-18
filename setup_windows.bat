@echo off
title Academia Flow - Preparar Projeto
echo.
echo === Academia Flow ===
echo Preparando somente as plataformas suportadas: Android e Windows.
flutter config --enable-windows-desktop
if errorlevel 1 goto erro
flutter create . --platforms=android,windows
if errorlevel 1 goto erro
echo.
echo Baixando dependencias...
flutter pub get
if errorlevel 1 goto erro
echo.
echo Projeto preparado com sucesso.
echo Para executar no Windows: flutter run -d windows
echo Para APK Release assinado, use o workflow Build Android APK no GitHub Actions.
pause
exit /b 0

:erro
echo.
echo Ocorreu um erro. Confirme se o Flutter esta instalado e execute "flutter doctor -v".
pause
exit /b 1
