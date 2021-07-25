{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}
program Package_Maker;

    uses PkgComn, QNLS, QDOS, QStrings, QFiles;

    type
        PToDo = ^TToDo;
        TToDo = record
            Path : PString;
            Data : LongInt;
            Time : LongInt;
            Attr : byte;
            Next : PToDo
        end;
        TDataItem = record
            Name : TFileNameString;
            Time : LongInt;
            case Attr : byte of
                faAnyfile   : ( Size : LongInt );
                faDirectory : ( First : LongInt );
        end;

    const
        InitScan : boolean = False;     { After options processed either      }
        PostScan : boolean = False;     { InitScan or PostScan will be true.  }
                                        { But Not BOTH ! }
        DoneScan : boolean = False;     { Kill temp file when done }
        DataFile : PABstractFile = nil; { Temp data file name }
        ScanDrives : String = '';
        ToDo     : PToDo = nil;
        TotalFiles : LongInt = 0;
        TotalDirs  : LongInt = 0;
        TotalBytes : LongInt = 0;
        NewFiles : LongInt = 0;
        NewDirs  : LongInt = 0;
        NewBytes : LongInt = 0;

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
        db 'SCAN.RUN=Scanning...',0
        db 'SCAN.DONE=Done',0
        db 'SCAN.DONE.FAST=Or, not. Wow, that was quick. Done!',0

        db 'TEMP.DEL=temporary data file $ deleted',0
        db 'STATS.NOW=found $0 directories, $1 files, $2',0
        db 'STATS.NEW=found $1 new files and $2',0

        db 0
    end;

    procedure CheckDataFileError;
    var
        R : integer;
    begin
        R := DataFile^.IOResult;
        if R <> 0 then WriteHalt(ErrorMsg(R, DataFile^.Name), R);
    end;

    procedure CleanUp(ShowMsg : boolean);
    var
        F : File;
    begin
        if Not Assigned(DataFile) then exit;
        DataFile^.Erase;
        if ShowMsg then
            WriteLn(NLSstr('TEMP.DEL', Datafile^.Name));
    end;

    procedure UpdateDirItem(APos : LongInt; S : String; Time:LongInt; Attr : byte);
    var
        D : TDataItem;
        X : byte;
    begin
        if not InitScan then Exit;
        DataFile^.Seek(APos);
        CheckDataFileError;
        S := TailDelim(S);
        SetLength(S, Length(S) - 1);
        X :=  LastPos('\', S) + 1;
        FillChar(D.Name, Sizeof(D.Name), 0);
        D.Name := Copy(S, X, Sizeof(TFileNameString));
        D.Attr := Attr;
        D.Time := Time;
        D.First := DataFile^.FileSize;
        DataFile^.WriteRecord(D, Sizeof(D));
        CheckDataFileError;
        DataFile^.SeekEOF;
        CheckDataFileError;
    end;

    procedure AddToDo(S : String; Time : LongInt; Attr : byte);
    var
        P : PToDo;
    begin
        S := TailDelim(S);
        P := New(PToDo);
        P^.Path := StrPtr(S);
        P^.Next := ToDo;

        P^.Data := DataFile^.FileSize;
        P^.Attr := Attr;
        ToDo := P;
        Inc(TotalDirs);
        UpdateDirItem(P^.Data, S, Time, Attr)
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

    procedure ScanStats(New : boolean);
    var
        S : String;
        XE, XF : LongInt;
    begin
       XE := ElapsedTicks(true);
        if XE = 0 then
            XF := 0
        else
            XF := ((TotalFiles + TotalDirs) div XE) * 18;
        { Write('(', ElapsedTicks(False), '/', XE, '/', XF, ') '); }
        if XE < 90 then
            WriteLn(NLS('SCAN.DONE.FAST'))
        else
            WriteLn(NLS('SCAN.DONE'));

        if New then begin
            S := NLS('STATS.NEW');
            S := ReplaceStr(S, '$0', IntStr(NewDirs), True);
            S := ReplaceStr(S, '$1', IntStr(NewFiles), True);
            S := ReplaceStr(S, '$2', SizeStr(NewBytes, True), True);
        end else begin
            S := NLS('STATS.NOW');
            S := ReplaceStr(S, '$0', IntStr(TotalDirs), True);
            S := ReplaceStr(S, '$1', IntStr(TotalFiles), True);
            S := ReplaceStr(S, '$2', SizeStr(TotalBytes, True), True);
        end;
        WriteLn(S);
    end;

    function FetchData(D : String; I : TSearchRec; var O : TDataItem) : boolean;
    const
        LastD : String = '';
        LastP : LongInt = 0;
        LastX : LongInt = 0;
    var
        LastO : TDataItem;
        CurD, DD : String;
    begin
        FetchData := False;
        { Find Branch }
        if LastD <> D then begin
            CurD := '';
            DD := D;
            DataFile^.SeekSOF;
            CheckDataFileError;
            repeat
                TestBreak;
                Tumbler;
                DataFile^.ReadRecord(O, Sizeof(O));
                CheckDataFileError;
                { WriteLn('?', O.Name);}
                if Copy(D, 1, Length(O.Name)) <> O.Name then continue;
                if Copy(D, Length(O.Name) + 1, 1) <> PathDelim then continue;
                DataFile^.Seek(O.First);
                CheckDataFileError;
                CurD := TailDelim(CurD + O.Name);
                Delete(D, 1, Length(TailDelim(O.Name)));
            until (O.Name = '') or (D = '');
            { WriteLn(CurD, ' (', D, ')'); }
            CheckDataFileError;
            if (O.Name = '') then Exit; { DataFile^.Result := 9; }
            if (D <> '') then  Exit; { DataFile^.Result := 18; }
            LastD := CurD;
            LastP := O.First;
            LastX := LastP;
            LastO := O;
        end;
        DataFile^.Seek(LastP);
        { WriteLn('?', D, '>', I.Name);}
        while DataFile^.Result = 0 do begin
            TestBreak;
            Tumbler;
            DataFile^.ReadRecord(O, Sizeof(O));
            { WriteLn(O.Name); }
            if (I.Name = O.Name) then Break;
            if (O.Name = '') then DataFile^.Seek(LastX);
            if (DataFile^.FilePos = LastP) then Break;
        end;
        CheckDataFileError;
        LastP := DataFile^.FilePos;
        FetchData := (I.Name = O.Name);
    end;

    procedure CompareScan(D : String; I : TSearchRec);
    var
        O : TDataItem;
    begin
        if not FetchData(D, I, O) then begin
            WriteLn('New: ', D + I.Name);
        end;

    end;

    procedure Scan;
    var
        P, N : PToDo;
        S : TSearchRec;
        D : String;
        IPath, IName : String;
        I : TDataItem;
    begin
        Write(NLS('SCAN.RUN'));
        ElapsedTicks(true);
        IPath := TailDelim(PathOf(DataFile^.Name));
        IName := Copy(DataFile^.Name, Length(IPath) + 1, Sizeof(TFileNameString));
        while Assigned(ToDo) do begin
            TestBreak;
            Tumbler;

            P := ToDo;
            ToDo := P^.Next;
            D := PtrStr(P^.Path);
            If InitScan then UpdateDirItem(P^.Data, D, P^.Time, P^.Attr);
            Dispose(P);

            FindFirst( D + '*.*', faAnyFile, S);
            { WriteLn(Space(CountStr(PathDelim, D) * 2), BaseNameOf(NoTailDelim(D))); }
            while DOSError = 0 do begin
                TestBreak;
                if S.Attr and faDirectory = faDirectory then begin
                    if (S.Name <> '.') and (S.Name <> '..') then begin
                        AddToDo(D + S.Name + PathDelim, S.Time, S.Attr);
                        if PostScan then CompareScan(D, S);
                    end;
                end else if (IName <> S.Name) or (IPath <> D) then begin
                    Inc(TotalFiles);
                    Inc(TotalBytes, S.Size);
                    if InitScan then begin
                        FillChar(I.Name, Sizeof(I.Name), 0);
                        I.Name := S.Name;
                        I.Attr := S.Attr;
                        I.Time := S.Time;
                        I.Size := S.Size;
                        DataFile^.WriteRecord(I, Sizeof(I));
                    end;
                    if PostScan then CompareScan(D, S);
                end; {else it is our temp file, ignore it}
                FindNext(S);
            end;
            if InitScan then begin
                FillChar(I, Sizeof(I), 0);
                DataFile^.WriteRecord(I, Sizeof(I));
            end;
        end;
        if InitScan then begin
            DataFile^.WriteRecord(I, Sizeof(I));
        end;
        TumblerDone;
        ScanStats(False);
    end;

    procedure PerformScan;
    var
        R : integer;
    begin
        if InitScan then begin
            WriteLn(NLS('SCAN.INIT'));
            DataFile^.Rewrite;
        end else begin
            WriteLn(NLS('SCAN.POST'));
            DataFile^.Reset;
        end;
        CheckDataFileError;
        WriteLn(NLS('SCAN.WAIT'));
        while Length(ScanDrives) > 0 do begin
            AddToDo(ScanDrives[1] + DriveDelim + PathDelim, 0, $ff);
            Delete(ScanDrives, 1,1);
        end;
        Scan;
        DataFile^.Close;
        CheckDataFileError;
    end;

    procedure PerformTask;
    var
        I : integer;
        S : String;
    begin
        { Set TEMP Scan Data File Name }
        if DataFile^.Name = '' then begin
            S := GetENV('TEMP');
            if S = '' then S := GetENV('TMP');
            if S = '' then WriteHalt(NLS('ERROR.TEMP'),3);
            S := TailDelim(S) + GetEXEBase + '.TMP';
            DataFile^.Assign(S);
        end;

        if not DirExists(PathOf(DataFile^.Name)) then
            WriteHalt(ErrorMsg(3, PathOf(DataFile^.Name)) , 3);

        { Scan type not specified, autodetect}
        if InitScan or PostScan = False then begin
            if DoneScan then begin
                CleanUp(True);
                Halt(0);
            end;
            PostScan := FileExists(DataFile^.Name);
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

        DoneScan := False;
        PerformScan;
        if DoneScan then CleanUp(False);
    end;

    function Options(Option : String; var NextParam : Integer) : boolean; far;
    begin
        WriteLn('What?');
        Options := False;
    end;

begin
    ScanDrives := 'C';
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('');
    DataFile := New(PDiskFile, Create(nil));
    ParseCommandLine(Options);
    PerformTask;
end.

