@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

CD /D "%~dp0"
COLOR F0
SET "HEADTITLE=nt4Drivers (nt4AliveRev Companion)"
TITLE %HEADTITLE%
NET SESSION >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO.
    ECHO [ERROR] Administrator privileges are required to update the NT 4.0 registry hive.
    ECHO         Please right-click "%~nx0" and select "Run as administrator".
    ECHO.
    PAUSE
    EXIT /B 1
)

ECHO.
ECHO  ================= nt4AliveRevDrivers - NT 4.0 Driver Integrator ==================
ECHO.
ECHO  Targets ISOs built by nt4AliveRev (NT4SP6W.iso, NT4SP6S.iso, NT4SP6T.iso)
ECHO  Integrates text-mode & PnP drivers from DRIVERS\ and outputs NT4SP6*+.iso
ECHO.
ECHO  ==============================================================================

:: 1. Verify required tools from nt4AliveRev's TOOLS\ folder
SET "SEVENZIP=%~dp0TOOLS\7z.exe"
SET "OSCDIMG=%~dp0TOOLS\oscdimg.exe"
SET "CDIMAGE=%~dp0TOOLS\cdimage.exe"
SET "BOOTBIN=%~dp0TOOLS\BOOT.BIN"

IF NOT EXIST "%SEVENZIP%" (
    ECHO.
    ECHO [ERROR] TOOLS\7z.exe not found. Please run nt4AliveRev first.
    PAUSE
    EXIT /B 1
)
IF NOT EXIST "%BOOTBIN%" (
    ECHO.
    ECHO [ERROR] TOOLS\BOOT.BIN not found. Please run nt4AliveRev first.
    PAUSE
    EXIT /B 1
)
SET "ISOTOOL="
IF EXIST "%OSCDIMG%" SET "ISOTOOL=%OSCDIMG%"
IF NOT DEFINED ISOTOOL IF EXIST "%CDIMAGE%" SET "ISOTOOL=%CDIMAGE%"
IF NOT DEFINED ISOTOOL (
    ECHO.
    ECHO [ERROR] Neither TOOLS\oscdimg.exe nor TOOLS\cdimage.exe was found.
    PAUSE
    EXIT /B 1
)

:: 2. Create DRIVERS\ folder structure if missing
FOR %%D IN ("DRIVERS" "DRIVERS\AHCINT" "DRIVERS\NVMENT" "DRIVERS\IDENT" "DRIVERS\MMCSDNT" "DRIVERS\USBNT" "DRIVERS\CUSTOM") DO (
    IF NOT EXIST %%D MD %%D
)

:: 3. Check if any ages2001 drivers are missing; only prompt to download if needed
SET "MISSING_AGES="
IF NOT EXIST "DRIVERS\AHCINT\ahcint.sys" SET "MISSING_AGES=1"
IF NOT EXIST "DRIVERS\NVMENT\nvment.sys" SET "MISSING_AGES=1"
IF NOT EXIST "DRIVERS\IDENT\ident.sys" SET "MISSING_AGES=1"
IF NOT EXIST "DRIVERS\MMCSDNT\mmcsdnt.sys" SET "MISSING_AGES=1"
IF NOT EXIST "DRIVERS\USBNT\usbnt.sys" SET "MISSING_AGES=1"
IF NOT EXIST "DRIVERS\USBNT\usbinst.exe" SET "MISSING_AGES=1"

IF DEFINED MISSING_AGES (
    ECHO.
    CHOICE /C YN /N /M " One or more 'ages2001' drivers are missing. Download suite from GitHub? [Y/N]: "
    IF !ERRORLEVEL! EQU 1 CALL :DOWNLOAD_AGES2001
)

:: Check if any driver files are present to integrate
SET "HAS_DRIVERS="
IF EXIST "DRIVERS\AHCINT\ahcint.sys" SET "HAS_DRIVERS=1"
IF EXIST "DRIVERS\NVMENT\nvment.sys" SET "HAS_DRIVERS=1"
IF EXIST "DRIVERS\IDENT\ident.sys" SET "HAS_DRIVERS=1"
IF EXIST "DRIVERS\MMCSDNT\mmcsdnt.sys" SET "HAS_DRIVERS=1"
IF EXIST "DRIVERS\USBNT\usbnt.sys" IF EXIST "DRIVERS\USBNT\usbinst.exe" SET "HAS_DRIVERS=1"
FOR /F "DELIMS=" %%F IN ('DIR /B /A-D "DRIVERS\CUSTOM" 2^>NUL') DO SET "HAS_DRIVERS=1"

IF NOT DEFINED HAS_DRIVERS (
    ECHO.
    ECHO [NOTICE] No drivers were found in DRIVERS\ to integrate.
    ECHO          Place drivers in DRIVERS\ subfolders or re-run and download the suite.
    ECHO.
    PAUSE
    EXIT /B 0
)

:: Load CDIMAGE_SWITCHES from TOOLS\SETTINGS.INI if available
SET "CDIMAGE_SWITCHES=-h -j1 -m -o -e"
IF EXIST "TOOLS\SETTINGS.INI" (
    FOR /F "USEBACKQ EOL=; TOKENS=1,* DELIMS==" %%A IN ("TOOLS\SETTINGS.INI") DO (
        IF /I "%%A"=="CDIMAGE_SWITCHES" SET "CDIMAGE_SWITCHES=%%B"
    )
)

:: 4. Scan strictly for ISOs produced by nt4AliveRev
SET "FOUND_ISO=0"
FOR %%I IN (NT4SP6W.iso NT4SP6S.iso NT4SP6T.iso) DO (
    IF EXIST "%%I" (
        SET "FOUND_ISO=1"
        CALL :PROCESS_ISO "%%I"
    )
)

IF "%FOUND_ISO%"=="0" (
    ECHO.
    ECHO [NOTICE] No nt4AliveRev ISOs ^(NT4SP6W.iso, NT4SP6S.iso, or NT4SP6T.iso^) found.
    ECHO          Run nt4AliveRev first to build your base SP6a ISO.
    ECHO.
    PAUSE
    EXIT /B 0
)

ECHO.
ECHO ==============================================================================
ECHO  All matching ISOs have been updated with '+' suffix!
ECHO.
ECHO  [IMPORTANT POST-INSTALL NOTE]
ECHO  After arriving at the Windows NT 4.0 desktop for the first time, REBOOT
ECHO  ONCE before installing VMware Tools, VirtualBox Guest Additions, or any
ECHO  other drivers/hardware services so USBNT finishes initializing cleanly.
ECHO ==============================================================================
ECHO.
PAUSE
EXIT /B 0



REM ////////////////////////////////////////////////////////////////////////////
REM ************************ DOWNLOAD AGES2001 DRIVER SUITE ********************
REM ////////////////////////////////////////////////////////////////////////////
:DOWNLOAD_AGES2001
ECHO.
ECHO  Downloading ages2001 NT 4.0 driver suite from GitHub...

SET "SUB=raw"
SET "DOM=githubusercontent.com"
SET "USR=ages2001"
SET "PS_TLS=[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls;"

FOR %%P IN (
    "AHCINT:ahcint.sys:ahcicfg.exe"
    "NVMENT:nvment.sys:nvmecfg.exe"
    "IDENT:ident.sys:identcfg.exe"
    "MMCSDNT:mmcsdnt.sys:mmccfg.exe"
) DO (
    FOR /F "TOKENS=1,2,3 DELIMS=:" %%R IN (%%P) DO (
        ECHO   - Fetching %USR%/%%R ^(%%S + %%T^)...
        IF EXIST "DRIVERS\%%R" RD /Q /S "DRIVERS\%%R"
        MD "DRIVERS\%%R"
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { %PS_TLS% $wc = New-Object System.Net.WebClient; $wc.Headers.Add('User-Agent', 'nt4Drivers'); $wc.DownloadFile('https://%SUB%.%DOM%/%USR%/%%R/main/bin/NT/%%S', '%~dp0DRIVERS\%%R\%%S'); $wc.DownloadFile('https://%SUB%.%DOM%/%USR%/%%R/main/bin/NT/%%T', '%~dp0DRIVERS\%%R\%%T') } catch { exit 1 }"
        IF EXIST "DRIVERS\%%R\%%S" (
            ECHO     [OK] Saved %%S to DRIVERS\%%R\
        ) ELSE (
            ECHO     [WARNING] Failed to download %%S from %USR%/%%R.
        )
    )
)

ECHO   - Fetching %USR%/USBNT ^(latest release^)...
IF EXIST "DRIVERS\USBNT" RD /Q /S "DRIVERS\USBNT"
MD "DRIVERS\USBNT"
SET "API_SUB=api"
SET "GH_DOM=github.com"
SET "DL_TEMP=%~dp0DRV_DL_TEMP"
IF EXIST "%DL_TEMP%" RD /Q /S "%DL_TEMP%"
MD "%DL_TEMP%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { %PS_TLS% $wc = New-Object System.Net.WebClient; $wc.Headers.Add('User-Agent', 'nt4Drivers'); $json = $wc.DownloadString('https://%API_SUB%.%GH_DOM%/repos/%USR%/USBNT/releases/latest') | ConvertFrom-Json; $url = ($json.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1).browser_download_url; if ($url) { $wc.DownloadFile($url, '%DL_TEMP%\USBNT.zip') } } catch { exit 1 }"

IF NOT EXIST "%DL_TEMP%\USBNT.zip" GOTO :USBNT_DONE
"%SEVENZIP%" x "%DL_TEMP%\USBNT.zip" -o"%DL_TEMP%\USBNT_ext" -y >NUL 2>&1
FOR %%F IN (usbnt.sys usbinst.exe usbmon.exe usbtree.exe usbeject.exe usbcam.exe usbntcap.dll wheeltst.exe) DO (
    FOR /R "%DL_TEMP%\USBNT_ext" %%X IN (%%F) DO (
        IF EXIST "%%~fX" (
            ECHO "%%~dpX" | FINDSTR /I "\\2kxp\\ \\amd64\\ \\OEMDISK\\" >NUL 2>&1
            IF !ERRORLEVEL! NEQ 0 COPY /Y "%%~fX" "DRIVERS\USBNT\" >NUL
        )
    )
)

:USBNT_DONE
RD /Q /S "%DL_TEMP%"
IF EXIST "DRIVERS\USBNT\usbnt.sys" (
    ECHO     [OK] Saved USBNT NT 4.0 stack and tools to DRIVERS\USBNT\
) ELSE (
    ECHO     [WARNING] Failed to download USBNT release from %USR%/USBNT.
)
EXIT /B 0

REM ////////////////////////////////////////////////////////////////////////////
REM ************************ PROCESS SINGLE nt4AliveRev ISO ************************
REM ////////////////////////////////////////////////////////////////////////////
:PROCESS_ISO
SET "SRC_ISO=%~1"
SET "BASE_NAME=%~n1"
SET "OUT_ISO=%BASE_NAME%+.iso"
SET "OUT_LABEL=%BASE_NAME%+"
SET "STAGE_DIR=%~dp0DRV_WORK"

ECHO.
ECHO ------------------------------------------------------------------------------
ECHO  Source ISO : %SRC_ISO%
ECHO  Target ISO : %OUT_ISO%
ECHO ------------------------------------------------------------------------------

IF EXIST "%STAGE_DIR%" RD /Q /S "%STAGE_DIR%"
MD "%STAGE_DIR%"

ECHO  [1/4] Extracting %SRC_ISO%...
"%SEVENZIP%" x "%SRC_ISO%" -o"%STAGE_DIR%" -y >NUL
IF %ERRORLEVEL% GTR 1 (
    ECHO  [ERROR] Failed to extract %SRC_ISO%. Skipping...
    RD /Q /S "%STAGE_DIR%"
    EXIT /B 1
)
ATTRIB -R "%STAGE_DIR%\*.*" /S /D >NUL 2>&1

IF NOT EXIST "%STAGE_DIR%\I386\TXTSETUP.SIF" (
    ECHO  [ERROR] I386\TXTSETUP.SIF not found inside %SRC_ISO%. Skipping...
    RD /Q /S "%STAGE_DIR%"
    EXIT /B 1
)

ECHO  [2/4] Integrating drivers...

:: --- AHCINT (SATA AHCI) ---
IF EXIST "DRIVERS\AHCINT\ahcint.sys" (
    CALL :SLIP_MINIPORT "DRIVERS\AHCINT" "ahcint" "ahcint.sys" "ahcicfg.exe" "PCI\CC_010601" "AHCINT SATA AHCI Storage Controller"
)

:: --- NVMENT (NVMe SSD) ---
IF EXIST "DRIVERS\NVMENT\nvment.sys" (
    CALL :SLIP_MINIPORT "DRIVERS\NVMENT" "nvment" "nvment.sys" "nvmecfg.exe" "PCI\CC_010802" "NVMENT NVMe Storage Controller"
)

:: --- IDENT (PATA / IDE) ---
IF EXIST "DRIVERS\IDENT\ident.sys" (
    CALL :SLIP_MINIPORT "DRIVERS\IDENT" "ident" "ident.sys" "identcfg.exe" "PCI\CC_0101" "IDENT PCI IDE Storage Controller"
)

:: --- MMCSDNT (SD / SDHC / SDXC Host Controller) ---
IF EXIST "DRIVERS\MMCSDNT\mmcsdnt.sys" (
    CALL :SLIP_MINIPORT "DRIVERS\MMCSDNT" "mmcsdnt" "mmcsdnt.sys" "mmccfg.exe" "PCI\CC_080501" "MMCSDNT SD Host Controller"
)

:: --- USBNT (USB 1.1 / 2.0 / 3.x / 4 & Thunderbolt Stack) ---
IF NOT EXIST "DRIVERS\USBNT\usbnt.sys" GOTO :SKIP_USBNT
IF NOT EXIST "DRIVERS\USBNT\usbinst.exe" GOTO :SKIP_USBNT
ECHO        + Integrating USBNT USB/Thunderbolt Stack...
XCOPY /Y /Q "DRIVERS\USBNT\*.*" "%STAGE_DIR%\I386\" >NUL

:: Generate usbnt_up.inf using native NT 4.0 AddReg -> RunOnce   <-- PUT IT RIGHT HERE
(
    ECHO [Version]
    ECHO Signature="$Windows NT$"
    ECHO [DefaultInstall.Custom]
    ECHO AddReg=USBNT.RunOnce
    ECHO [USBNT.RunOnce]
    ECHO HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce","InstallUSBNT",0,"%%11%%\usbinst.exe /install /keepi8042"
) > "%STAGE_DIR%\I386\usbnt_up.inf"


:: Register all USBNT files + usbnt_up.inf into System32 (DIRID=2) & INF (DIRID=20)
ECHO.>> "%STAGE_DIR%\I386\TXTSETUP.SIF"
ECHO [SourceDisksFiles]>> "%STAGE_DIR%\I386\TXTSETUP.SIF"
ECHO.>> "%STAGE_DIR%\I386\DOSNET.INF"
ECHO [Files]>> "%STAGE_DIR%\I386\DOSNET.INF"

FOR %%F IN ("DRIVERS\USBNT\*.*") DO (
    ECHO %%~nxF = 1,,,,,,,2,0,0 >> "%STAGE_DIR%\I386\TXTSETUP.SIF"
    ECHO d1,%%~nxF>> "%STAGE_DIR%\I386\DOSNET.INF"
)
ECHO usbnt_up.inf = 1,,,,,,,20,0,0 >> "%STAGE_DIR%\I386\TXTSETUP.SIF"
ECHO d1,usbnt_up.inf>> "%STAGE_DIR%\I386\DOSNET.INF"

:: Append usbnt_up.inf to SYSSETUP.INF [Infs.Always]
IF EXIST "%STAGE_DIR%\I386\SYSSETUP.INF" (
    FINDSTR /I "usbnt_up.inf" "%STAGE_DIR%\I386\SYSSETUP.INF" >NUL 2>&1
    IF !ERRORLEVEL! NEQ 0 (
        (
            ECHO.
            ECHO [Infs.Always]
            ECHO usbnt_up.inf,DefaultInstall.Custom
        ) >> "%STAGE_DIR%\I386\SYSSETUP.INF"
    )
) ELSE (
    ECHO        [WARNING] SYSSETUP.INF not found; USBNT will not auto-install!
)

:SKIP_USBNT


:: --- Custom Driver Files from DRIVERS\CUSTOM\ ---
FOR /F "DELIMS=" %%F IN ('DIR /B /A-D "DRIVERS\CUSTOM" 2^>NUL') DO (
    ECHO        + Integrating custom file: %%F...
    SET "C_NAME=%%~nF"
    SET "C_EXT=%%~xF"
    SET "DIRID=2"
    IF /I "!C_EXT!"==".SYS" SET "DIRID=4"
    IF /I "!C_EXT!"==".INF" SET "DIRID=20"
    IF /I "!C_EXT!"==".HLP" SET "DIRID=21"
    IF /I "!C_EXT!"==".CHM" SET "DIRID=21"

    IF DEFINED C_EXT IF EXIST "%STAGE_DIR%\I386\!C_NAME!!C_EXT:~0,3!_" (
        DEL /Q /F "%STAGE_DIR%\I386\!C_NAME!!C_EXT:~0,3!_" >NUL 2>&1
    )
    COPY /Y "DRIVERS\CUSTOM\%%F" "%STAGE_DIR%\I386\" >NUL
    (
        ECHO.
        ECHO [SourceDisksFiles]
        ECHO %%F = 1,,,,,,,!DIRID!,0,0
    ) >> "%STAGE_DIR%\I386\TXTSETUP.SIF"
    (
        ECHO.
        ECHO [Files]
        ECHO d1,%%F
    ) >> "%STAGE_DIR%\I386\DOSNET.INF"
)

ECHO  [3/4] Building bootable %OUT_ISO%...
IF EXIST "%OUT_ISO%" DEL /Q /F "%OUT_ISO%"
"%ISOTOOL%" "-l%OUT_LABEL%" %CDIMAGE_SWITCHES% "-b%BOOTBIN%" "%STAGE_DIR%" "%OUT_ISO%" >NUL

ECHO  [4/4] Cleaning up staging folder...
RD /Q /S "%STAGE_DIR%"

IF EXIST "%OUT_ISO%" (
    ECHO  [DONE] Created %OUT_ISO% successfully!
) ELSE (
    ECHO  [ERROR] Failed to create %OUT_ISO%.
)
EXIT /B 0


REM ////////////////////////////////////////////////////////////////////////////
REM ************************ HELPER: SLIPSTREAM SCSI MINIPORT ******************
REM ////////////////////////////////////////////////////////////////////////////
:SLIP_MINIPORT
SET "DRV_DIR=%~1"
SET "SVC_NAME=%~2"
SET "SYS_FILE=%~3"
SET "CFG_EXE=%~4"
SET "HW_ID=%~5"
SET "DESC=%~6"
SET "SYS_BASE=%~n3"

ECHO        + Integrating %DESC% ^(%SYS_FILE%^)...
COPY /Y "%DRV_DIR%\%SYS_FILE%" "%STAGE_DIR%\I386\" >NUL
IF EXIST "%STAGE_DIR%\I386\%SYS_BASE%.sy_" DEL /Q /F "%STAGE_DIR%\I386\%SYS_BASE%.sy_" >NUL 2>&1

(
    ECHO.
    ECHO [SourceDisksFiles]
    ECHO %SYS_FILE% = 1,,,,,,3_,4,1
    ECHO.
    ECHO [HardwareIdsDatabase]
    ECHO %HW_ID% = "%SVC_NAME%"
    ECHO.
    ECHO [SCSI.Load]
    ECHO %SVC_NAME% = %SYS_FILE%,4
    ECHO.
    ECHO [SCSI]
    ECHO %SVC_NAME% = "%DESC%"
) >> "%STAGE_DIR%\I386\TXTSETUP.SIF"

(
    ECHO.
    ECHO [Files]
    ECHO d1,%SYS_FILE%
) >> "%STAGE_DIR%\I386\DOSNET.INF"

IF EXIST "%DRV_DIR%\%CFG_EXE%" (
    ECHO        + Adding %CFG_EXE% utility...
    COPY /Y "%DRV_DIR%\%CFG_EXE%" "%STAGE_DIR%\I386\" >NUL
    (
        ECHO.
        ECHO [SourceDisksFiles]
        ECHO %CFG_EXE% = 1,,,,,,,2,0,0
    ) >> "%STAGE_DIR%\I386\TXTSETUP.SIF"
    (
        ECHO.
        ECHO [Files]
        ECHO d1,%CFG_EXE%
    ) >> "%STAGE_DIR%\I386\DOSNET.INF"
)
EXIT /B 0

