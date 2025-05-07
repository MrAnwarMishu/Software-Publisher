@echo off
setlocal enabledelayedexpansion

:: === Check if OpenSSL is installed ===
where openssl >nul 2>nul
if errorlevel 1 (
    echo OpenSSL Not Installed.
    pause
    exit /b
)

:: === Check if WiX Toolset is installed ===
where candle >nul 2>nul
if errorlevel 1 (
    echo WiX Toolset Not Installed.
    pause
    exit /b
)

:: === Check if SignTool is installed ===
where signtool >nul 2>nul
if errorlevel 1 (
    echo SignTool Not Installed.
    pause
    exit /b
)

:: === User Inputs ===
echo === Auto MSI Builder ===
set /p EXE=Enter path to your .exe file (e.g. Brightness_Controller.exe): 
set /p APPNAME=Enter App Name (e.g. MyApp): 
set /p MANUFACTURER=Enter Manufacturer Name: 
set /p VERSION=Enter App Version (e.g. 1.0.0.0): 
set /p CN=Enter Common Name (CN) for Certificate: 
set /p O=Enter Organization (O): 
set /p OU=Enter Organizational Unit (OU): 
set /p C=Enter Country (C): 
set /p EMAIL=Enter Email (optional): 
set /p PFXPASS=Enter password for the .pfx file: 

:: === Check if .exe file exists ===
if not exist "%EXE%" (
    echo ERROR: .exe file not found!
    pause
    exit /b
)

:: === Create Self-Signed Certificate using OpenSSL ===
echo Generating Self-Signed Certificate and .pfx file...
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -keyout private.key -out certificate.crt -subj "/CN=%CN%/O=%O%/OU=%OU%/C=%C%/emailAddress=%EMAIL%"
openssl pkcs12 -export -out certificate.pfx -inkey private.key -in certificate.crt -password pass:%PFXPASS%

:: === Write installer.wxs ===
echo Generating installer.wxs...
(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi"^>
echo   ^<Product Id="*" Name="%APPNAME%" Language="1033" Version="%VERSION%" Manufacturer="%MANUFACTURER%" UpgradeCode="PUT-GUID-HERE"^>
echo     ^<Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" /^>
echo     ^<MediaTemplate /^>
echo     ^<Directory Id="TARGETDIR" Name="SourceDir"^>
echo       ^<Directory Id="ProgramFilesFolder"^>
echo         ^<Directory Id="INSTALLFOLDER" Name="%APPNAME%"^>
echo           ^<Component Id="MainExecutable" Guid="PUT-GUID-HERE"^>
echo             ^<File Source="%EXE%" KeyPath="yes" /^>
echo           ^</Component^>
echo         ^</Directory^>
echo       ^</Directory^>
echo     ^</Directory^>
echo     ^<Feature Id="ProductFeature" Title="%APPNAME%" Level="1"^>
echo       ^<ComponentRef Id="MainExecutable" /^>
echo     ^</Feature^>
echo   ^</Product^>
echo ^</Wix^>
) > installer.wxs

:: === Compile MSI ===
echo.
echo 🔨 Building MSI...
"C:\Program Files (x86)\WiX Toolset v3.11\bin\candle.exe" installer.wxs
"C:\Program Files (x86)\WiX Toolset v3.11\bin\light.exe" installer.wixobj -o "%APPNAME%.msi"

:: === Sign the files ===
echo.
echo 🔏 Signing %EXE% and %APPNAME%.msi...
set SIGNTOOL="C:\Program Files (x86)\Windows Kits\10\bin\x64\signtool.exe"
%SIGNTOOL% sign /f certificate.pfx /p %PFXPASS% /t http://timestamp.digicert.com "%EXE%"
%SIGNTOOL% sign /f certificate.pfx /p %PFXPASS% /t http://timestamp.digicert.com "%APPNAME%.msi"

:: === Cleanup ===
del private.key
del certificate.crt
del certificate.pfx

echo.
echo ✅ Done! Signed .exe and .msi are ready.
pause
