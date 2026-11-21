@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

CD /D "%~dp0"
COLOR F0
TITLE nt4AliveRevClean2K - Windows 2000 Boot ISO Slimmer

ECHO.
ECHO  ==================== nt4AliveRevClean2K ========================================
ECHO.
ECHO  Creates a minimal (~300 KB) Windows 2000 boot ISO (nt4AliveRevClean2K.iso)
ECHO  containing only CDROM_NT.5, I386\NTLDR, I386\NTDETECT.COM, and BOOT.BIN.
ECHO  Your original Windows 2000 ISO will not be modified or deleted.
ECHO.
ECHO  ==============================================================================

:: Locate 7-Zip (TOOLS\, script directory, or Program Files)
IF NOT EXIST "TOOLS" MD "TOOLS"
SET "NEED_7Z="
IF NOT EXIST "TOOLS\7z.exe" SET "NEED_7Z=1"
IF NOT EXIST "TOOLS\7z.dll" SET "NEED_7Z=1"

IF DEFINED NEED_7Z (
    IF EXIST "%~dp07z.exe" IF EXIST "%~dp07z.dll" (
        COPY /Y "%~dp07z.exe" "TOOLS\" >NUL
        COPY /Y "%~dp07z.dll" "TOOLS\" >NUL
    ) ELSE IF EXIST "%ProgramFiles%\7-Zip\7z.exe" IF EXIST "%ProgramFiles%\7-Zip\7z.dll" (
        COPY /Y "%ProgramFiles%\7-Zip\7z.exe" "TOOLS\" >NUL
        COPY /Y "%ProgramFiles%\7-Zip\7z.dll" "TOOLS\" >NUL
    ) ELSE IF EXIST "%ProgramFiles(x86)%\7-Zip\7z.exe" IF EXIST "%ProgramFiles(x86)%\7-Zip\7z.dll" (
        COPY /Y "%ProgramFiles(x86)%\7-Zip\7z.exe" "TOOLS\" >NUL
        COPY /Y "%ProgramFiles(x86)%\7-Zip\7z.dll" "TOOLS\" >NUL
    )
)

SET "MISSING_7Z="
IF NOT EXIST "TOOLS\7z.exe" SET "MISSING_7Z=1"
IF NOT EXIST "TOOLS\7z.dll" SET "MISSING_7Z=1"

IF DEFINED MISSING_7Z (
    ECHO.
    ECHO [ERROR] 7-Zip was not found. Please install 7-Zip from www.7-zip.org
    ECHO         Or copy 7z.exe and 7z.dll to this folder or TOOLS\.
    PAUSE
    EXIT /B 1
)
SET "SEVENZIP=%~dp0TOOLS\7z.exe"

:: Locate oscdimg.exe or cdimage.exe (TOOLS\, script directory, local ADK, or offer download)
IF NOT EXIST "TOOLS\oscdimg.exe" (
    IF EXIST "%~dp0oscdimg.exe" (
        COPY /Y "%~dp0oscdimg.exe" "TOOLS\" >NUL
    ) ELSE (
        FOR %%D IN (
            "%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg"
            "%ProgramFiles%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg"
            "%ProgramFiles(x86)%\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg"
            "%ProgramFiles(x86)%\Windows Kits\8.0\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg"
            "%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
            "%ProgramFiles%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
        ) DO (
            IF NOT EXIST "TOOLS\oscdimg.exe" IF EXIST "%%~D\oscdimg.exe" (
                COPY /Y "%%~D\oscdimg.exe" "TOOLS\" >NUL
            )
        )
    )
)

IF NOT EXIST "TOOLS\CDIMAGE.EXE" IF NOT EXIST "TOOLS\oscdimg.exe" (
    ECHO.
    ECHO  oscdimg.exe was not found in TOOLS\ or the script folder.
    CHOICE /C YN /N /M "  Download oscdimg.exe (v2.56) from Microsoft now? [Y/N]: "
    IF !ERRORLEVEL! EQU 1 (
        ECHO  Downloading oscdimg.exe to "%~dp0"...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls; $wc = New-Object System.Net.WebClient; $wc.Headers.Add('User-Agent', 'Microsoft-Symbol-Server/10.0.0.0'); $wc.DownloadFile('https://microsoft.com', '%~dp0oscdimg.exe') } catch { exit 1 }"
        IF EXIST "%~dp0oscdimg.exe" COPY /Y "%~dp0oscdimg.exe" "TOOLS\" >NUL
    )
)

SET "ISOTOOL="
IF EXIST "TOOLS\CDIMAGE.EXE" SET "ISOTOOL=TOOLS\CDIMAGE.EXE"
IF NOT DEFINED ISOTOOL IF EXIST "TOOLS\oscdimg.exe" SET "ISOTOOL=TOOLS\oscdimg.exe"
IF NOT DEFINED ISOTOOL (
    ECHO.
    ECHO [ERROR] Neither TOOLS\CDIMAGE.EXE nor TOOLS\oscdimg.exe was found.
    PAUSE
    EXIT /B 1
)

:: Find source Windows 2000 ISO in current folder (ignoring NT4 output ISOs and nt4AliveRevClean2K.iso)
:SCAN_W2K
SET "W2K_ISO="
FOR %%I IN (*.iso) DO (
    IF /I NOT "%%~nxI"=="NT4SP6W.iso" IF /I NOT "%%~nxI"=="NT4SP6S.iso" IF /I NOT "%%~nxI"=="NT4SP6T.iso" IF /I NOT "%%~nxI"=="nt4AliveRevClean2K.iso" IF NOT DEFINED W2K_ISO (
        "%SEVENZIP%" l "%%~fI" | FINDSTR /I /C:"CDROM_NT.5" >NUL 2>&1
        IF !ERRORLEVEL! EQU 0 SET "W2K_ISO=%%~nxI"
    )
)

IF NOT DEFINED W2K_ISO (
    ECHO.
    ECHO  No Windows 2000 ISO was found in this folder.
    CHOICE /C RQ /N /M "  Would you like to retry or quit? [R/Q]: "
    IF !ERRORLEVEL! EQU 1 GOTO :SCAN_W2K
    EXIT /B 1
)

ECHO.
ECHO Found Windows 2000 ISO: "!W2K_ISO!"
ECHO Extracting minimal boot files...

IF EXIST "W2K_MIN_WORK" RD /Q /S "W2K_MIN_WORK"
MD "W2K_MIN_WORK\ISO\I386"

:: Extract CDROM_NT.5, NTLDR, and NTDETECT.COM
"%SEVENZIP%" x "!W2K_ISO!" -o"W2K_MIN_WORK\ISO" CDROM_NT.5 I386\NTLDR I386\NTDETECT.COM -y >NUL

IF NOT EXIST "W2K_MIN_WORK\ISO\I386\NTLDR" (
    ECHO [ERROR] Failed to extract I386\NTLDR from "!W2K_ISO!".
    RD /Q /S "W2K_MIN_WORK"
    PAUSE
    EXIT /B 1
)

:: Extract the 2048-byte El Torito boot sector
powershell -NoProfile -ExecutionPolicy Bypass -Command "$fs = [System.IO.File]::OpenRead((Resolve-Path '!W2K_ISO!').Path); $br = New-Object System.IO.BinaryReader($fs); $fs.Position = 17 * 2048; $bvd = $br.ReadBytes(2048); $catLba = [BitConverter]::ToUInt32($bvd, 0x47); $fs.Position = [int64]$catLba * 2048; $cat = $br.ReadBytes(2048); $loadLba = [BitConverter]::ToUInt32($cat, 0x28); $fs.Position = [int64]$loadLba * 2048; $bootBytes = $br.ReadBytes(2048); $fs.Close(); [System.IO.File]::WriteAllBytes((Join-Path (Resolve-Path 'W2K_MIN_WORK').Path 'W2KBOOT.BIN'), $bootBytes);"

IF NOT EXIST "W2K_MIN_WORK\W2KBOOT.BIN" (
    ECHO [ERROR] Failed to extract boot sector from "!W2K_ISO!".
    RD /Q /S "W2K_MIN_WORK"
    PAUSE
    EXIT /B 1
)

ECHO Building minimal bootable ISO: nt4AliveRevClean2K.iso...
IF EXIST "nt4AliveRevClean2K.iso" DEL /Q /F "nt4AliveRevClean2K.iso"
"%ISOTOOL%" -lNT4ALIVEREVCLEAN2K -h -j1 -m -o -e "-bW2K_MIN_WORK\W2KBOOT.BIN" "W2K_MIN_WORK\ISO" "nt4AliveRevClean2K.iso" >NUL

RD /Q /S "W2K_MIN_WORK"

IF NOT EXIST "nt4AliveRevClean2K.iso" (
    ECHO [ERROR] Failed to create nt4AliveRevClean2K.iso.
    PAUSE
    EXIT /B 1
)

ECHO.
ECHO  Success! Created nt4AliveRevClean2K.iso.
ECHO  Original ISO "!W2K_ISO!" was left untouched.
ECHO.
ECHO  Press any key to quit...
PAUSE >NUL
EXIT /B 0
