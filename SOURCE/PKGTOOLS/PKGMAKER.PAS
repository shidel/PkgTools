{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}

{$M 16384,51200,102400}
program Package_Maker;

    { At present, the LSM and MOD file sizes do not count towards byte totals
      But, they should not make much of a difference anyhow. But, it could
      always save the before and after sizes then add the difference onto
      the total bytes. But, I don't think it needs that level of detail.
      After all, we probable rounded it to the nearest KB or MB anyway. Also,
      there are excluded from Total new and modified file counts as well. }

    uses PkgComn, QNLS, QDOS, QStrings, QFiles, QPkgLSM;

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

        PDirMap = ^TDirMap;
        TDirMap = record
            Path : String;
            Name : String;
            Next : PDirMap;
        end;

    const
        InitScan : boolean = False;     { After options processed either      }
        PostScan : boolean = False;     { InitScan or PostScan will be true.  }
                                        { But Not BOTH ! }
        DoneScan : boolean = False;     { Kill temp file when done }
        DataFile : PABstractFile = nil; { Temp data file name }
        LSMFile  : PABstractFile = nil;
        LSTFile  : PABstractFile = nil;
        MODFile  : PABstractFile = nil;
        TMPFile  : PABstractFile = nil;
        TMPDir   : String = '';
        ScanDrives : String = '';
        ScanMulti : boolean = false;
        ToDo     : PToDo = nil;
        TotalFiles : LongInt = 0;
        TotalDirs  : LongInt = 0;
        TotalBytes : LongInt = 0;
        NewFiles : LongInt = 0;
        NewDirs  : LongInt = 0;
        NewBytes : LongInt = 0;
        ModFiles : LongInt = 0;
        DataStart : LongInt = 0;

        Verbose : boolean = true;

        OptIncDrvs : String = '';
        OptKeepScan : boolean = false;
        OptMetaOnly : boolean = false;
        OptForced   : boolean = false;
        OptPkgAdd   : String = '';
        OptPkgDel   : String = '';
        OptZipIt    : boolean = false;
        LSMFileName : String = '';
        LSTFileName : String = '';
        MODFileName : String = '';
        LSMAppend   : boolean = false;
        LSTAppend   : boolean = false;
        MODAppend   : boolean = false;
        ZIPexe      : String = '';
        ZipOpts     : String = '-r -9 -S';
        PkgSettings : String = 'FDNPKG.CFG';
        DirMap      : PDirMap = nil;

    const
        NewLSM : array[1..18] of String =(
        'Begin3',
        'Title:          The $NAME$ package',
        'Version:        unknown',
        'Entered-date:   $TODAY$',
        'Description:    less than 80 characters',
        'Summary:        really long summary of package',
        'Changes:        if it is new, whats changed?',
        'Keywords:       dos',
        'Author:         ',
        'Maintained-by:  ',
        'Primary-site:   ',
        'Alternate-site: ',
        'Original-site:  ',
        'Wiki-site:      ',
        'Mirror-site:    ',
        'Platforms:      DOS',
        'Copying-policy: unknown',
        'End'
        );
        DefaultMap : array [1..21] of record
            Name : String[8];
            Path : String[32];
        end = (
            (Name:'ARCHIVER'; Path:'C:\ARCHIVER'),
            (Name:'BOOT'; Path:'C:\BOOT'),
            (Name:'DEVEL'; Path:'C:\DEVEL'),
            (Name:'DRIVERS'; Path:'%DOSDIR%\DRIVER'),
            (Name:'DRIVERS'; Path:'%DOSDIR%\DRIVERS'),
            (Name:'DRIVERS'; Path:'C:\DRIVER'),
            (Name:'DRIVERS'; Path:'C:\DRIVERS'),
            (Name:'EDIT'; Path:'C:\EDIT'),
            (Name:'EMULATOR'; Path:'C:\EMULATOR'),
            (Name:'GAMES'; Path:'C:\GAMES'),
            (Name:'GUI'; Path:'C:\GUI'),
            (Name:'LINKS'; Path:'%DOSDIR%\LINKS'),
            (Name:'NETWORK'; Path:'C:\NET'),
            (Name:'NETWORK'; Path:'C:\NETWORK'),
            (Name:'NETWORK'; Path:'%DOSDIR%\NETWORK'),
            (Name:'SOUND'; Path:'C:\SOUND'),
            (Name:'SOURCE'; Path:'%DOSDIR%\SOURCE'),
            (Name:'PROGS'; Path:'C:\'),
            (Name:'UNIX'; Path:'C:\UNIX'),
            (Name:'APPS'; Path:'C:\APPS'),
            (Name:'UTIL'; Path:'C:\UTIL')
        );


    procedure ProgramMessages; assembler;
    asm
        db 'LANGUAGE=Built-in',0
        db 'PROG.NAME=PkgMaker',0
        db 'PROG.VERSION=Version $',0
        db 'PROG.TITLE=PkgMaker',0
        db 'PROG.DESC=Package Creation Utility',0
        db 'PROG.ABORT=aborted',0
        db 'MEM.USAGE=Memory Usage',0
        db 'ERROR=Error ($)',0
        db 'ERROR.NUMBER=#$',0
        db 'ERROR.2=file not found',0
        db 'ERROR.3=path not found',0
        db 'ERROR.9=out of memory',0

        db 'ERROR.DEFCFG=assuming default settings',0
        db 'ERROR.BADOPT=invalid switch $',0
        db 'ERROR.NOTEMP=TEMP environment variable not set',0
        db 'ERROR.BADDRV=can not find drive $, ignored',0
        db 'ERROR.LOWMEM=extremely low on free memory',0
        db 'ERROR.LONGLN=Error: Line #$ is too long',0
        db 'ERROR.ISULFN=probably LFN',0

        db 'ERROR.NOPKG=package id/name not specified',0
        db 'ERROR.BADNAME=cannot use $ for package id/name',0
        db 'ERROR.EXISTS=package $ metadata already exists',0
        db 'ERROR.NOINC=can only include drives on the initial scan',0
        db 'ERROR.NOLST=package $ file list not found',0
        db 'ERROR.BADLSM=package $ metadata file needs edited',0
        db 'ERROR.NOZIP=zip program not found',0

        db 'FORCED=forced to continue',0
        db 'FILE.APPEND=appending original $',0
        db 'FILE.KEEP=keeping original $',0
        db 'FILE.PRUNE=pruning original $',0

        db 'HELP.0=no built-in help available',0
        db 'USAGE=Disk Usage',0
        db 'FILE=$ file',0
        db 'FILES=$ files',0
        db 'BYTE=$ byte',0
        db 'BYTES=$ bytes',0
        db 'KBYTE=$KB',0
        db 'MBYTE=$MB',0
        db 'GBYTE=$GB',0
        db 'OVERBYTE=>$GB',0

        db 'SCAN.INIT=Perform initial scan',0
        db 'SCAN.POST=Perform secondary scan',0
        db 'SCAN.WAIT=This can take a while',0
        db 'SCAN.MISSING=Initial scan not found',0
        db 'SCAN.RUN=Scanning...',0
        db 'SCAN.DRIVE=Scanning $ ...',0
        db 'SCAN.DONE=Scan complete',0
        db 'SCAN.DONE.FAST=Or, not. Wow, that was quick. Done!',0

        db 'FILE.DEL=file $ deleted',0
        db 'STATS.NOW=found $0 directories, $1 files, $2',0
        db 'STATS.NEW=found $1 new files and $2',0
        db 'STATS.MOD=found $0 modified files, see $1',0
        db 'STATS.DETACH=detached $ files',0

        db 'META.MADE=package $ metadata created',0
        db 'META.UPDATE=package $ metadata updated',0

        db 'MODE.ADD=Add files to $ package',0
        db 'MODE.DETACH=Detach files from $ package',0
        db 'MODE.ZIP=Create zip archive of package $',0

        db 'PKG.ADD=add: $',0
        db 'PKG.DETACH=detach: $',0

        db 'IDX.NEW.FILE=New: $',0
        db 'IDX.NEW.DIR=New: $\',0
        db 'IDX.MOD.FILE=Changed: $',0
        db 'IDX.MOD.DIR=Changed: $\',0

        db 'PAUSED=press a key to continue...',0
        db 'SUPPORT=Help support continued development of $ by becoming a Patron.'
        db 13,10
        db 'https://patreon.com/shidel',0
        db 0
    end;

    procedure UserTerminate; far;
    begin
    	if OptZipIt then exit;
        if InitScan then begin
            if Assigned(DataFile) and FileExists(DataFile^.Name) then begin
                DataFile^.Close;
                DataFile^.Erase;
                WriteLn('');
                Write(NLSstr('FILE.DEL', Datafile^.Name));
            end;
        end else begin
            if Assigned(LSMFile) then begin
                LSMFile^.Close;
                if not LSMAppend then begin
                    LSMFile^.Erase;
                    WriteLn('');
                    Write(NLSstr('FILE.DEL', LSMFile^.Name));
                end;
            end;
            if Assigned(LSTFile) then begin
                LSTFile^.Close;
                if not (LSTAppend) then begin
                    LSTFile^.Erase;
                    WriteLn('');
                    Write(NLSstr('FILE.DEL', LSTFile^.Name));
                end;
            end;
            if Assigned(MODFile) then begin
                MODFile^.Close;
                if not MODAppend then begin
                    MODFile^.Erase;
                    WriteLn('');
                    Write(NLSstr('FILE.DEL', MODFile^.Name));
                end;
            end;
        end;
        if Assigned(TMPFile) then begin
            TMPFile^.Close;
            TMPFile^.Erase;
            WriteLn('');
            Write(NLSstr('FILE.DEL', TMPFile^.Name));
        end;
    end;

    procedure CheckFileError(F : PAbstractFile);
    var
        R : integer;
    begin
        if Assigned(F) then begin
            R := F^.IOResult;
            if R <> 0 then begin
                WriteLn('');
                WriteLn(ErrorMsg(R, F^.Name));
                F^.Close; { We will probably close it twice. Don't matter! }
                UserTerminate;
                Halt(R);
            end;
        end;
    end;

    procedure CheckDataFileError;
    begin
        CheckFileError(DataFile);
    end;

    procedure CleanUp(ShowMsg : boolean);
    var
        F : File;
    begin
    	if OptZipIt then exit;
        if Not Assigned(DataFile) then exit;
        DataFile^.Erase;
        if ShowMsg then begin
            WriteLn('');
            Write(NLSstr('FILE.DEL', Datafile^.Name));
        end;
    end;

    function NoScan : boolean;
    begin
        NoScan := OptZipIt or OptMetaOnly or (OptPkgAdd <> '') or (OptPkgDel <> '');
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
    const
        LowWarn : boolean = false;
    var
        P : PToDo;
    begin
        if MaxAvail < 20480 then begin
            if MaxAvail < 5120 then begin
                TumblerDone;
                WriteLn('');
                UserTerminate;
                WriteLn('');
                WriteHalt(ErrorMsg(9,''),9);
            end else if not LowWarn then begin
                TumblerDone;
                WriteLn('');
                Write(NLSstr('ERROR.LOWMEM', IntStr(MaxAvail)) + ' ');
                LowWarn := true;
            end
        end else if MaxAvail > 30720 then
            LowWarn := false;
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

    procedure AddToLST(FileName : String; CanIncSelf : boolean);
    begin
        if (not CanIncSelf) and (UCase(FileName) = UCase(LSTFileName)) then begin
            Exit;
        end;
        if not Assigned(LSTFile) then begin
            if LSTAppend then begin
                TumblerDone;
                { if not NoScan then }
                WriteLn('');
                Write(NLSstr('FILE.APPEND', LSTFileName) + ' ');
            end;
            LSTFile :=New(PDiskFile, Create(nil));
            LSTFile^.Assign(LSTFileName);
            if LSTAppend then
                LSTFile^.Reset
            else
                LSTFile^.Rewrite;
            CheckFileError(LSTFile);
            LSTFile^.SeekEOF;
            CheckFileError(LSTFile);
        end;
        LSTFile^.WriteLn(FileName);
        CheckFileError(LSTFile);
    end;

    procedure AddToMOD(FileName : String);
    begin
        if not Assigned(MODFile) then begin
            if MODAppend then begin
                TumblerDone;
                WriteLn('');
                Write(NLSstr('FILE.APPEND', MODFileName)+ ' ');
            end else
                AddToLST(MODFileName, False);
            MODFile :=New(PDiskFile, Create(nil));
            MODFile^.Assign(MODFileName);
            if MODAppend then
                MODFile^.Reset
            else
                MODFile^.Rewrite;
            CheckFileError(MODFile);
            MODFile^.SeekEOF;
            CheckFileError(MODFile);
        end;
        MODFile^.WriteLn(FileName);
        CheckFileError(MODFile);
    end;

    procedure AddToDirMap(AName, APath : String);
    var
        DM : PDirMap;
    begin
        DM := New(PDirMap);
        DM^.Next := DirMap;
        DM^.Path := TailDelim(APath);
        DM^.Name := NoTailDelim(AName);
        DirMap := DM;
        { WriteLn('MAP: ', APath, ' -> ', AName); }
    end;

    procedure CreateLSM;
    var
        I : integer;
        S, Today : String;
        Year, Month, Day, DayOfWeek: Word;
    begin
        if LSMAppend then begin
            if not OptMetaOnly then WriteLn('');
            Write(NLSstr('FILE.KEEP', LSMFileName));
            if OptMetaOnly then WriteLn('');
            Exit;
        end;
        AddToLST(LSMFileName, False);
        { WriteLn(''); }
        if Not Assigned(LSMFile) then begin
            LSMFile :=New(PDiskFile, Create(nil));
            LSMFile^.Assign(LSMFileName);
            LSMFile^.Rewrite;
            CheckFileError(LSMFile);
            GetDate(Year, Month, Day, DayOfWeek);
            Today := ZPad(IntStr(Year), 4) + '-' + ZPad(IntStr(Month), 2)
                + '-' + ZPad(IntStr(Day), 2);
            for I := Low(NewLSM) to High(NewLSM) do begin
                S := ReplaceStr(NewLSM[I], '$NAME$', PkgWildCard, true);
                S := ReplaceStr(S, '$TODAY$', Today, true);
                { WriteLn(S); }
                LSMFile^.WriteLn(S);
                CheckFileError(LSMFile);
            end;
            LSMFile^.Close;
        end
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
            {if (NewFiles <> 0) or (NewDirs <> 0) then}
            WriteLn('');
            XE := ElapsedTicks(true);
            if XE = 0 then
                XF := 0
            else
                XF := ((TotalFiles + TotalDirs) div XE) * 18;
            { Write('(', ElapsedTicks(False), '/', XE, '/', XF, ') '); }
            if XE < 90 then
                Write(NLS('SCAN.DONE.FAST'))
            else
                Write(NLS('SCAN.DONE'));
        end;
        WriteLn('');
        if New then begin
            S := NLS('STATS.NEW');
            S := ReplaceStr(S, '$0', IntStr(NewDirs), True);
            S := ReplaceStr(S, '$1', IntStr(NewFiles), True);
            if TotalBytes >= 0 then
                S := ReplaceStr(S, '$2', SizeStr(NewBytes, True), True)
            else
                S := ReplaceStr(S, '$2', NLSStr('OVERBYTE', '2'), True);
        end else begin
            S := NLS('STATS.NOW');
            S := ReplaceStr(S, '$0', IntStr(TotalDirs), True);
            S := ReplaceStr(S, '$1', IntStr(TotalFiles), True);
            if TotalBytes >= 0 then
                S := ReplaceStr(S, '$2', SizeStr(TotalBytes, True), True)
            else
                S := ReplaceStr(S, '$2', NLSStr('OVERBYTE', '2'), True);
            if ModFiles > 0 then begin
                WriteLn(S);
                S := NLS('STATS.MOD');
                S := ReplaceStr(S, '$0', IntStr(ModFiles), True);
                S := ReplaceStr(S, '$1', MODFileName, True);
            end;
        end;
        Write(S);
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
            { WriteLn(D,I.NAME);
            Halt(0); }
            if (I.Attr and faDirectory = faDirectory) then begin
                {AddToLST(D + I.Name);}
                Inc(NewDirs)
            end else begin
                Inc(NewFiles);
                if NewBytes >= 0 then
                    Inc(NewBytes, I.Size);
                AddToLST(D + I.Name, False);
            end;
            if Verbose then begin
                TumblerDone;
                WriteLn('');
                Write(NLSstr('IDX.NEW.' +
                    WhichStr(I.Attr and faDirectory = faDirectory, 'FILE', 'DIR'),
                    D + I.Name) + ' ');
            end;

        end else if (I.Attr and faDirectory = faDirectory) and
        (I.Attr and faDirectory = faDirectory) then begin
            { I think we can just ignore modified DIR items }
            { if (I.Time <> O.Time) or (I.Attr <> O.Attr) then begin
                  TumblerDone;
                  WriteLn('');
                  Write(NLSstr('IDX.MOD.DIR', D + I.Name), ' ');
            end; }

        end else if (I.Time <> O.Time) or (I.Attr <> O.Attr) or
        (I.Size <> O.Size) then begin
            Inc(MODFiles);
            AddToMOD(D + I.Name);
            if Verbose then begin
                  TumblerDone;
                  WriteLn('');
                  Write(NLSstr('IDX.MOD.FILE', D + I.Name) + ' ');
            end;
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
        ElapsedTicks(true);
        IPath := TailDelim(PathOf(DataFile^.Name));
        IName := Copy(DataFile^.Name, Length(IPath) + 1, Sizeof(TFileNameString));
        while Assigned(ToDo) do begin
            TestBreak;

            P := ToDo;
            ToDo := P^.Next;
            D := PtrStr(P^.Path);
            If InitScan then UpdateDirItem(P^.Data, D, P^.Time, P^.Attr);
            FreeStr(P^.Path);
            Dispose(P);

            if {ScanMulti and} (Length(D) < 4) then begin
                TumblerDone;
                WriteLn('');
                Write(NLSstr('SCAN.DRIVE', D {Copy(D, 1,2)}) + ' ');
            end;

            Tumbler;

            FindFirst( D + '*.*', faAnyFile, S);

            { WriteLn(Space(CountStr(PathDelim, D) * 2), BaseNameOf(NoTailDelim(D))); }
            if (DOSError <> 0) then begin
                TumblerDone;
                WriteLn('');
                if (Length(D) < 4) then
                    Write(NLSstr('ERROR.' + ErrBadDrv, D))
                else if DOSError = 18 then
                    Write(ErrorTxt(ErrIsULFN, D))
                else
                    Write(ErrorMsg(DOSERROR, D));
                Write(' ');
            end;

            {
            if MaxAvail < 20480 then begin
                TumblerDone;
                WriteLn('');
                Write (MaxAvail, ',', MemAvail, ' > ', D);
            end;
            }

            while DOSError = 0 do begin
                TestBreak;
                if S.Attr and faDirectory = faDirectory then begin
                    if (S.Name <> '.') and (S.Name <> '..') then begin
                        AddToDo(D + S.Name + PathDelim, S.Time, S.Attr);
                        if PostScan then CompareScan(D, S);
                    end;
                end else if (IName <> S.Name) or (IPath <> D) then begin
                    Inc(TotalFiles);
                    if TotalBytes >= 0 then
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
            FindClose(S);
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

    procedure AddList(var List : PToDo; S : String);
    var
        P : PToDo;
    begin
        P := New(PToDo);
        P^.Path := StrPtr(S);
        P^.Next := List;
        List := P;
    end;

    procedure AddFiles;
    var
        S, D, F, T, Pkgs : String;
        List, P : PTodo;
        SR : TSearchRec;
    begin
        Write(NLSstr('MODE.ADD',PkgWildCard));
        T := NLS('PKG.ADD');
        Pkgs := OptPkgAdd;
        While Pkgs <> '' do begin
            S := Trim(PullStr( '|', Pkgs));
            if S = '' then continue;
            S := FileExpand(S);
            D := PathOf(S);
            F := Copy(S, Length(D) + 1, Length(S));
            if D = '' then begin D := F; F := ''; end;
            D := TailDelim(D);
            if F = '' then F := '*';
            { WriteLn(S, ' > ', D, ' + ', F); }
            List := nil;
            AddList(List, D);
            { WriteLn(''); }
            while Assigned(List) do begin
                P := List;
                List := P^.Next;
                TestBreak;
                FindFirst(PtrStr(P^.Path) + '*.*', faAnyfile, SR);
                while DOSError = 0 do begin
                    TestBreak;
                    if (SR.Attr and faVolumeID = faVolumeID) or
                    ((SR.Attr and faDirectory = faDirectory) and ((SR.Name = '.') or (SR.Name = '..'))) then  begin
                        { ignore it }
                    end else
                    if MatchWildCard(F, UCase(SR.Name)) then begin
                        if SR.Attr and faDirectory = faDirectory then begin
                            AddList(List, TailDelim(PtrStr(P^.Path)+SR.Name));
                            Inc(NewDirs);
                        end else begin
                            Inc(NewFiles);
                            if NewBytes >= 0then
                                Inc(NewBytes, SR.Size);
                            AddToLST(PtrStr(P^.Path)+SR.Name, True);
                            if Verbose then begin
                                WriteLn('');
                                Write(ReplaceStr(T, '$', PtrStr(P^.Path)+SR.Name, false));
                            end;
                        end;
                    end;
                    FindNext(SR);
                end;
                FindClose(SR);
                FreeStr(P^.Path);
                Dispose(P);
                F := '*'; { Sub dirs match all files/directories }
            end;
        end;
        ScanStats(True);
    end;

    procedure DelFiles;
    var
        S, W, DS, Pkgs : String;
        L, X:integer;
        LenOK, Detach : boolean;
    begin
        DS := NLS('PKG.DETACH');
        Write(NLSstr('MODE.DETACH',PkgWildCard));
        if not Assigned(LSTFile) then begin
            LSTFile :=New(PDiskFile, Create(nil));
            LSTFile^.Assign(LSTFileName);
            LSTFile^.Reset;
            CheckFileError(LSTFile);
            WriteLn('');
            Write(NLSstr('FILE.PRUNE', LSTFileName) + ' ');
        end else
            LSTAppend := True;
        LSTFile^.SeekSOF;
        CheckFileError(LSTFile);
        TMPFile :=New(PDiskFile, Create(nil));
        TMPFile^.Assign(PathOf(LSTFileName) + BaseNameOf(LSTFileName) + '.TMP');
        TMPFile^.Rewrite;
        CheckFileError(TMPFile);
        X := 0;
        L := 1;
        while not LSTFile^.EOF do begin
            TestBreak;
            LenOK := LSTFile^.ReadLn(S, Sizeof(S) - 1);
            CheckFileError(LSTFile);
            if not LenOk then begin
                WriteLn(NLSstr('ERROR.LONGLN', IntStr(L)));
                if not OptForced then begin
                    UserTerminate;
                    WriteHalt(NLS('PROG.ABORT'), 1);
                end;
            end;
            S := UCase(Trim(S));
            if S = '' then Continue;
            Inc(L);
            Pkgs := Ucase(OptPkgDel);
            Detach := false;
            While Pkgs <> '' do begin
                W := Trim(PullStr( '|', Pkgs));
                if W = '' then continue;
                if MatchWildCard(W, S) then begin
                    Detach := True;
                    Break;
                end;
            end;
            if Detach then begin
                WriteLn('');
                Write(ReplaceStr(DS, '$', S, false));
            end else begin
                TMPFile^.WriteLn(S);
                CheckFileError(TMPFile);
            end;
        end;
        TMPFile^.Close;
        CheckFileError(TMPFile);
        LSTFile^.Close;
        CheckFileError(LSTFile);
        LSTFile^.Rename(PathOf(LSTFileName) + BaseNameOf(LSTFileName) + '.BAK');
        CheckFileError(LSTFile);
        TMPFile^.Rename(LSTFileName);
        CheckFileError(TMPFile);
        LSTFile^.Erase;
        Dispose(LSTFile, Destroy);
        LSTFile := nil;
        Dispose(TMPFile, Destroy);
        TMPFile := nil;
    end;

    procedure PrepareFileNames;
    begin
        if PostScan or NoScan then begin
            if PkgWildCard = '*' then WriteHalt(NLS('ERROR.NOPKG'),1);
            if not ValidPkgName(PkgWildCard) then
                WriteHalt(NLSstr('ERROR.BADNAME', PkgWildCard),1);
        end;
        if (PkgWildCard <> '*') then begin
             LSMFileName := TailDelim(GetENV('DOSDIR')) + 'APPINFO' + PathDelim +
                PkgWildCard + FileExtLSM;
             LSTFileName := TailDelim(GetENV('DOSDIR')) + 'PACKAGES' + PathDelim +
                PkgWildCard + FileExtLST;
             MODFileName := TailDelim(GetENV('DOSDIR')) + 'PACKAGES' + PathDelim +
                PkgWildCard + '.MOD';
            LSMAppend := FileExists(LSMFileName);
            LSTAppend := FileExists(LSTFileName);
            MODAppend := FileExists(MODFileName);
            if ((OptPkgAdd <> '') or (OptPkgDel <> '') or OptZipIt) then begin
                if not LSTAppend then begin
                    WriteLn(NLSstr('ERROR.NOLST', PkgWildCard));
                    if OptForced then
                        WriteLn(NLSstr('FORCED', SwitchChar))
                    else
                        Halt(5);
                end;
            end else if FileExists(LSMFileName) or FileExists(LSTFileName) or
            FileExists(MODFileName) then begin
                WriteLn(NLSstr('ERROR.EXISTS', PkgWildCard));
                if PostScan or OptMetaOnly then begin
                    if FileExists(LSMFileName) then begin
                        WriteLn(ErrorMsg(5, LSMFileName));
                    end;
                    if FileExists(LSTFileName) then begin
                        WriteLn(ErrorMsg(5, LSTFileName));
                    end;
                    if FileExists(MODFileName) then begin
                        WriteLn(ErrorMsg(5, MODFileName));
                    end;
                    if OptForced then
                        WriteLn(NLSstr('FORCED', SwitchChar))
                    else
                        Halt(5);
                end;
            end;
        end;
    end;

    procedure LocateZip;
    begin
        ZIPexe := SearchPathSpec('ZIP.EXE');
        if ZIPexe = '' then WriteHalt(NLS('ERROR.NOZIP'), 2);
    end;

    function CopyProgress(APercent : integer) : boolean; far;
    begin
        CopyProgress := true;
        if (not IsOutCON) then begin
            if (APercent = 100) then Write('100%');
            Exit;
        end;
        System.Write(ChrStr(#8, 4) + LSpace(IntStr(APercent), 3)+ '%');
    end;

    function GetPkgSettings : boolean;
    var
        FN, S, T : String;
        LenOK, Save : boolean;
        FM, L : word;
        P : PDirMap;
        I : integer;
    begin
        Save := False;
        FN := GetENV( GetEXEBase + '.CFG' );
        if FN = '' then begin
            FN := GetENV('DOSDIR');
            if FN <> '' then
                FN := TailDelim(FN) + 'BIN' + PathDelim + GetEXEBase + '.CFG'
            else
                WriteHalt(ErrorMsg(3, '%DOSDIR%'), 3);
        end;
        if Not FileExists(FN) then
            FN := TailDelim(GetEXEPath) + GetEXEBase + '.CFG';
        if Not FileExists(FN) then begin
            Save := True;
            FN := GetENV(PkgSettings);
            if FN = '' then begin
                FN := GetENV('DOSDIR');
                if FN <> '' then
                    FN := TailDelim(FN) + 'BIN' + PathDelim + PkgSettings
                else
                    WriteHalt(ErrorMsg(3, '%DOSDIR%'), 3);
            end;
        end;
        FM := FileMode;
        GetPkgSettings := false;
        if not FileExists(FN) then begin
            WriteLn(ErrorMsg(2, FN));
            WriteLn(NLS('ERROR.DEFCFG'));
            Save := True;
        end;
        FileMode := 0;
        MODFile := new(PDiskFile, Create(nil));
        MODFile^.Assign(FN);
        L := 0;
        MODFile^.Reset;
        if MODFile^.Result = 0 then begin
            while (not MODFile^.EOF) do begin
                LenOk := MODFile^.ReadLn(S, Sizeof(S) -1);
                if MODFile^.Result <> 0 then Break;
                Inc(L);
                if Not LenOK then begin
                    WriteLn(NLSStr('ERROR.LONGLN', IntStr(L)));
                    Continue;
                end;
                T := PullWord(S);
                if (UCase(T) <> 'DIR') then Continue;
                T := UCase(PullWord(S));
                S := ENVExpand(S);
                AddToDirMap(T, S);
            end;
        end else
            for I := Low(DefaultMap) to High(DefaultMap) do
                AddToDirMap(DefaultMap[I].Name, ENVExpand(DefaultMap[I].Path));
        AddToDirMap('BIN', ENVExpand('%DOSDIR%\BIN'));
        AddToDirMap('', ENVExpand('%DOSDIR%'));
        if Save then begin
          MODFile^.Close;

          FN := TailDelim(GetEXEPath) + GetEXEBase + '.CFG';
          MODFile^.Assign(FN);
          MODFile^.Rewrite;
          P := DirMap;
          While Assigned(P) do begin
            S := 'dir ' + RSpace(P^.NAME, 12) + ' ' + P^.Path;
            MODFile^.WriteLn(S);
            P := P^.Next;
          end;
        end;

        GetPkgSettings := (MODFile^.Result = 0);

        MODFile^.Close;
        Dispose(MODFile, Destroy);
        FileMode := FM;
    end;

    function ReMapFile(APath : String) : String;
    var
        P : PDirMap;
        S, X, T : String;
        TL, SL : integer;
    begin
        S := '';
        X := UCase(APath);
        P := DirMap;
        TL := 0;
        SL := 0;
        While Assigned(P) do begin
            TL := Length(P^.Path);
            if (Copy(X, 1, TL) = UCase(P^.Path)) then begin
                T := P^.Name + Copy(X, TL, Length(X));
                while (T<>'') and (T[1] = PathDelim) do
                    Delete(T, 1,1);
                T := TailDelim(TMPDir + PkgWildCard + '.PKG') + T;
                if (TL > SL) or (SL = 0) or ((TL = SL) and (UCase(T) < UCase(S))) then begin
                   {  WriteLn(T, ' ? ', S); }
                    S := T;
                    SL := TL;
                end
            end;
            P := P^.Next;
        end;
        if S <> '' then begin
            ReMapFile := S;
        end else if (Copy(APath, 2,2) = ':' + PathDelim) and
            (Copy(GetENV('DOSDIR'), 1,3) <> Copy(APath, 1,3)) then
            ReMapFile := ReMapFile(Copy(GetENV('DOSDIR'), 1,3) + Copy(APath, 4,Length(APath)))
        else
            ReMapFile := 'FAILED';
    end;

{$IFDEF ZIPIT}
    {$I-}
    procedure ZipPackage;
    var
        L : word;
        Ret, E : Integer;
        S, DF : String;
        LenOk : boolean;
        CDir, ZDir : String;
    begin
        LocateZip;
        GetPkgSettings;
        PrepareFileNames;
        WriteLn(NLSstr('MODE.ZIP', PkgWildCard));
        if not Assigned(LSTFile) then begin
            LSTFile := New(PDiskFile, Create(nil));
            LSTFile^.Assign(LSTFileName);
            if LSTAppend then
                LSTFile^.Reset
            else
                LSTFile^.Rewrite;
            CheckFileError(LSTFile);
        end;
        if DirExists(ReMapFile(TailDelim(GetEnv('DOSDIR')))) then begin
            WriteLn(ErrorMsg(5, ReMapFile(TailDelim(GetEnv('DOSDIR')))));
            if not OptForced then begin
                UserTerminate;
                WriteHalt(NLS('PROG.ABORT'), 1);
            end;
        end;
        L := 0;
        LSTFile^.SeekSOF;
        CheckFileError(LSTFile);
        while not LSTFile^.EOF do begin
            Inc(L);
            LenOk := LSTFile^.ReadLn(S, Sizeof(S) -1);
            if not LenOk then begin
                WriteLn(NLSstr('ERROR.LONGLN', IntStr(L)));
                if not OptForced then begin
                    UserTerminate;
                    WriteHalt(NLS('PROG.ABORT'), 1);
                end;
            end;
            S := Trim(S);
            if S = '' then Continue;
            DF := ReMapFile(S);
            if MakeDir(PathOf(DF)) <> 0 then begin
                WriteLn(ErrorMsg(DOSERROR, PathOf(DF)));
                UserTerminate;
                WriteHalt(NLS('PROG.ABORT'), 1);
            end;
            if not FileExists(S) then begin
                WriteLn(ErrorMsg(2, S));
                if not OptForced then begin
                    UserTerminate;
                    WriteHalt(NLS('PROG.ABORT'), 1);
                end;
                Continue;
            end;
{            Write(S, ' -> ', DF); }
            Write(S);
            if IsOutCON then Write(Space(5));
            Ret := CopyFile(S, DF, nil, 65535, CopyProgress);
            if Ret <> 0 then begin
                WriteLn('');
                WriteLn(ErrorMsg(RET, DF));
                UserTerminate;
                WriteHalt(NLS('PROG.ABORT'), 1);
            end;
            if IsOutCON then System.Write(ChrStr(#8, 5) + Space(5) + ChrStr(#8, 5));
            WriteLn('');
        end;

        GetDir(0, CDir);
        ChDir(Copy(TMPDir,1,2));
        Ret := IOResult;
        GetDir(0, ZDir);
        if Ret = 0 then begin
            ChDir(TailDelim(TMPDir) + PkgWildCard + '.PKG');
            Ret := IOResult;
            { MemStat; }
            if Ret <> 0 then begin
                WriteLn(ErrorMsg(Ret, TailDelim(TMPDir) + PkgWildCard + '.PKG'));
            end else begin
                if Copy(CDir, 1, 2) = Copy(ZDir, 1, 2) then
                    S := TailDelim(CDir)
                else
                    S := Copy(CDir, 1, 2);
                DOSError := 0;
                S := ' ' + ZipOpts + ' ' + S + PkgWildCard + '.zip . -i *.*';
                { WriteLn('');
                WriteLn(ZIPexe + ' ' + S); }
                SwapIntVecs;
                {Exec('C:\D.EXE', '');}
                Exec(ZIPexe, S);
                Ret := DOSError;
                SwapIntVecs;
            end;

            ChDir(ZDir);
            E := IOResult;
            ChDir(CDir);
            E := IOResult;
        end;

        if Ret <> 0 then
            WriteLn(ErrorMsg(Ret, Copy(TMPDir,1,2)));

        UserTerminate;
        if not DeleteDir(ReMapFile(TailDelim(GetEnv('DOSDIR'))), True) then begin
            WriteLn(ErrorMsg(DOSError, ReMapFile(TailDelim(GetEnv('DOSDIR')))));
            Halt(1);
        end;
    end;
    {$I+}
{$ELSE}
    procedure ZipPackage;
    var
    	S : String;
	begin
		S := NLS('NO.ZIP');
		if S = '' then S := 'Package zipping not available for compatibilty reasons, use pkgzipit.bat';
		WriteLn(S);
	end;
{$ENDIF}


    procedure PerformScan;
    var
        R : integer;
        S : String;
    begin
        if not NoScan then begin
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
        end;
        PrepareFileNames;
        if not NoScan then begin
            Write(NLS('SCAN.WAIT'));
            ScanDrives := FlipStr(ScanDrives);
            ScanMulti := Length(ScanDrives) > 1;
            while Length(ScanDrives) > 0 do begin
                AddToDo(ScanDrives[1] + DriveDelim + PathDelim, 0, $ff);
                Delete(ScanDrives, 1,1);
            end;
            Scan;
            DataFile^.Close;
            CheckDataFileError;
        end;
        if OptPkgAdd <> '' then AddFiles;
        if OptPkgDel <> '' then begin
            if OptPkgAdd <> '' then WriteLn('');
            DelFiles;
        end;

        if PostScan or NoScan then begin
            if PostScan or OptMetaOnly then CreateLSM;
            if Assigned(LSTFile) then LSTFile^.Close;
            if Assigned(MODFile) then MODFile^.Close;
            if LSMAppend or LSTAppend or MODAppend then begin
                if not OptMetaOnly then  WriteLn('');
                WriteLn(NLSstr('META.UPDATE', PkgWildCard));
            end else begin
                if not OptMetaOnly then WriteLn('');
                WriteLn(NLSstr('META.MADE', PkgWildCard));
            end;
        end else
            WriteLn('');
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
            if S = '' then WriteHalt(NLS('ERROR.' + ErrNoTemp),3);
            TMPDir := TailDelim(S);
            S := TailDelim(S) + GetEXEBase + '.TMP';
            DataFile^.Assign(S);
        end;

        if not DirExists(PathOf(DataFile^.Name)) then
            WriteHalt(ErrorMsg(3, PathOf(DataFile^.Name)) , 3);

        { Scan type not specified, autodetect}
        if (InitScan or PostScan) and (not OptZipIt) = False then begin
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
        if OptZipIt then
            ZipPackage
        else
            PerformScan;
        if DoneScan then CleanUp(False);
    end;

    function Options(Option : String; var NextParam : Integer) : boolean; far;
    begin
        Options := True;
        if Option = 'Z' then begin
            OptZipIt := True;
        end else if Option = 'I' then begin
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
            OptMetaOnly := True;
        end else if Option = 'F' then begin
            OptForced := True;
        end else if Option = 'D' then begin
            OptIncDrvs := OptIncDrvs + ParamStr(NextParam);
            Inc(NextParam);
        end else if Option = 'A' then begin
            OptPkgAdd := OptPkgAdd + '|' + ParamStr(NextParam);
            Inc(NextParam);
        end else if Option = 'R' then begin
            OptPkgDel := OptPkgDel + '|' + ParamStr(NextParam);
            Inc(NextParam);
        end else
            Options := False;
    end;

begin
    CleanUpProc := UserTerminate;
    ScanDrives := 'C';
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('');
    DataFile := New(PDiskFile, Create(nil));
    ParseCommandLine(Options);
    PerformTask;
end.

