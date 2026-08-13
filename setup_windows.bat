@echo off
title Academia Flow - Preparar Projeto
echo.
echo === Academia Flow ===
echo Gerando arquivos nativos do Flutter...
flutter create . --platforms=android,web,windows
if errorlevel 1 goto erro
echo.
echo Baixando dependencias...
flutter pub get
if errorlevel 1 goto erro
echo.
echo Projeto preparado com sucesso.
echo Para executar: flutter run
pause
exit /b 0

:erro
echo.
echo Ocorreu um erro. Confirme se o Flutter esta instalado e se "flutter doctor" esta sem erros criticos.
pause
exit /b 1
