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
        DataStart : LongInt = 0;

        OptIncDrvs : String = '';
        OptKeepScan : boolean = false;
        OptMetaOnly : boolean = false;

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
        db 'ERROR.NOPKG=package id/name not specified',0
        db 'ERROR.BADNAME=cannot use $ for package id/name',0
        db 'ERROR.TEMP=TEMP environment variable not set',0
        db 'ERROR.NOINC=can only include drives on the initial scan',0
        db 'ERROR.BADDRV=can not find or access drive $',0
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
        db 'SCAN.POST=Performing secondary scan',0
        db 'SCAN.WAIT=This could take a while',0
        db 'SCAN.MISSING=Initial scan not found',0
        db 'SCAN.RUN=Scanning...',0
        db 'SCAN.DONE=Done',0
        db 'SCAN.DONE.FAST=Or, not. Wow, that was quick. Done!',0

        db 'TEMP.DEL=temporary data file $ deleted',0
        db 'STATS.NOW=found $0 directories, $1 files, $2',0
        db 'STATS.NEW=found $1 new files and $2',0

        db 'IDX.NEW.FILE=New: $',0
        db 'IDX.NEW.DIR=New: $\',0
        db 'IDX.MOD.FILE=Changed: $',0
        db 'IDX.MOD.DIR=Changed: $\',0
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
        P^.Time := Time;
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
        if New = false then begin
            if (NewFiles <> 0) or (NewDirs <> 0) then WriteLn;
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
        end;

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
            DataFile^.Seek(DataStart);
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
            WriteLn(D,I.NAME);
            Halt(0);
            if (I.Attr and faDirectory = faDirectory) then
                Inc(NewDirs)
            else begin
                Inc(NewFiles);
                Inc(NewBytes, I.Size);
            end;
            TumblerDone;
            WriteLn;
            Write(NLSstr('IDX.NEW.' +
                WhichStr(I.Attr and faDirectory = faDirectory, 'FILE', 'DIR'),
                D + I.Name), ' ');
        end else if (I.Attr and faDirectory = faDirectory) and
        (I.Attr and faDirectory = faDirectory) then begin
            { I think we can just ignore modified DIR items }
            { if (I.Time <> O.Time) or (I.Attr <> O.Attr) then begin
                  TumblerDone;
                  WriteLn;
                  Write(NLSstr('IDX.MOD.DIR', D + I.Name), ' ');
            end; }

        end else if (I.Time <> O.Time) or (I.Attr <> O.Attr) or
        (I.Size <> O.Size) then begin
              TumblerDone;
              WriteLn;
              Write(NLSstr('IDX.MOD.FILE', D + I.Name), ' ');
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
        if PostScan then ScanStats(True);
    end;

    procedure PerformScan;
    var
        R : integer;
        S : String;
    begin
        if InitScan then begin
            WriteLn(NLS('SCAN.INIT'));
            DataFile^.Rewrite;
            CheckDataFileError;
            DataFile^.SeekSOF;
            CheckDataFileError;
            DataFile^.PutString(ScanDrives);
            CheckDataFileError;
            DataFile^.PutString(PkgWildCard);
            CheckDataFileError;
        end else begin
            WriteLn(NLS('SCAN.POST'));
            DataFile^.Reset;
            CheckDataFileError;
            DataFile^.SeekSOF;
            CheckDataFileError;
            ScanDrives:=DataFile^.GetString;
            CheckDataFileError;
            S := DataFile^.GetString;
            CheckDataFileError;
            if PkgWildCard = '*' then PkgWildCard := S;
        end;
        CheckDataFileError;
        DataStart := DataFile^.FilePos;
        if PostScan then begin
            if PkgWildCard = '*' then WriteHalt(NLS('ERROR.NOPKG'),1);
            if not ValidPkgName(PkgWildCard) then
                WriteHalt(NLSstr('ERROR.BADNAME', PkgWildCard),1);
        end;
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

        if (OptIncDrvs <> '') and (Not InitScan) then
            WriteHalt(NLS('ERROR.NOINC'), 1);

        if OptIncDrvs = '*' then
            ScanDrives := DriveLetters
        else if OptIncDrvs <> '' then
            ScanDrives := ScanDrives + UCase(OptIncDrvs);

        if ScanDrives <> 'C' then begin
            I := 1;
            While I <= Length(ScanDrives) do begin
                { delete everything except uppercase letters }
                if (LCase(ScanDrives[I]) = ScanDrives[I]) then
                    Delete(ScanDrives, I, 1)
                { remove duplicate drive letters }
                else if (Pos(ScanDrives[I], ScanDrives) < I) then
                    Delete(ScanDrives, I, 1)
                else
                    Inc(I);
            end;
        end;
        if OptKeepScan then DoneScan := False;
        PerformScan;
        if DoneScan then CleanUp(False);
    end;

    function Options(Option : String; var NextParam : Integer) : boolean; far;
    begin
        Options := True;
        if Option = 'I' then begin
            InitScan := True;
            PostScan := False;
            DoneScan := False;
        end else if Option = 'S' then begin
            InitScan := False;
            PostScan := True;
            DoneScan := True;
        end else if Option = 'K' then begin
            DoneScan := False;
            OptKeepScan := True;
        end else if Option = 'M' then begin
            DoneScan := False;
            OptKeepScan := True;
        end else if Option = 'D' then begin
            OptIncDrvs := OptIncDrvs + ParamStr(NextParam);
            Inc(NextParam);
        end else
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

