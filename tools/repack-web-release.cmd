@echo off
setlocal

set ROOT=%~dp0..
cd /d "%ROOT%"

if not exist "build\web" (
  echo [ERROR] build\web not found. Run flutter build web first.
  exit /b 1
)

set MAT_SRC=C:\flutter_windows_3.41.4-stable\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf
set MAT_DST=build\web\assets\fonts\MaterialIcons-Regular.otf

if exist "%MAT_SRC%" (
  copy /y "%MAT_SRC%" "%MAT_DST%" >nul
  echo [OK] Patched MaterialIcons font.
) else (
  echo [WARN] MaterialIcons source font not found, skip patch.
)

if not exist "dist" mkdir dist
if exist "dist\pickplan30ios-web.zip" del /f /q "dist\pickplan30ios-web.zip"
if exist "dist\_zip_verify" rmdir /s /q "dist\_zip_verify"

tar -a -cf "dist\pickplan30ios-web.zip" -C "build\web" .
if errorlevel 1 (
  echo [ERROR] zip packaging failed.
  exit /b 1
)

mkdir "dist\_zip_verify"
tar -xf "dist\pickplan30ios-web.zip" -C "dist\_zip_verify"
if errorlevel 1 (
  echo [ERROR] zip verify failed.
  exit /b 1
)

echo [OK] Generated: dist\pickplan30ios-web.zip
endlocal
