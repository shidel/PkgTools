@echo off

if not exist %1.ZIP goto NoExistingZIP
echo %1.ZIP already exists in the current directory
goto End

:NoExistingZIP
if exist %DOSDIR%\PACKAGES\%1.LST goto HaveLSTFile
echo Could not locate package listing File.
goto End

:HaveLSTFile
if exist %DOSDIR%\APPINFO\%1.LSM goto HaveLSMFile
echo Could not locate package metadata File.
goto End

:HaveLSMFile
if exist %DOSDIR%\BIN\ZIP.EXE goto HaveZIPexe
echo Could not locate zip compression program.
goto End

:HaveZIPexe
type %DOSDIR%\PACKAGES\%1.LST | zip -r -9 -S %1.ZIP -@
if errorlevel 1 goto End
dir %1.ZIP

:End
