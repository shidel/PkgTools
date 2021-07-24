{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}
program Package_Mover;

    uses PkgComn, QNLS;

    procedure ProgramMessages; assembler;
    asm
        db 'LANGUAGE=Built-in',0
        db 'PROG.NAME=PkgUtil',0
        db 'PROG.VERSION=Version $',0
        db 'PROG.TITLE=PkgUtil',0
        db 'PROG.DESC=Package Utility',0
        db 'PROG.ABORT=aborted',0
        db 'MEM.USAGE=Memory Usage',0
        db 'BAD.SWITCH=invalid switch $',0
        db 'LINE.TOOLONG=Error: Line #$ is too long',0
        db 'ERROR=Error ($)',0
        db 'ERROR.NUMBER=#$',0
        db 'ERROR.2=file not found',0
        db 'ERROR.3=path not found',0

        db 'ALLFILES=Files',0
        db 'BINARIES=Executables',0
        db 'HELP.0=no built-in help available',0
        db 'USAGE=Disk Usage',0
        db 'FILE=$ file',0
        db 'FILES=$ files',0
        db 'BYTE=$ byte',0
        db 'BYTES=$ bytes',0
        db 'KBYTE=$KB',0
        db 'MBYTE=$MB',0
        db 'PACKAGES=$0 of $1 packages shown',0

        db 0
    end;

    function Options(Option : String; var NextParam : Integer) : boolean; far;
    begin
        WriteLn('Opt');
        Options := False;
    end;

begin
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('');
    ParseCommandLine(Options);
end.
