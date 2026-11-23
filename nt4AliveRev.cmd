@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: Lock working directory to the folder containing this script (fixes Run as Admin in System32)
CD /D "%~dp0"
SET "BASEDIR=%~dp0"

COLOR F0
SET "HEADTITLE=nt4AliveRev(nt4Alive Revised)"

IF /I "%RUNMODE%"=="D" (
    SET "HEADTITLE=%HEADTITLE% (debug mode)"
    GOTO :MAIN
)

:: Auto-generate default TOOLS\SETTINGS.INI if missing
IF NOT EXIST "TOOLS" MD "TOOLS"
IF NOT EXIST "TOOLS\SETTINGS.INI" (
    (
        ECHO ; nt4AliveRev Settings
        ECHO CREATE_ISO=YES
        ECHO CDIMAGE_SWITCHES=-h -j1 -m -o -e
    ) > "TOOLS\SETTINGS.INI"
)

IF EXIST "TOOLS\SETTINGS.INI" (
    FOR /F "USEBACKQ EOL=; TOKENS=1,* DELIMS==" %%A IN ("TOOLS\SETTINGS.INI") DO (
        IF NOT "%%A"=="" SET "%%A=%%B"
    )
)

IF /I "%RUNMODE%"=="SKIPINTRO" GOTO :MAIN
IF /I "%RUNMODE%"=="FULLAUTO" GOTO :MAIN

TITLE %HEADTITLE% - Introduction
ECHO.
ECHO  ==================== nt4AliveRev -- Windows NT 4.0 =============================
ECHO.
ECHO  Modernized for Windows 7 / 8 / 10 / 11 (x86 ^& x64)
ECHO.
ECHO  Slipstreams SP6a, Q299444 rollup, Q*i.exe / WindowsNT4*.exe hotfixes,
ECHO  and Windows Installer 2.0 into Windows NT 4.0 Workstation and Server.
ECHO.
ECHO  Original (C) 2008 Tomcat76 / FDV / TommyP (GPLv2)
ECHO.
ECHO  ==============================================================================
ECHO  Press Enter to continue (or type D + Enter for debug log)...
SET /P "RUNMODE="
IF /I "%RUNMODE%"=="D" (
    CLS
    ECHO.
    ECHO  Running in debug mode. Output is being logged to DEBUG.TXT...
    CALL "%~f0" > "DEBUG.TXT" 2>&1
    ECHO.
    ECHO  Done slipstreaming. Find DEBUG.TXT in this folder.
    ECHO  Press any key to quit...
    PAUSE >NUL
    EXIT /B
)
CLS

:MAIN
REM *********************************************************************************
REM ************************ PRE-FLIGHT & ENVIRONMENT CHECK *************************
REM *********************************************************************************
TITLE %HEADTITLE% - Preparing folders and checking environment
ECHO.
ECHO Preparing folders and checking environment...

:: Verify Administrator privileges (required on Windows 7/8/10/11 for REG LOAD/UNLOAD)
NET SESSION >NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO.
    ECHO [ERROR] Administrator privileges are required to mount NT 4.0 registry hives.
    ECHO         Please right-click "%~nx0" and select "Run as administrator".
    ECHO.
    PAUSE
    EXIT /B 1
)

:: Locate 7-Zip: check TOOLS\, then script directory (%~dp0), then Program Files
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
    ECHO [ERROR] Please Install 7-Zip from www.7-zip.org before continuing
    ECHO         Or copy 7z.exe and 7z.dll to this folder and run again
    ECHO.
    PAUSE
    EXIT /B 1
)
SET "SEVENZIP=%~dp0TOOLS\7z.exe"

FOR %%I IN (PACKAGES PACKAGES_TS DUMP TOOLS) DO IF NOT EXIST "%%I" MD "%%I"
FOR %%I IN (TEMP WORK SOURCE_NEW) DO IF EXIST "%%I" RD /Q /S "%%I"

:: Locate oscdimg.exe: check TOOLS\, script directory (%~dp0), local ADK, or offer download
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

IF /I "%CREATE_ISO%"=="YES" IF NOT EXIST "TOOLS\CDIMAGE.EXE" IF NOT EXIST "TOOLS\oscdimg.exe" (
    ECHO.
    ECHO  oscdimg.exe was not found in TOOLS\ or the script folder.
    CHOICE /C YN /N /M "  Download oscdimg.exe (v2.56) from Microsoft now? [Y/N]: "
    IF !ERRORLEVEL! EQU 1 (
        ECHO  Downloading oscdimg.exe to "%~dp0"...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls; $wc = New-Object System.Net.WebClient; $wc.Headers.Add('User-Agent', 'Microsoft-Symbol-Server/10.0.0.0'); $wc.DownloadFile('https://msdl.microsoft.com/download/symbols/oscdimg.exe/688CABB065000/oscdimg.exe', '%~dp0oscdimg.exe') } catch { exit 1 }"
        IF EXIST "%~dp0oscdimg.exe" (
            COPY /Y "%~dp0oscdimg.exe" "TOOLS\" >NUL
            ECHO  oscdimg.exe downloaded and copied to TOOLS\.
        ) ELSE (
            ECHO  [WARNING] Download failed. ISO creation will be skipped unless oscdimg.exe is added manually.
        )
    )
)
:: Interactive Windows 2000 Boot Loader Integration
SET "DO_W2K=N"
IF /I "%USE_W2K_BOOT%"=="YES" (
    SET "DO_W2K=Y"
) ELSE IF /I NOT "%USE_W2K_BOOT%"=="NO" (
    ECHO.
    CHOICE /C YN /N /M "  Integrate Windows 2000 BOOT.BIN, NTLDR, and NTDETECT.COM? [Y/N]: "
    IF !ERRORLEVEL! EQU 1 SET "DO_W2K=Y"
)

IF /I NOT "!DO_W2K!"=="Y" GOTO :SKIP_W2K

:SCAN_W2K
SET "W2K_ISO="
FOR %%I IN (*.iso) DO (
    IF /I NOT "%%~nxI"=="NT4SP6W.iso" IF /I NOT "%%~nxI"=="NT4SP6S.iso" IF /I NOT "%%~nxI"=="NT4SP6T.iso" IF NOT DEFINED W2K_ISO (
        "%SEVENZIP%" l "%%~fI" | FINDSTR /I /C:"CDROM_NT.5" >NUL 2>&1
        IF !ERRORLEVEL! EQU 0 SET "W2K_ISO=%%~nxI"
    )
)
IF NOT DEFINED W2K_ISO (
    ECHO.
    ECHO  No Windows 2000 iso was found in this folder.
    CHOICE /C RS /N /M "  Would you like to Retry or Skip this process? [R/S]: "
    IF !ERRORLEVEL! EQU 1 GOTO :SCAN_W2K
    SET "DO_W2K=N"
)

:SKIP_W2K


IF /I "!DO_W2K!"=="Y" (
    ECHO  Windows 2000 ISO detected: "!W2K_ISO!"
    ECHO  Integrating Windows 2000 boot sector and loaders...
    IF EXIST "W2K_TEMP" RD /Q /S "W2K_TEMP"
    MD "W2K_TEMP"
    "%SEVENZIP%" x "!W2K_ISO!" -o"W2K_TEMP" I386\NTLDR I386\NTDETECT.COM -y >NUL
    IF NOT EXIST "DUMP\I386" MD "DUMP\I386"
    IF EXIST "W2K_TEMP\I386\NTLDR" COPY /Y "W2K_TEMP\I386\NTLDR" "DUMP\I386\" >NUL
    IF EXIST "W2K_TEMP\I386\NTDETECT.COM" COPY /Y "W2K_TEMP\I386\NTDETECT.COM" "DUMP\I386\" >NUL
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$fs = [System.IO.File]::OpenRead((Resolve-Path '!W2K_ISO!').Path); $br = New-Object System.IO.BinaryReader($fs); $fs.Position = 17 * 2048; $bvd = $br.ReadBytes(2048); $catLba = [BitConverter]::ToUInt32($bvd, 0x47); $fs.Position = [int64]$catLba * 2048; $cat = $br.ReadBytes(2048); $loadLba = [BitConverter]::ToUInt32($cat, 0x28); $fs.Position = [int64]$loadLba * 2048; $bootBytes = $br.ReadBytes(2048); $fs.Close(); [System.IO.File]::WriteAllBytes((Join-Path (Resolve-Path 'TOOLS').Path 'BOOT.BIN'), $bootBytes);"
    RD /Q /S "W2K_TEMP"
) ELSE (
    IF EXIST "TOOLS\BOOT.BIN" DEL /Q /F "TOOLS\BOOT.BIN" >NUL
    IF EXIST "DUMP\I386\NTLDR" DEL /Q /F "DUMP\I386\NTLDR" >NUL
    IF EXIST "DUMP\I386\NTDETECT.COM" DEL /Q /F "DUMP\I386\NTDETECT.COM" >NUL
)


:: Auto-detect Windows NT 4.0 ISO (needed if SOURCE\I386 or TOOLS\BOOT.BIN is missing)
SET "SRC_ISO="
SET "NEED_NT4_ISO="
IF NOT EXIST "SOURCE\I386" SET "NEED_NT4_ISO=1"
IF NOT EXIST "TOOLS\BOOT.BIN" SET "NEED_NT4_ISO=1"

IF DEFINED NEED_NT4_ISO (
    FOR %%I IN (*.iso) DO (
        IF /I NOT "%%~nxI"=="NT4SP6W.iso" IF /I NOT "%%~nxI"=="NT4SP6S.iso" IF /I NOT "%%~nxI"=="NT4SP6T.iso" IF NOT DEFINED SRC_ISO (
            "%SEVENZIP%" l "%%~fI" | FINDSTR /I /C:"CDROM_W.40" /C:"CDROM_S.40" /C:"CDROM_TS.40" >NUL 2>&1
            IF !ERRORLEVEL! EQU 0 SET "SRC_ISO=%%~nxI"
        )
    )
)

:: Extract NT 4.0 ISO to SOURCE\ if SOURCE\I386 does not already exist
IF NOT EXIST "SOURCE\I386" (
    IF NOT DEFINED SRC_ISO (
        IF NOT EXIST "SOURCE" MD "SOURCE"
        ECHO.
        ECHO [ERROR] SOURCE\I386 is empty and no Windows NT 4.0 ISO was found in this folder.
        ECHO         Place a Windows NT 4.0 .iso next to %~nx0 or copy files into SOURCE\.
        PAUSE
        EXIT /B 1
    )
    ECHO.
    ECHO Found Windows NT 4.0 ISO "!SRC_ISO!" - extracting to SOURCE\...
    IF EXIST "SOURCE" RD /Q /S "SOURCE"
    MD "SOURCE"
    "%SEVENZIP%" x "!SRC_ISO!" -o"SOURCE" -y >NUL
    IF !ERRORLEVEL! GTR 1 (
        ECHO [ERROR] Failed to extract "!SRC_ISO!" to SOURCE\.
        PAUSE
        EXIT /B 1
    )
    ATTRIB -R "SOURCE\*.*" /S /D >NUL 2>&1
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$bootDir = Get-ChildItem -Path 'SOURCE' -Directory -Force | Where-Object { $_.Name -like '*BOOT*' } | Select-Object -First 1; if ($bootDir) { if (-not (Test-Path 'TOOLS\BOOT.BIN')) { $img = Get-ChildItem -Path $bootDir.FullName -File -Force | Select-Object -First 1; if ($img) { Copy-Item -LiteralPath $img.FullName -Destination 'TOOLS\BOOT.BIN' -Force } }; Remove-Item -LiteralPath $bootDir.FullName -Recurse -Force }"
)

:: Extract TOOLS\BOOT.BIN directly from the NT 4.0 ISO if still missing (e.g., after answering N to W2K boot)
IF NOT EXIST "TOOLS\BOOT.BIN" (
    IF DEFINED SRC_ISO (
        ECHO Extracting NT 4.0 boot sector from "!SRC_ISO!"...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$fs = [System.IO.File]::OpenRead((Resolve-Path '!SRC_ISO!').Path); $br = New-Object System.IO.BinaryReader($fs); $fs.Position = 17 * 2048; $bvd = $br.ReadBytes(2048); $catLba = [BitConverter]::ToUInt32($bvd, 0x47); $fs.Position = [int64]$catLba * 2048; $cat = $br.ReadBytes(2048); $loadLba = [BitConverter]::ToUInt32($cat, 0x28); $fs.Position = [int64]$loadLba * 2048; $bootBytes = $br.ReadBytes(2048); $fs.Close(); [System.IO.File]::WriteAllBytes((Join-Path (Resolve-Path 'TOOLS').Path 'BOOT.BIN'), $bootBytes);"
    ) ELSE (
        ECHO   [WARNING] TOOLS\BOOT.BIN is missing and no NT 4.0 ISO was found to extract it from.
    )
)


REM *** SET LANGUAGE, DISTRO, PACKAGE FOLDER & SERVICE PACK FROM PRODSPEC.INI
SET "ISTSE="
SET "PKGDIR=PACKAGES"
SET "SP6_PKG=sp6ai386.exe"
FOR /F "DELIMS=" %%I IN ('FINDSTR /BIR "Localization" "SOURCE\I386\PRODSPEC.INI"') DO SET "%%I"
FOR /F "TOKENS=3,4 DELIMS== " %%I IN ('FINDSTR /BIR "Product" "SOURCE\I386\PRODSPEC.INI"') DO (
    IF /I "%%I"=="NT" (
        IF /I "%%J"=="Workstation" (
            SET "DISTRO=WKS"
            SET "CDTAG=CDROM_W.40"
            SET "ISO_FILE_NAME=NT4SP6W.iso"
            SET "ISO_VOLUME_LABEL=NT4SP6W"
        ) ELSE (
            SET "DISTRO=SRV"
            SET "CDTAG=CDROM_S.40"
            SET "ISO_FILE_NAME=NT4SP6S.iso"
            SET "ISO_VOLUME_LABEL=NT4SP6S"
        )
    )
)
FINDSTR /I "Terminal" "SOURCE\I386\PRODSPEC.INI" >NUL 2>&1
IF %ERRORLEVEL% EQU 0 SET "ISTSE=1"
IF EXIST "SOURCE\CDROM_TS.40" SET "ISTSE=1"

IF DEFINED ISTSE (
    SET "PKGDIR=PACKAGES_TS"
    SET "DISTRO=SRV"
    SET "CDTAG=CDROM_TS.40"
    SET "SP6_PKG=wtsi386.exe"
    SET "ISO_FILE_NAME=NT4SP6T.iso"
    SET "ISO_VOLUME_LABEL=NT4SP6T"
)

IF NOT EXIST "%~dp0%SP6_PKG%" (
    ECHO.
    ECHO [ERROR] Please place %SP6_PKG% in the same folder as %~nx0.
    PAUSE
    EXIT /B 1
)

MD "SOURCE_NEW\I386" "WORK\CDROOT\I386\UNIPROC"
IF /I "%RUNMODE%"=="D" ECHO Localization=%Localization% ^| DISTRO=%DISTRO% ^| CDTAG=%CDTAG% ^| SP6_PKG=%SP6_PKG%


REM *** INITIALIZE TXTSETUP.SIF & DOSNET.INF
COPY "SOURCE\I386\TXTSETUP.SIF" /A "SOURCE_NEW\I386\TXTSETUP.SIF" /B >NUL
(
    ECHO.
    ECHO [SourceDisksFiles]
) >> "SOURCE_NEW\I386\TXTSETUP.SIF"

COPY "SOURCE\I386\DOSNET.INF" /A "SOURCE_NEW\I386\DOSNET.INF" /B >NUL
(
    ECHO.
    ECHO [Files]
) >> "SOURCE_NEW\I386\DOSNET.INF"

(
    ECHO 31 = Web
    ECHO 32 = system32\Setup
    ECHO 60 = AppPatch
) > "WORK\NTDIRS.TXT"

REM *********************************************************************************
REM ************************ COPY BASE SOURCE FILES *********************************
REM *********************************************************************************
TITLE %HEADTITLE% - Copying base NT 4.0 source
ECHO.
ECHO Copying base NT 4.0 source files...
XCOPY /D /E /Y /Q "SOURCE" "SOURCE_NEW\" >NUL
ATTRIB -R "SOURCE_NEW\*.*" /S /D >NUL 2>&1

REM *********************************************************************************
REM ************************ PACKAGES & HOTFIXES ************************************
REM *********************************************************************************
SET "ENCRYPTION=56"
CALL :SP6
IF EXIST "%PKGDIR%\InstMsiW.exe" CALL :WI20

SET "HFX=100"
:: Normal processing with separate INF
IF EXIST "%PKGDIR%\*q*i.exe" (
    DIR /B /ON "%PKGDIR%\*q*i.exe" > "WORK\HFXXt.TXT"
    FINDSTR /VI "299444" "WORK\HFXXt.TXT" >> "WORK\HFXX.TXT"
)
IF EXIST "%PKGDIR%\WindowsNT4*.exe" (
    DIR /B /ON "%PKGDIR%\WindowsNT4*.exe" >> "WORK\HFXX.TXT"
)
IF EXIST "WORK\HFXX.TXT" (
    FOR /F "USEBACKQ DELIMS=" %%I IN ("WORK\HFXX.TXT") DO (
        SET "HFXPKG=%%I"
        CALL :XTYPE
    )
)

:: BasicReg packages (INF not copied separately; set Installed flag in hive)
IF EXIST "%PKGDIR%\BASICREG\*.exe" (
    FOR /F "DELIMS=" %%I IN ('DIR /B /ON "%PKGDIR%\BASICREG\*.exe"') DO (
        ECHO BASICREG\%%I>> "WORK\HFXX2.TXT"
    )
)
IF EXIST "WORK\HFXX2.TXT" (
    SET "HFXBASIC=1"
    FOR /F "USEBACKQ DELIMS=" %%I IN ("WORK\HFXX2.TXT") DO (
        SET "HFXPKG=%%I"
        CALL :XTYPE
    )
)

REM *** POST-PROCESSING
MD "WORK\CDROOT\I386\SYSTEM32" >NUL 2>&1
IF EXIST "WORK\CDROOT\I386\NTDLL.DLL" COPY /Y "WORK\CDROOT\I386\NTDLL.DLL" "WORK\CDROOT\I386\SYSTEM32\" >NUL

:: Patch oleaccrc.dll PE checksum natively via imagehlp.dll (replaces ModifyPE.exe)
IF EXIST "WORK\CDROOT\I386\oleaccrc.dll" (
    ECHO.
    ECHO Fixing oleaccrc.dll PE checksum...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $cs='using System; using System.IO; using System.Runtime.InteropServices; public class PeFix { [DllImport(\"imagehlp.dll\",SetLastError=true)] public static extern IntPtr CheckSumMappedFile(byte[] BaseAddress, uint FileLength, out uint HeaderSum, out uint CheckSum); public static void Patch(string path) { byte[] data=File.ReadAllBytes(path); uint origSum, newSum; IntPtr hdr=CheckSumMappedFile(data,(uint)data.Length,out origSum,out newSum); if(hdr==IntPtr.Zero) throw new Exception(\"CheckSumMappedFile failed\"); int peOffset=BitConverter.ToInt32(data,0x3C); Array.Copy(BitConverter.GetBytes(newSum),0,data,peOffset+0x58,4); File.WriteAllBytes(path,data); } }'; Add-Type -TypeDefinition $cs; [PeFix]::Patch((Resolve-Path 'WORK\CDROOT\I386\oleaccrc.dll').Path);"
)

IF EXIST "WORK\CDROOT\I386\htrn_jis.dll" (
    CALL :EXPAND_NT4 "SOURCE\I386\COMMUNIC.IN_" "WORK"
    COPY "WORK\communic.inf" /A "WORK\communi2.inf" /B >NUL
FINDSTR /VBIR "\[HypertrmCopyFilesProg\] hypertrm\.exe" "WORK\communi2.inf" > "WORK\CDROOT\I386\communic.inf"
(
ECHO.
ECHO [SourceDisksNames]
ECHO 1="Windows CD","%CDTAG%",,
ECHO.
ECHO [SourceDisksFiles]
ECHO htrn_jis.dll=1
ECHO.
ECHO [HypertrmCopyFilesProg]
ECHO hypertrm.exe
ECHO htrn_jis.dll,I386\htrn_jis.dll
) >> "WORK\CDROOT\I386\communic.inf"
ECHO htrn_jis.dll = 1,,,,,,,,3,3 >> "SOURCE_NEW\I386\TXTSETUP.SIF"
ECHO d1,htrn_jis.dll >> "SOURCE_NEW\I386\DOSNET.INF"
)
REM *********************************************************************************
REM ************************ FINISH SETUP FILES (SINGLE-PASS) ***********************
REM *********************************************************************************
TITLE %HEADTITLE% - Finishing up setup information files
ECHO.
ECHO Finishing up setup information files...
FOR /F "TOKENS=1 DELIMS==	 " %%I IN ('FINDSTR ",,," "SOURCE_NEW\I386\TXTSETUP.SIF"') DO (
ECHO %%I>> "WORK\FULLSRC.TXT"
)
DIR /B /A-D "WORK\CDROOT\I386" > "WORK\NSFALL.TXT"
FINDSTR /VIB /G:"WORK\FULLSRC.TXT" "WORK\NSFALL.TXT" > "WORK\NSFALL1.TXT"
(FOR /F "USEBACKQ DELIMS=" %%I IN ("WORK\NSFALL1.TXT") DO ECHO d1,%%I) >> "SOURCE_NEW\I386\DOSNET.INF"
(
FOR /F "USEBACKQ DELIMS=" %%I IN ("WORK\NSFALL1.TXT") DO (
SET "EXT=%%~xI"
SET "DIRID=2"
IF /I "!EXT!"==".SYS" SET "DIRID=4"
IF /I "!EXT!"==".INF" SET "DIRID=20"
IF /I "!EXT!"==".ADM" SET "DIRID=20"
IF /I "!EXT!"==".CHM" SET "DIRID=21"
IF /I "!EXT!"==".HLP" SET "DIRID=21"
IF /I "!EXT!"==".TTF" SET "DIRID=22"
IF /I "!EXT!"==".HTT" SET "DIRID=31"
IF /I "!EXT!"==".SDB" SET "DIRID=60"
ECHO %%I = 1,,,,,,,!DIRID!,0,0
)
ECHO.
ECHO [WinntDirectories]
TYPE "WORK\NTDIRS.TXT"
) >> "SOURCE_NEW\I386\TXTSETUP.SIF"
CALL :EXPAND_NT4 "SOURCE_NEW\I386\SYSSETUP.IN_" "WORK"
FINDSTR /VIR "\[Infs\.Always\] DefaultInstall" "WORK\SYSSETUP.INF" > "WORK\CDROOT\I386\SYSSETUP.INF"
(
ECHO.
ECHO [Infs.Always]
IF EXIST "WORK\TOSYSSETUPA.INF" TYPE "WORK\TOSYSSETUPA.INF"
FINDSTR /I "DefaultInstall" "WORK\SYSSETUP.INF"
IF EXIST "WORK\TOSYSSETUP.INF" TYPE "WORK\TOSYSSETUP.INF"
) >> "WORK\CDROOT\I386\SYSSETUP.INF"
REM *** REGISTRY HIVES
SET "REG=%SystemRoot%\System32\reg.exe"
IF EXIST "TOOLS\reg.exe" SET "REG=TOOLS\reg.exe"
IF EXIST "%REG%" CALL :HIVES
REM *********************************************************************************
REM ************************ SLIPSTREAM NEW BINARIES (UNCOMPRESSED) *****************
REM *********************************************************************************
TITLE %HEADTITLE% - Slipstreaming new and updated binaries
ECHO.
ECHO Slipstreaming new and updated binaries...
SET "CDROOT_PREFIX=%CD%\WORK\CDROOT\"
FOR /F "DELIMS=" %%I IN ('DIR /B /S /A-D /ON "WORK\CDROOT"') DO (
SET "FULLSRC=%%I"
SET "RELFILE=!FULLSRC:%CDROOT_PREFIX%=!"
CALL :SLIP_ONE "!RELFILE!"
)
REM *********************************************************************************
REM ************************ THE DUMPSTER *******************************************
REM *********************************************************************************
SET "DUMPBIN="
FOR /F %%I IN ('DIR /B "DUMP"') DO SET "DUMPBIN=1"
IF DEFINED DUMPBIN (
ECHO.
ECHO Copying custom files from DUMP\ into SOURCE_NEW\...
XCOPY /E /H /Y "DUMP" "SOURCE_NEW\" >NUL
)
REM *********************************************************************************
REM ************************ CLEANUP & ISO CREATION *********************************
REM *********************************************************************************
ECHO.
ECHO Cleaning up temporary files...
RD /Q /S "WORK"

SET "ISOCREATED="
IF /I NOT "%RUNMODE%"=="D" IF /I "%CREATE_ISO%"=="YES" CALL :ISO

TITLE %HEADTITLE% - Done
ECHO.
ECHO ===============================================================================
ECHO.
ECHO  NT4 Alive has finished! Your updated NT 4.0 source is in: SOURCE_NEW\
IF DEFINED ISOCREATED ECHO  Bootable ISO created: %ISO_FILE_NAME%
ECHO.
IF /I NOT "%RUNMODE%"=="D" IF /I NOT "%RUNMODE%"=="FULLAUTO" (
    ECHO  Press any key to quit...
    PAUSE >NUL
)
GOTO :EOF


REM ////////////////////////////////////////////////////////////////////////////////////////////////////////////


REM *********************************************************************************
REM ************************ HELPER: PACKAGE EXTRACTOR ******************************
REM *********************************************************************************
:EXTRACT_PKG
SET "PKG_SRC=%~1"
SET "PKG_DST=%~2"
IF NOT EXIST "%PKG_DST%" MD "%PKG_DST%"
START /WAIT "" "%PKG_SRC%" /U /X:"%PKG_DST%"
EXIT /B


REM *********************************************************************************
REM ************************ HELPER: LEGACY SZDD/IN_ EXPANDER ***********************
REM *********************************************************************************
:EXPAND_NT4
SET "EXP_SRC=%~1"
SET "EXP_DST=%~2"
IF DEFINED SEVENZIP (
    "%SEVENZIP%" e "%EXP_SRC%" -o"%EXP_DST%" -y >NUL 2>&1
    IF !ERRORLEVEL! EQU 0 EXIT /B 0
)
"%SystemRoot%\System32\expand.exe" "%EXP_SRC%" "%EXP_DST%" >NUL 2>&1
EXIT /B


REM *********************************************************************************
REM ************************ HELPER: SLIPSTREAM SINGLE FILE *************************
REM *********************************************************************************
:SLIP_ONE
SET "RELFILE=%~1"
SET "RELDIR=!RELFILE:%~nx1=!"
SET "MAKEDIR=SOURCE_NEW\!RELDIR!"
IF "!MAKEDIR:~-1!"=="\" SET "MAKEDIR=!MAKEDIR:~0,-1!"
SET "FNAME=%~n1"
SET "FEXT=%~x1"
ECHO   !RELFILE!
IF NOT EXIST "!MAKEDIR!" MD "!MAKEDIR!"
IF DEFINED FEXT IF EXIST "!MAKEDIR!\!FNAME!!FEXT:~0,3!_" DEL /Q /F "!MAKEDIR!\!FNAME!!FEXT:~0,3!_" >NUL 2>&1
COPY /Y "WORK\CDROOT\!RELFILE!" "!MAKEDIR!\" >NUL
GOTO :EOF


REM *********************************************************************************
REM ************************ SERVICE PACK 6A ****************************************
REM *********************************************************************************
:SP6
TITLE %HEADTITLE% - Processing Service Pack 6a
ECHO.
ECHO Processing Service Pack 6a...
ECHO   Using %SP6_PKG%...
CALL :EXTRACT_PKG "%~dp0%SP6_PKG%" "%~dp0TEMP"

IF EXIST "TEMP\enhsig.dll" SET "ENCRYPTION=128"

:: Q299444 Security Rollup Package
SET "SRP="
IF EXIST "%PKGDIR%\*299444*.exe" FOR /F "DELIMS=" %%I IN ('DIR /B "%PKGDIR%\*299444*.exe"') DO SET "SRP=%%I"
IF DEFINED SRP (
    ECHO   Embedding %SRP%...
    MD "TEMP\299444\UNIPROC" >NUL 2>&1
    CALL :EXTRACT_PKG "%PKGDIR%\%SRP%" "%~dp0TEMP\299444"
    IF EXIST "TEMP\299444\SYMBOLS" RD /Q /S "TEMP\299444\SYMBOLS"
    IF EXIST "TEMP\299444\hotfix.exe" DEL /Q /F "TEMP\299444\hotfix.exe"
    IF "%ENCRYPTION%"=="128" IF EXIST "TEMP\299444\128bit\*.*" MOVE /Y "TEMP\299444\128bit\*.*" "TEMP\299444\" >NUL
    IF EXIST "TEMP\299444\128bit" RD /Q /S "TEMP\299444\128bit"
    IF EXIST "TEMP\299444\browser.dll" REN "TEMP\299444\browser.dll" "browsern.dll"
    IF EXIST "TEMP\299444\browser2.dll" REN "TEMP\299444\browser2.dll" "browser.dll"
    DEL /Q /F "TEMP\299444\fp4autl.dll" "TEMP\299444\pbserver.dll" "TEMP\299444\asp.dll" "TEMP\299444\iischema.dll" "TEMP\299444\iislog.dll" "TEMP\299444\iscomlog.dll" "TEMP\299444\wam.dll" "TEMP\299444\adsiis.dll" "TEMP\299444\rmiisupd.cmd" >NUL 2>&1
    XCOPY /S /H /Y "TEMP\299444" "TEMP\" >NUL
    RD /Q /S "TEMP\299444"
)

:: Prune unused Alpha, MTS/DTC, NetWare, Cluster, RRAS, and IIS4 components
DEL /Q /F "TEMP\xenroll.axp" "TEMP\*.SOFTEX" "TEMP\aic78xx.001" "TEMP\INTLFXSR.SYS" "TEMP\splayout.inf" "TEMP\spuninst.exe" "TEMP\tagfile.1" "TEMP\MARKVIS.HLP" >NUL 2>&1
DEL /Q /F "TEMP\MTX*" "TEMP\clex_*" "TEMP\MTS*" "TEMP\Test*" "TEMP\MSDTC*" "TEMP\DTC*" "TEMP\*.h" "TEMP\*.lib" >NUL 2>&1
DEL /Q /F "TEMP\enumtx.dll" "TEMP\txctx.dll" "TEMP\readme.hlp" "TEMP\readme.cnt" "TEMP\daccom.dll" "TEMP\mfcsubs.dll" >NUL 2>&1
DEL /Q /F "TEMP\account.rc" "TEMP\javaguid.exe" "TEMP\SampDtcC.exe" "TEMP\xaswitch.pdb" "TEMP\ADME.DLL" "TEMP\ENUDTC.DLL" >NUL 2>&1
DEL /Q /F "TEMP\LOGMGR.DLL" "TEMP\SVCSRVL.DLL" "TEMP\XOLEHLP.DLL" >NUL 2>&1
DEL /Q /F "TEMP\ATTACH.EXE" "TEMP\CAPTURE.EXE" "TEMP\CHGPASS.EXE" "TEMP\ENDCAP.EXE" "TEMP\LOGIN.EXE" "TEMP\LOGOUT.EXE" "TEMP\MAP.EXE" "TEMP\SETPASS.EXE" "TEMP\SLIST.EXE" >NUL 2>&1
DEL /Q /F "TEMP\AUTHSAM.DLL" "TEMP\AUTHSRV.EXE" "TEMP\SIGHTNT.DLL" >NUL 2>&1
DEL /Q /F "TEMP\CLUADMIN.EXE" "TEMP\CLUADMEX.DLL" "TEMP\CLUSETUP.EXE" "TEMP\CLUSPRXY.EXE" "TEMP\CLUSRES.DLL" "TEMP\CLUSSVC.EXE" >NUL 2>&1
DEL /Q /F "TEMP\DEBUGEX.DLL" "TEMP\IISCLUS3.DLL" "TEMP\RESRCMON.EXE" "TEMP\RPCLTCCL.DLL" "TEMP\RPCLTSCL.DLL" >NUL 2>&1

IF EXIST "TEMP\MPRAPI.STE" REN "TEMP\MPRAPI.STE" "mprapi.dll"
DEL /Q /F "TEMP\*.STE" >NUL 2>&1

DEL /Q /F "TEMP\*.IS4" "TEMP\*.bcp" "TEMP\*.CMD" "TEMP\exair*" "TEMP\bookflight.asp" "TEMP\ii*.asp" "TEMP\js*.asp" "TEMP\TEMPLATE.ASP" >NUL 2>&1
DEL /Q /F "TEMP\URLFORM.ASP" "TEMP\welcome.asp" "TEMP\finish.inc" "TEMP\adsiis.tlb" "TEMP\Build.vbs" "TEMP\BROWSCAP.INI" >NUL 2>&1
DEL /Q /F "TEMP\CERTMAP.OCX" "TEMP\global.asa" "TEMP\HTTPEXT.H" "TEMP\IISsettings.bas" "TEMP\mssccprj.scc" "TEMP\IISLOG.DLL" >NUL 2>&1
DEL /Q /F "TEMP\IISUI.DLL" "TEMP\INETMGR.DLL" "TEMP\ISATQ.DLL" "TEMP\ISCOMLOG.DLL" "TEMP\IWRPS.DLL" "TEMP\KEYRING.EXE" >NUL 2>&1
DEL /Q /F "TEMP\METADATA.DLL" "TEMP\MYINFO.DLL" "TEMP\NNTPSNAP.DLL" "TEMP\NNTPSVC.DLL" "TEMP\PWSDATA.DLL" "TEMP\PWS.EXE" >NUL 2>&1
DEL /Q /F "TEMP\SMTPSNAP.DLL" "TEMP\SMTPSVC.DLL" "TEMP\WAM.DLL" "TEMP\WAMREG.DLL" "TEMP\WAMPS.DLL" "TEMP\COADMIN.DLL" >NUL 2>&1
DEL /Q /F "TEMP\IISADMIN.DLL" "TEMP\LONSINT.DLL" "TEMP\NSEPM.DLL" "TEMP\W3EXT.DLL" "TEMP\CLUSIIS4.DLL" "TEMP\IISCLEX4.DLL" >NUL 2>&1
DEL /Q /F "TEMP\MBOXAPI.DLL" "TEMP\IISCHEMA.DLL" "TEMP\MDUTIL.EXE" "TEMP\W3KEY.DLL" "TEMP\W3CTRS.DLL" "TEMP\FTPCTRS2.DLL" >NUL 2>&1
DEL /Q /F "TEMP\ciadmin.dll" "TEMP\cidaemon.exe" "TEMP\cisvc.exe" "TEMP\idq.dll" "TEMP\infosoft.dll" "TEMP\ixsso.dll" >NUL 2>&1
DEL /Q /F "TEMP\msidxs.dll" "TEMP\nlgwbrkr.dll" "TEMP\nlhtml.dll" "TEMP\offfilt.dll" "TEMP\qperf.dll" "TEMP\query.dll" >NUL 2>&1
DEL /Q /F "TEMP\webhits.dll" "TEMP\adsiis.dll" "TEMP\WAMREGPS.DLL" "TEMP\ADMWPROX.DLL" "TEMP\IISMAP.DLL" "TEMP\VBSCRIPT.DLL" >NUL 2>&1
DEL /Q /F "TEMP\JSCRIPT.DLL" "TEMP\SCRRUN.DLL" "TEMP\DISPEX.DLL" "TEMP\IIS_U.DLL" "TEMP\COMCTL32.W9X" "TEMP\CMMGR32.EXE" >NUL 2>&1
DEL /Q /F "TEMP\COUNTRY.TXT" "TEMP\EMPTY_PB.MDB" "TEMP\PB*" >NUL 2>&1

:: Per distro cleanup
IF "%DISTRO%"=="WKS" DEL /Q /F "TEMP\*.SRV" "TEMP\TCMAPP.EXE" >NUL 2>&1
IF "%DISTRO%"=="SRV" DEL /Q /F "TEMP\*.WKS" >NUL 2>&1
FOR /F %%I IN ('DIR /B "TEMP\OEM*.%DISTRO%" 2^>NUL') DO REN "TEMP\%%I" "%%~nI.inf"
IF EXIST "TEMP\INETSTP.%DISTRO%" REN "TEMP\INETSTP.%DISTRO%" "INETSTP.INF"
IF EXIST "TEMP\00_iis.%DISTRO%" REN "TEMP\00_iis.%DISTRO%" "00_IIS.HTM"

:: msconv97.dll & WORDPAD.INF
CALL :EXPAND_NT4 "SOURCE\I386\WORDPAD.IN_" "WORK"
COPY "WORK\wordpad.inf" /A "WORK\wordpad2.inf" /B >NUL
FINDSTR /VBIR "\[WordPadCopyFiles\] mswd6 wordpad\.exe write32" "WORK\wordpad2.inf" > "TEMP\wordpad.inf"
(
    ECHO.
    ECHO [SourceDisksNames]
    ECHO 1="Windows CD","%CDTAG%",,
    ECHO.
    ECHO [SourceDisksFiles]
    ECHO msconv97.dll=1
    ECHO.
    ECHO [WordPadCopyFiles]
    ECHO mswd6_32.wpc
    ECHO wordpad.exe
    ECHO write32.wpc
    ECHO msconv97.dll,I386\msconv97.dll
) >> "TEMP\wordpad.inf"

IF EXIST "TEMP\desktop.x" REN "TEMP\desktop.x" "DESKTOP.INI"
IF EXIST "TEMP\certsrv.inf" COPY /Y "TEMP\certsrv.inf" "TEMP\certsrv2.inf" >NUL

:: IIS 3
DEL /Q /F "TEMP\ASP.DLL" >NUL 2>&1
MD "TEMP\INETSRV\HTMLA" "TEMP\INETSRV\HTMLDOCS" >NUL 2>&1
FOR %%F IN (CONVLOG.EXE FSCFG.DLL FTPSVC2.DLL GOPHERD.DLL GSCFG.DLL HTTPODBC.DLL INETMGR.EXE INETSTP.DLL INETSTP.EXE INETSTP.INF INFOCOMM.DLL SSINC.DLL SSPIFILT.DLL W3SCFG.DLL W3SVC.DLL) DO (
    IF EXIST "TEMP\%%F" MOVE /Y "TEMP\%%F" "TEMP\INETSRV\" >NUL 2>&1
)
IF EXIST "TEMP\DEFAULT.HTM" MOVE /Y "TEMP\DEFAULT.HTM" "TEMP\INETSRV\HTMLA\" >NUL 2>&1
IF EXIST "TEMP\ISM.DLL" MOVE /Y "TEMP\ISM.DLL" "TEMP\INETSRV\HTMLA\" >NUL 2>&1
IF EXIST "TEMP\*.HTR" MOVE /Y "TEMP\*.HTR" "TEMP\INETSRV\HTMLA\" >NUL 2>&1
IF EXIST "TEMP\00_IIS.HTM" MOVE /Y "TEMP\00_IIS.HTM" "TEMP\INETSRV\HTMLDOCS\" >NUL 2>&1

:: Batch-append SP6a entries to TXTSETUP.SIF & DOSNET.INF
(
    ECHO IEHELP.EXE = 1,,,,,,,1,0,0
    ECHO SNMPELEA.DLL = 1,,,,,,,1,0,0
    ECHO SNMPELMG.DLL = 1,,,,,,,1,0,0
    ECHO odbcinst.cnt = 1,,,,,,,2,0,0
    ECHO odbcinst.hlp = 1,,,,,,,2,0,0
    ECHO README.HTM = 1,,,,,,,2,0,0
    ECHO BULL18.DLL = 1,,,,,,,11,0,0
    ECHO BULL24.DLL = 1,,,,,,,11,0,0
    ECHO BULL9.DLL = 1,,,,,,,11,0,0
    ECHO BULLASER.DLL = 1,,,,,,,11,0,0
    ECHO DPCPCL.DLL = 1,,,,,,,11,0,0
    ECHO HP5SIM.DLL = 1,,,,,,,11,0,0
    ECHO HP5SIMUI.DLL = 1,,,,,,,11,0,0
    ECHO HPRASDD.DLL = 1,,,,,,,11,0,0
    ECHO HPRASDUI.DLL = 1,,,,,,,11,0,0
    ECHO LMINKJET.DLL = 1,,,,,,,11,0,0
    ECHO MTPCL.DLL = 1,,,,,,,11,0,0
    ECHO PCL5EMS2.DLL = 1,,,,,,,11,0,0
    ECHO SHRPCL5E.DLL = 1,,,,,,,11,0,0
    ECHO X42XXPCL.DLL = 1,,,,,,,11,0,0
    ECHO XEROXDCS.DLL = 1,,,,,,,11,0,0
    ECHO certocm.dll = 1,,,,,,,32,0,0
    ECHO certsrv2.inf = 1,,,,,,,32,0,0,certsrv.inf
    ECHO msconv97.dll = 1,,,,,,,,3,3
    ECHO AppServ.cla = 1,,,,,,,1201,0,0,AppServer.class
    ECHO Context.cla = 1,,,,,,,1201,0,0,Context.class
    ECHO IMTxAS.cla = 1,,,,,,,1201,0,0,IMTxAS.class
    ECHO ObjCont.cla = 1,,,,,,,1201,0,0,ObjectContext.class
    ECHO SecProp.cla = 1,,,,,,,1201,0,0,SecurityProperty.class
    ECHO ceaccept.asp = 1,,,,,,,1202,0,0
    ECHO ceenroll.asp = 1,,,,,,,1202,0,0
    ECHO xenroll.cab = 1,,,,,,,1203,0,0
    ECHO xenroll.x86 = 1,,,,,,,1204,0,0,xenroll.dll
) >> "SOURCE_NEW\I386\TXTSETUP.SIF"

(
    FOR %%F IN (IEHELP.EXE SNMPELEA.DLL SNMPELMG.DLL odbcinst.cnt odbcinst.hlp README.HTM BULL18.DLL BULL24.DLL BULL9.DLL BULLASER.DLL DPCPCL.DLL HP5SIM.DLL HP5SIMUI.DLL HPRASDD.DLL HPRASDUI.DLL LMINKJET.DLL MTPCL.DLL PCL5EMS2.DLL SHRPCL5E.DLL X42XXPCL.DLL XEROXDCS.DLL certocm.dll certsrv2.inf msconv97.dll AppServ.cla Context.cla IMTxAS.cla ObjCont.cla SecProp.cla ceaccept.asp ceenroll.asp xenroll.cab xenroll.x86) DO (
        ECHO d1,%%F
    )
) >> "SOURCE_NEW\I386\DOSNET.INF"

IF EXIST "TEMP\AppServer.class" REN "TEMP\AppServer.class" "AppServ.cla"
IF EXIST "TEMP\Context.class" REN "TEMP\Context.class" "Context.cla"
IF EXIST "TEMP\IMTxAS.class" REN "TEMP\IMTxAS.class" "IMTxAS.cla"
IF EXIST "TEMP\ObjectContext.class" REN "TEMP\ObjectContext.class" "ObjCont.cla"
IF EXIST "TEMP\SecurityProperty.class" REN "TEMP\SecurityProperty.class" "SecProp.cla"

(
    ECHO 1201 = Java\TrustLib\com\ms\mtx
    ECHO 1202 = system32\CertSrv\CertEnroll
    ECHO 1203 = system32\CertSrv\CertControl
    ECHO 1204 = system32\CertSrv\CertControl\x86
) >> "WORK\NTDIRS.TXT"

:: Network Monitor for SRV and WKS DevEd
IF EXIST "TEMP\browsern.dll" (
    IF EXIST "SOURCE\I386\NETMON\NMAPI.DLL" (
        MD "TEMP\NETMON" >NUL 2>&1
        MOVE /Y "TEMP\nmapi.dll" "TEMP\NETMON\" >NUL
        MOVE /Y "TEMP\parser.ini" "TEMP\NETMON\" >NUL
        (
            ECHO atalk.dll = 1,,,,,,,1205,0,0
            ECHO bone.dll = 1,,,,,,,1205,0,0
            ECHO browsern.dll = 1,,,,,,,1205,0,0,browser.dll
            ECHO ipx.dll = 1,,,,,,,1205,0,0
            ECHO ncp.dll = 1,,,,,,,1205,0,0
            ECHO netbios.dll = 1,,,,,,,1205,0,0
            ECHO ppp.dll = 1,,,,,,,1205,0,0
            ECHO smb.dll = 1,,,,,,,1205,0,0
            ECHO snmp.dll = 1,,,,,,,1205,0,0
            ECHO tcpip.dll = 1,,,,,,,1205,0,0
            ECHO trail.dll = 1,,,,,,,1205,0,0
            ECHO vines.dll = 1,,,,,,,1205,0,0
        ) >> "SOURCE_NEW\I386\TXTSETUP.SIF"

(
FOR %%F IN (atalk.dll bone.dll browsern.dll ipx.dll ncp.dll netbios.dll ppp.dll smb.dll snmp.dll tcpip.dll trail.dll vines.dll) DO ECHO d1,%%F
) >> "SOURCE_NEW\I386\DOSNET.INF"
ECHO 1205 = system32\netmon\parsers>> "WORK\NTDIRS.TXT"
) ELSE (
DEL /Q /F "TEMP\nmapi.dll" "TEMP\parser.ini" "TEMP\atalk.dll" "TEMP\bone.dll" "TEMP\browsern.dll" "TEMP\ipx.dll" "TEMP\ncp.dll" "TEMP\netbios.dll" "TEMP\ppp.dll" "TEMP\smb.dll" "TEMP\snmp.dll" "TEMP\tcpip.dll" "TEMP\trail.dll" "TEMP\vines.dll" >NUL 2>&1
)
)
:: Create sp6a.inf
(
ECHO [Version]
ECHO Signature="$WINDOWS NT$"
ECHO [DefaultInstallA]
ECHO DelReg=DelReg.Custom
ECHO [DefaultInstallB]
ECHO AddReg=Product.Add.Reg,Product.Add.Reg.x86,Product.RunOnce,IE5.Add.Reg,IIS.AddReg
IF "%DISTRO%"=="WKS" (
ECHO AddReg=Product.Add.Reg.Workstation,Workstation.IIS.AddReg
) ELSE (
ECHO AddReg=Server.IIS.AddReg
)
ECHO [DelReg.Custom]
ECHO HKLM,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones"
ECHO HKLM,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\SP4"
ECHO HKLM,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\SP5"
ECHO.
TYPE "TEMP\update\update.inf"
) > "TEMP\sp6a.inf"
ECHO sp6a.inf,DefaultInstallA>> "WORK\TOSYSSETUPA.INF"
ECHO sp6a.inf,DefaultInstallB>> "WORK\TOSYSSETUPA.INF"
:: Create sp6b.inf for Q299444i.EXE
IF EXIST "TEMP\hotfix.inf" (
(
ECHO [Version]
ECHO Signature="$Windows NT$"
ECHO [DefaultInstallC]
ECHO AddReg=Product.Add.Reg
ECHO RunPostSetupCommands=ProcessesToRun
ECHO.
TYPE "TEMP\hotfix.inf"
) > "TEMP\sp6b.inf"
ECHO sp6b.inf,DefaultInstallC>> "WORK\TOSYSSETUPA.INF"
DEL /Q /F "TEMP\hotfix.inf"
)
IF EXIST "TEMP\update" RD /Q /S "TEMP\update"
XCOPY /E /Y /Q "TEMP" "WORK\CDROOT\I386\" >NUL
RD /Q /S "TEMP"
GOTO :EOF
REM *********************************************************************************
REM ************************ WINDOWS INSTALLER 2.0 **********************************
REM *********************************************************************************
:WI20
TITLE %HEADTITLE% - Processing Windows Installer 2.0
ECHO.
ECHO Processing Windows Installer 2.0...
MD "TEMP" >NUL 2>&1
START /WAIT "" "%PKGDIR%\InstMsiW.exe" /Q /T:"%~dp0TEMP" /C
DEL /Q /F "TEMP\*.INF" "TEMP\*.CAT" "TEMP\instmsi.msi" "TEMP\msiinst.exe" >NUL 2>&1
IF EXIST "%PKGDIR%\*299444*.exe" DEL /Q /F "TEMP\shfolder.dll" >NUL 2>&1

(
    ECHO [Version]
    ECHO Signature="$Windows NT$"
    ECHO [DefaultInstall.Custom]
    ECHO RegisterOCXs=RegEm
    ECHO [RegEm]
    ECHO %%11%%\msi.dll
    ECHO %%11%%\msihnd.dll
    ECHO %%11%%\msisip.dll
) > "TEMP\msi.inf"
ECHO msi.inf,DefaultInstall.Custom>> "WORK\TOSYSSETUP.INF"

XCOPY /Y /Q "TEMP" "WORK\CDROOT\I386\" >NUL
RD /Q /S "TEMP"
GOTO :EOF


REM *********************************************************************************
REM ************************ XTYPE HOTFIXES *****************************************
REM *********************************************************************************
:XTYPE
TITLE %HEADTITLE% - Processing %HFXPKG%
ECHO   Processing %HFXPKG%...
MD "TEMP\UNIPROC" >NUL 2>&1
CALL :EXTRACT_PKG "%PKGDIR%\%HFXPKG%" "%~dp0TEMP"

IF EXIST "TEMP\SYMBOLS" RD /Q /S "TEMP\SYMBOLS"
IF EXIST "TEMP\*.DBG" DEL /Q /F "TEMP\*.DBG"
IF EXIST "TEMP\hotfix.exe" DEL /Q /F "TEMP\hotfix.exe"
IF EXIST "TEMP\128bit" (
    IF "%ENCRYPTION%"=="128" (
        MOVE /Y "TEMP\128bit\*.*" "TEMP\" >NUL
    ) ELSE (
        RD /Q /S "TEMP\128bit"
    )
)

IF EXIST "TEMP\hotfix.inf" (
    IF DEFINED HFXBASIC (
        FOR /F "TOKENS=2 DELIMS==" %%I IN ('FINDSTR /IL "HOTFIX_NUMBER=" "TEMP\hotfix.inf"') DO ECHO %%~I>> "WORK\HFXBASIC.TXT"
    ) ELSE (
        SET /A HFX+=1
        (
            ECHO [Version]
            ECHO Signature="$Windows NT$"
            ECHO [DefaultInstall.Custom]
            ECHO DelReg=Product.Del.Reg
            ECHO AddReg=Product.Add.Reg,Product.RunOnce
            ECHO RunPostSetupCommands=ProcessesToRun
            ECHO.
            TYPE "TEMP\hotfix.inf"
        ) > "TEMP\HFX!HFX!.INF"
        ECHO HFX!HFX!.INF,DefaultInstall.Custom>> "WORK\TOSYSSETUP.INF"
    )
    DEL /Q /F "TEMP\hotfix.inf"
)

:: Q323172 & UNIPROC
IF EXIST "TEMP\xenroll.dll" IF NOT EXIST "TEMP\xenroll.x86" COPY /Y "TEMP\xenroll.dll" "TEMP\xenroll.x86" >NUL
IF EXIST "TEMP\kernel32.dll" IF NOT EXIST "TEMP\UNIPROC\kernel32.dll" COPY /Y "TEMP\kernel32.dll" "TEMP\UNIPROC\" >NUL
IF EXIST "TEMP\win32k.sys" IF NOT EXIST "TEMP\UNIPROC\win32k.sys" COPY /Y "TEMP\win32k.sys" "TEMP\UNIPROC\" >NUL
IF EXIST "TEMP\winsrv.dll" IF NOT EXIST "TEMP\UNIPROC\winsrv.dll" COPY /Y "TEMP\winsrv.dll" "TEMP\UNIPROC\" >NUL

XCOPY /E /Y /Q "TEMP" "WORK\CDROOT\I386\" >NUL
RD /Q /S "TEMP"
GOTO :EOF


REM *********************************************************************************
REM ************************ HIVES **************************************************
REM *********************************************************************************
:HIVES
TITLE %HEADTITLE% - Editing registry hives
ECHO.
ECHO Editing NT 4.0 SOFTWARE registry hive...
IF EXIST "SOURCE\I386\SOFTWARE._" (
    CALL :EXPAND_NT4 "SOURCE\I386\SOFTWARE._" "WORK"
    IF EXIST "WORK\SOFTWARE" REN "WORK\SOFTWARE" "SOFTWARE.HIV"
) ELSE IF EXIST "SOURCE\I386\SOFTWARE" (
    COPY /Y "SOURCE\I386\SOFTWARE" "WORK\SOFTWARE.HIV" >NUL
)
IF NOT EXIST "WORK\SOFTWARE.HIV" (
    ECHO   [WARNING] SOFTWARE registry hive not found!
    GOTO :EOF
)

"%REG%" load HKLM\NT4SFT "%~dp0WORK\SOFTWARE.HIV" >NUL
"%REG%" add "HKLM\NT4SFT\Microsoft\GdiDetectionTool" /v GDITool /t REG_DWORD /d 1 /f >NUL
"%REG%" add "HKLM\NT4SFT\Microsoft\Windows\CurrentVersion\Explorer" /v DisableFlushWrites /t REG_BINARY /d 01000000 /f >NUL
"%REG%" add "HKLM\NT4SFT\Microsoft\Windows\CurrentVersion\Explorer" /v UseCopyMaxBufferSize /t REG_BINARY /d 01000000 /f >NUL
IF EXIST "WORK\HFXBASIC.TXT" (
    FOR /F "USEBACKQ DELIMS=" %%I IN ("WORK\HFXBASIC.TXT") DO (
        "%REG%" add "HKLM\NT4SFT\Microsoft\Windows NT\CurrentVersion\Hotfix\%%I" /v Installed /t REG_DWORD /d 1 /f >NUL
    )
)
"%REG%" add "HKLM\NT4SFT\Microsoft\Windows NT\CurrentVersion\Hotfix\Q312895" /v Comments /t REG_SZ /d "Windows NT 4.0 Hotfix [See Q312895 for more information]" /f >NUL
"%REG%" add "HKLM\NT4SFT\Microsoft\Windows NT\CurrentVersion\Hotfix\Q312895" /v Installed /t REG_DWORD /d 1 /f >NUL
"%REG%" add "HKLM\NT4SFT\Microsoft\Windows NT\CurrentVersion\Hotfix\KB840987" /v Installed /t REG_DWORD /d 1 /f >NUL
"%REG%" unload HKLM\NT4SFT >NUL

COPY /Y "WORK\SOFTWARE.HIV" "WORK\CDROOT\I386\software" >NUL
GOTO :EOF

REM *********************************************************************************
REM ************************ CREATE BOOTABLE ISO ************************************
REM *********************************************************************************
:ISO
IF NOT EXIST "TOOLS\BOOT.BIN" (
ECHO   [WARNING] TOOLS\BOOT.BIN not found. Skipping ISO creation.
GOTO :EOF
)
TITLE %HEADTITLE% - Creating bootable ISO image
ECHO.
ECHO Creating bootable ISO image...
IF NOT DEFINED ISO_FILE_NAME (
SET "ISO_FILE_NAME=NT40_SP6a.iso"
) ELSE (
FOR /F "DELIMS=" %%I IN ("%ISO_FILE_NAME%") DO (
IF /I NOT "%%~xI"==".iso" SET "ISO_FILE_NAME=%ISO_FILE_NAME%.iso"
)
)
IF NOT DEFINED ISO_VOLUME_LABEL SET "ISO_VOLUME_LABEL=NT40_SP6A"
IF NOT DEFINED CDIMAGE_SWITCHES SET "CDIMAGE_SWITCHES=-h -j1 -m -o -e"
IF EXIST "%ISO_FILE_NAME%" DEL /Q /F "%ISO_FILE_NAME%"
IF EXIST "TOOLS\CDIMAGE.EXE" (
ECHO   Using TOOLS\CDIMAGE.EXE...
"TOOLS\CDIMAGE.EXE" "-l%ISO_VOLUME_LABEL%" %CDIMAGE_SWITCHES% "-bTOOLS\BOOT.BIN" "SOURCE_NEW" "%ISO_FILE_NAME%"
IF EXIST "%ISO_FILE_NAME%" SET "ISOCREATED=1"
GOTO :EOF
)
IF EXIST "TOOLS\OSCDIMG.EXE" (
ECHO   Using TOOLS\OSCDIMG.EXE...
"TOOLS\OSCDIMG.EXE" "-l%ISO_VOLUME_LABEL%" %CDIMAGE_SWITCHES% "-bTOOLS\BOOT.BIN" "SOURCE_NEW" "%ISO_FILE_NAME%"
IF EXIST "%ISO_FILE_NAME%" SET "ISOCREATED=1"
GOTO :EOF
)
ECHO   [WARNING] Neither TOOLS\CDIMAGE.EXE nor TOOLS\OSCDIMG.EXE was found. Skipping ISO creation.
GOTO :EOF
