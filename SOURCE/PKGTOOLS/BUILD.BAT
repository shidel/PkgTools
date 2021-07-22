@echo off

if not exist BIN\NUL mkdir BIN
if exist BIN\PKGINFO.EXE deltree /y BIN\*.EXE >NUL
rem if exist BIN\QCRT.TPU deltree /y BIN\*.TPU >NUL

if exist QCRT\PASCAL\QCRT.TPU GOTO HaveQCRT
cd QCRT
call mkdemos.bat
cd ..
:HaveQCRT

call tpc /M /OQCRT\PASCAL /IQCRT\PASCAL -UQCRT\PASCAL -EBIN PKGINFO.PAS

del BIN\*.TPU

if exist bin\pkginfo.exe dir bin\*.exe | grep -i exe
upx -9 --8086 BIN\*.EXE

