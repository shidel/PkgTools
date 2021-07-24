{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}
program Package_Maker;

    uses PkgComn, QNLS, QDOS, QStrings;

    type
        PToDo = ^TToDo;
        TToDo = record
            Path : PString;
            Data : longint;
            Next : PToDo
        end;

    const
        InitScan : boolean = False; {After options processed either InitScan }
        PostScan : boolean = False; {or PostScan will be true. Not BOTH }
        DoneScan : boolean = False; { Kill temp file when done }
        DataFile : String = '';     { Temp file name }
        ScanDrives : String = '';
        ToDo     : PToDo = nil;
        TotalFiles : longint = 0;
        TotalDirs  : longint = 0;
        NewFiles : longint = 0;
        NewDirs  : longint = 0;

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
        db 'ERROR.TEMP=TEMP environment variable not set',0
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

        db 'SCAN.INIT=Performing initial scan',0
        db 'SCAN.POST=Performing post install scan',0
        db 'SCAN.WAIT=This could take a while',0
        db 'SCAN.MISSING=Initial scan not found',0

        db 'TEMP.DEL=temporary data file $ deleted'

        db 'STATS=found $0 directories, $1 files, $2'

        db 0
    end;

    procedure CleanUp(ShowMsg : boolean);
    var
        F : File;
        R : integer;
    begin
        if FileExists(DataFile) then begin
            {$I-}
            Assign(F,DataFile);
            Erase(F);
            R := IOResult;
            {$I+}
            if R <> 0 then
                WriteHalt(ErrorMsg(R, DataFile), R);
            if ShowMsg then
                WriteLn(NLSstr('TEMP.DEL', Datafile));
        end;
    end;

    procedure AddToDo(S : String; Data : LongInt);
    var
        P : PToDo;
    begin
        P := New(PToDo);
        P^.Path := StrPtr(S);
        P^.Next := ToDo;
        P^.Data := Data;
        ToDo := P;
        Inc(TotalDirs);
    end;

    function CountStr(SubStr, Str : String) : integer;
    var
        I, P : integer;
    begin
        I := 0;
        P := 1;
        if SubStr <> '' then
            While True do begin
                P := NextPos(SubStr, Str, P);
                if P > 0 then begin
                    Inc(I);
                    P := P + Length(SubStr);
                end else
                    break;
            end;
        CountStr := I;
    end;

    procedure Scanning;
    var
        P, N : PToDo;
        S : TSearchRec;
        D : String;
    begin
        while Assigned(ToDo) do begin
            TestBreak;

            P := ToDo;
            ToDo := P^.Next;
            D := PtrStr(P^.Path);
            FreeStr(P^.Path);
            Dispose(P);

            FindFirst( D + '*.*', faAnyFile, S);
            WriteLn(Space(CountStr(PathDelim, D) * 2), BaseNameOf(NoTailDelim(D)));
            while DOSError = 0 do begin
                TestBreak;
                if S.Attr and faDirectory = faDirectory then begin
                    if (S.Name <> '.') and (S.Name <> '..') then begin
                        AddToDo(D + S.Name + PathDelim, 0);
                    end;
                end else
                    Inc(TotalFiles);
                FindNext(S);
            end;
        end;
    end;

    procedure PerformScan;
    begin
        if InitScan then begin
            WriteLn(NLS('SCAN.INIT'));
        end else begin
            WriteLn(NLS('SCAN.POST'));
        end;
        WriteLn(NLS('SCAN.WAIT'));
        while Length(ScanDrives) > 0 do begin
            AddToDo(ScanDrives[1] + DriveDelim + PathDelim, 0);
            Delete(ScanDrives, 1,1);
        end;
        Scanning;
    end;

    procedure PerformTask;
    var
        I : integer;
    begin
        { Set TEMP Scan Data File Name }
        if DataFile = '' then begin
            DataFile := GetENV('TEMP');
            if DataFile = '' then DataFile := GetENV('TMP');
            if DataFile = '' then WriteHalt(NLS('ERROR.TEMP'),3);
            DataFile := TailDelim(DataFile) + GetEXEBase + '.TMP';
        end;

        if not DirExists(PathOf(DataFile)) then
            WriteHalt(ErrorMsg(3, PathOf(DataFile)) , 3);

        { Scan type not specified, autodetect}
        if InitScan or PostScan = False then begin
            if DoneScan then begin
                CleanUp(True);
                Halt(0);
            end;
            PostScan := FileExists(DataFile);
            InitScan := Not PostScan;
            DoneScan := PostScan;
        end;

        if ScanDrives = '' then begin
            ScanDrives := DriveLetters;
            I := 1;
            While I <= Length(ScanDrives) do begin
                if (LCase(ScanDrives[I]) = ScanDrives[I]) then
                    Delete(ScanDrives, I, 1)
                else
                    Inc(I);
            end;
        end;

        PerformScan;
        if DoneScan then CleanUp(False);
    end;

    function Options(Option : String; var NextParam : Integer) : boolean; far;
    begin
        WriteLn('Opt');
        Options := False;
    end;

begin
    ScanDrives := 'C';
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('');
    ParseCommandLine(Options);
    PerformTask;
end.

