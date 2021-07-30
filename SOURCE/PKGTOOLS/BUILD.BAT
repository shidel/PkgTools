@echo off
if not exist BIN\NUL mkdir BIN
if exist BIN\PKGINFO.EXE deltree /y BIN\*.EXE >NUL
rem if exist BIN\QCRT.TPU deltree /y BIN\*.TPU >NUL

if exist QCRT\PASCAL\QCRT.TPU GOTO HaveQCRT
cd QCRT
call mkdemos.bat
cd ..
:HaveQCRT
rem if "%1" == "dev" goto DevBuild1


call tpc /M /OQCRT\PASCAL /IQCRT\PASCAL -UQCRT\PASCAL -EBIN PKGINFO.PAS
if not exist BIN\PKGINFO.EXE goto Done
if "%1" == "dev" goto DoneDevBuild

:DevBuild1
if not exist PKGMAKER.PAS goto NoDevBuild
call tpc /M /OQCRT\PASCAL /IQCRT\PASCAL -UQCRT\PASCAL -EBIN PKGMAKER.PAS
if not exist BIN\PKGMAKER.EXE goto Done

:NoDevBuild

del BIN\*.TPU

:DoneDevBuild
if "%1" == "dev" goto NoCompress
upx -9 --8086 BIN\*.EXE
:NoCompress

if exist bin\pkginfo.exe goto ListEXEs
if exist bin\pkgmaker.exe goto ListEXEs
if exist bin\pkgmove.exe goto ListEXEs
goto Done

:ListEXEs
dir bin\*.exe | grep -i exe

:Done
