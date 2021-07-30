{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}

{$M 32678,102400,655360}
{$S+}
{ DEFINE FAKELOST}
program Package_Info;

uses PkgComn, QDOS, QClass, QStrings, QNLS, QPkgLSM, QAsciiZ, QFiles;

const
    ListDetails : String = '*title;*version;*copying;description';
    ListMore : String = '*title;*version;entered;' +
        'description;summary;changes;keywords;author;maintained;' +
        'primary;alternate;wiki;mirror;*copying';
    ListMode : integer = 1;

    Execuatable : String = ';EXE;COM;BAT;';
    PrefixLSM : Str4 = 'LSM.';

    DetailLevel : integer = 0;
    MetaFieldWidth : word = 0;
    PkgShown : integer = 0;
    PkgTesting : boolean = false;
    TotalFiles : longint = 0;
    TotalMissing : longint = 0;
    TotalBytes : longint = 0;
    PkgMissing : longint = 0;
    PkgFiles : longint = 0;
    PkgBytes : longint = 0;
    ReportMissing : boolean = false;
    ReportUsage : boolean = false;
    ReportEXEs : boolean = false;
    WildSearch : String = '';
    ListFiles : integer = 0; { 0 = don't; 1 = invisible for Missing & Usage;
                               2 = EXE, COM & BAT; 3 = Everything }

    procedure ProgramMessages; assembler;
    asm
        db 'LANGUAGE=Built-in',0
        db 'PROG.NAME=PkgInfo',0
        db 'PROG.VERSION=Version $',0
        db 'PROG.TITLE=PkgInfo',0
        db 'PROG.DESC=Package Information Utility',0
        db 'PROG.ABORT=aborted',0
        db 'MEM.USAGE=Memory Usage',0
        db 'BAD.SWITCH=invalid switch $',0
        db 'LINE.TOOLONG=Error: Line #$ is too long',0
        db 'ERROR=Error ($)',0
        db 'ERROR.NUMBER=#$',0
        db 'ERROR.2=file not found',0
        db 'ERROR.3=path not found',0
        db 'PKG.INSTALLED=package $ is installed',0
        db 'PKG.NOTFOUND=package $ not found',0
        db 'LST.NOTFOUND=File list for package not found',0

        db 'LSM.TITLE=Title',0
        db 'LSM.ENTERED-DATE=Entered Date',0
        db 'LSM.DESCRIPTION=Description',0
        db 'LSM.VERSION=Version',0
        db 'LSM.SUMMARY=Summary',0
        db 'LSM.CHANGES=What',$27,'s New',0
        db 'LSM.KEYWORDS=Keywords',0
        db 'LSM.AUTHOR=Author',0
        db 'LSM.MAINTAINED-BY=Maintainer',0
        db 'LSM.PLATFORMS=Plaforms',0
        db 'LSM.COPYING-POLICY=Copying Policy',0
        db 'LSM.PRIMARY-SITE=Primary Site',0
        db 'LSM.ALTERNATE-SITE=Alternate Site',0
        db 'LSM.ORIGINAL-SITE=Original Site',0
        db 'LSM.WIKI-SITE=Wiki Site',0
        db 'LSM.MIRROR-SITE=Mirror Site',0
        { Not LSM but used there }
        db 'NA=',0
        db 'ALLFILES=Files',0
        db 'BINARIES=Executables',0
        db 'MISSING.SOME=Missing $0 of $1 file',0
        db 'MISSING.SOMES=Missing $0 of $1 files',0
        db 'MISSING.NONE=No missing files',0
        db 'MISSING.ALL=All files are missing',0
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

    const
        ScreenX : integer = 1;
        ScreenY : integer = 1;

    procedure DoNewLine(NL : boolean);
    begin
        ScreenX := 1;
        Inc(ScreenY);
        if ScreenY > 23 then begin
            ScreenY := 1;
            TestBreakWait;
        end;
        if NL then System.WriteLn;
    end;

    procedure Write(S : String);
    var
        T : String;
        X : integer;
    begin
        if Not PagePause then
            system.Write(S)
        else
        while S <> '' do begin
            T := Copy(S, 1, 80 - ScreenX);
            ScreenX := ScreenX + Length(T);
            Delete(S, 1, Length(T));
            System.Write(T);
            if ScreenX >= 80 then DoNewLine(False);
        end;

    end;

    procedure WriteLn(S : String);
    begin
        if Not PagePause then
            system.WriteLn(S)
        else begin
            Write(S);
            DoNewLine(True);
        end;
    end;

    function SearchMetaData(LSM : PPackageLSM) : boolean;
    begin
        if not Assigned(LSM) then
            SearchMetaData := False
        else if WildSearch = '' then
            SearchMetaData := True
        else
            SearchMetaData:=LSM^.SearchMetaWild(WildSearch);
    end;

    function NumberStr(I : Longint) : String;
    begin
        NumberStr := IntStr(I);
    end;

    function FilesStr(I : Longint) : String;
    begin
        FilesStr := NLSPlural('FILE', IntStr(I), I <> 1);
    end;

    procedure ShowStats(Indent : String; AFiles, AMissing, ABytes:longint);
    begin
        if (AMissing = 0) then begin
            if ReportMissing then
                Write(Indent + NLS('MISSING.NONE'));
        end else if (AFiles = 0) then
            Write(Indent+ NLS('MISSING.ALL'))
        else
            Write(Indent + ReplaceStr(
                ReplaceStr(NLSPlural('MISSING.SOME', '$', AFiles <> 1), '$0', NumberStr(AMissing), True),
                '$1', NumberStr(AFiles + AMissing), True));

        if ReportUsage then begin
            if (AMissing = 0) and (not ReportMissing) then begin
                WriteLn(Indent + FilesStr(AFiles) + ', ' + SizeStr(ABytes, True))
            end else if PkgMissing = 0 then
                WriteLn(', ' + FilesStr(AFiles) + ', ' + SizeStr(ABytes, True))
            else
                WriteLn(', ' + SizeStr(ABytes, True));
        end else if (AMissing <> 0) or (ReportMissing) then WriteLn('');
    end;

    function ListPackageFiles(APkg : String) : integer;
    var
        FL : TDiskFile;
        Size : longint;
        S : String;
        I, MS : integer;
        LenOK, NWLState : boolean;
        Indent : String;
        IndentX : integer;
        function NWL : String;
        begin
            NWL := '';
            if NWLState then WriteLn('');
            NWLState := false;
        end;
    begin
        ListPackageFiles := 0;

        if not FileExists(TailDelim(PackageLSTPath) + APkg + FileExtLST) then begin
            ListPackageFiles := 2;
            exit;
        end;
        if ListMode < 2 then begin
            Indent := Tab;
            IndentX := TabStop;
        end else begin
            Indent := Tab + Tab;
            IndentX := TabStop * 2;
        end;
        PkgMissing := 0;
        PkgFiles := 0;
        PkgBytes := 0;
        NWLState := (ListMode = 0) or (ListMode >= 2); { could just be not 1 }
        FL.Create(nil);
        FL.Assign(TailDelim(PackageLSTPath) + APkg + FileExtLST);
        FL.Reset;
        FL.Seek(0);
        I := 0;
        MS := Length(SizeStr(MaxLongInt, False));
        while (FL.Result = 0) and (not FL.EOF) do begin
            TestBreak;
            LenOK := FL.ReadLn(S, Sizeof(S) - 1);
            S := Trim(S);
            if FL.Result <> 0 then begin
                WriteLn(NWL + Indent + ErrorMsg(FL.Result, TailDelim(PackageLSTPath) + APkg + FileExtLST));
                break;
            end;
            if Trim(S) = '' then Continue;
            Inc(I);
            if Not LenOK then begin
                WriteLn(NWL + Indent + NLSstr('LINE.TOOLONG', IntStr(I)));
                Continue;
            end;

            Size := SizeOfFile(S {$IFDEF FAKELOST}+ 'x' {$ENDIF});
            if DOSError <> 0 then begin
                if ReportMissing then WriteLn(NWL + Indent + ErrorMsg(DOSError, S));
                Size := 0;
                Inc(TotalMissing);
                Inc(PkgMissing);
                continue;
            end;
            PkgBytes := PkgBytes + Size;
            TotalBytes := TotalBytes + Size;
            Inc(PkgFiles);
            Inc(TotalFiles);
            if (ListFiles < 1) then
                continue
            else if (ListFiles = 1) and (not ReportEXEs) then
                continue
            else if (ListFiles > 2)  and (ReportEXEs) then begin
                if Pos(';' + FileExtension(S) + ';', Execuatable) > 0 then
                    S := '*' + S
                else
                    S := ' ' + S;
            end else
            if (ListFiles = 2) and (ReportEXEs) then begin
                if Pos(';' + FileExtension(S) + ';', Execuatable) = 0 then
                    continue;
            end;
            Write(NWL + Indent);
            if ReportUsage then Write(RSpace(SizeStr(Size, false), MS));
            WriteLn(S);
{            if S = '' then Break; }
        end;
        if (NWLState = true) then Indent := ' - ';
        ShowStats(Indent, PkgFiles, PkgMissing, PkgBytes);
        FL.Close;
        FL.Destroy;
    end;

    function DisplayFile(AObject : PObject) : integer; far;
    var
        Item : PDirItem;
    begin
        TestBreak;
        DisplayFile := 0;
        Item:=PDirItem(AObject);
        if (PkgWildCard <> '*') and
            (MatchWildCard(PkgWildCard, BaseNameOf(Item^.Name)) = false) then exit;
        Inc(PkgShown);
        if ListFiles = 1 then begin
            Write(RSpace(BaseNameOf(Item^.Name),9));
            ListPackageFiles(BaseNameOf(Item^.Name));
        end else
            WriteLn(BaseNameOf(Item^.Name));
    end;

    function DisplayPkgTitle(AObject : PObject) : integer; far;
    var
        Item : PDirItem;
        LSM : PPackageLSM;
        Err : integer;
        T, V : String;
    begin
        TestBreak;
        DisplayPkgTitle := 0;
        Item:=PDirItem(AObject);
        if (PkgWildCard <> '*') and
            (MatchWildCard(PkgWildCard, BaseNameOf(Item^.Name)) = false) then exit;
        LSM := PPackageLSM(NewPackageLSM(nil));
        Err := LSM^.ReadMetaData(BaseNameOf(Item^.Name));
        if SearchMetaData(LSM) or (Err <> 0) then begin
            Inc(PkgShown);
            if Err <> 0 then
                WriteLn(RSpace(BaseNameOf(Item^.Name), 9) + '-> ' + NLSStr('ERROR.NUMBER', IntStr(Err)))
            else begin
                T := LSM^.DataStr('title');
                V := LSM^.DataStr('version');
                if V <> '' then V := '(' + V + ')';
                if (T <> '') and (V <> '') then V := #32 + V;
                WriteLn(RSpace(BaseNameOf(Item^.Name), 9) + ': ' + T + V);
            end;
            if ListFiles > 0 then ListPackageFiles(BaseNameOf(Item^.Name));
        end;
        if Assigned(LSM) then Dispose(LSM, Destroy);
    end;

    function ExpandMetaID(AStr:String) : String;
    begin
        AStr := UCase(AStr);
        if (AStr = 'ENTERED') or (AStr = 'MODIFIED') then
            AStr := AStr + '-DATE'
        else
        if (AStr = 'COPYING') or (AStr = 'POLICY') or (AStr = 'LICENSE') then
            AStr := 'COPYING-POLICY'
        else
        if (AStr = 'MAINTAINED') then
            AStr := AStr + '-BY'
        else
        if (AStr = 'PRIMARY') or (AStr = 'ALTERNATE')
        or (AStr = 'ORIGINAL') or (AStr = 'WIKI')
        or (AStr = 'MIRROR') then
            AStr := AStr + '-SITE';

        ExpandMetaID := AStr;
    end;

    procedure WrapWriteLn(P : PAsciiZ);
    var
        X, I, L : word;
    begin
        I := 0;
        X := TabStop + MetaFieldWidth;
        while (Pos(P^[I], #13#10#0) = 0) do begin
            L := X + 1;
            while (L < 79) and (Pos(P^[I + L - X], #32#13#10#0) = 0) do Inc(L);
            if (L = 79) and (P^[I] = #32) then X := 79;
            if X = 79 then begin
                WriteLn('');
                X := TabStop + MetaFieldWidth;
                { if X > 16 then begin
                    X := 16;
                    Write(Tab, Tab);
                end else begin }
                    Write(Tab + Space(MetaFieldWidth));
                {end; }
                if P^[I] = #32 then begin
                    Inc(I);
                    continue;
                end;
            end;
            Write(P^[I]);
            Inc(I);
            Inc(X);
        end;
        WriteLn('');
    end;

    function DisplayPkgMetadata(AObject : PObject) : integer; far;
    var
        Item : PDirItem;
        LSM : PPackageLSM;
        Err, I : integer;
        P : PAsciiZ;
        L, M, D : String;
        R, H : boolean;
    begin
        TestBreak;
        DisplayPkgMetadata := 0;
        Item:=PDirItem(AObject);
        { Filenames in DOS are Uppercase (Excluding LFN, which isn't supported
          at this time). Also, OPT is Uppercased in the command line parser
          before it sets the PkgWildCard. So, All Checking is using Uppercase
          letters.}
        if (PkgWildCard <> '*') and
            (MatchWildCard(PkgWildCard, BaseNameOf(Item^.Name)) = false) then exit;
        LSM := PPackageLSM(NewPackageLSM(nil));
        Err := LSM^.ReadMetaData(BaseNameOf(Item^.Name));
        if SearchMetaData(LSM) or (Err <> 0) then begin
            Inc(PkgShown);
            if (PkgShown > 1) then WriteLn('');
            if Err <> 0 then
                WriteLn(RSpace(BaseNameOf(Item^.Name), 9)+ '-> '+ NLSStr('ERROR.NUMBER', IntStr(Err)))
            else begin
                WriteLn(BaseNameOf(Item^.Name)+ ':');
                if DetailLevel = 1 then
                    L := UCase(ListMore)
                else
                    L := UCase(ListDetails);
                while L <> '' do begin
                    I := Pos(';', L);
                    if I < 1 then I := Length(L) + 1;
                    M := Copy(L, 1, I - 1);
                    Delete(L,1, I);
                    if (M <> '') and (M[1] = '*') then begin
                        R := True;
                        Delete(M, 1,1);
                    end else
                        R := False;
                    if M = '' then Continue;
                    M := ExpandMetaID(M);
                    P := LSM^.DataPtr(M);
                    if Assigned(P) then begin
                        H := false;
                        for I := 0 to LSM^.DataLen(P) - 1 do
                            if (P^[I] <> '-') then begin
                                H := True;
                                Break;
                            end;
                        if  not H then P := nil;
                    end;

                    if R or Assigned(P) then begin
                        Write(Tab+ RSpace(NLS(PrefixLSM + M) + ':', MetaFieldWidth));
                        if not Assigned(P) then
                            WriteLn(NLS(PrefixLSM + 'NA'))
                        else
                            WrapWriteLn(P);
                    end;
                end;
                if ListFiles > 0 then
                    Err := ListPackageFiles(BaseNameOf(Item^.Name));
            end;
        end;
        if Assigned(LSM) then Dispose(LSM, Destroy);
    end;

    procedure CalcMetaFieldWidth;
    var
        L, M : String;
        I : integer;
    begin
        MetaFieldWidth := 0;
        if DetailLevel = 1 then
            L := UCase(ListMore)
        else
            L := UCase(ListDetails);
        while L <> '' do begin
            I := Pos(';', L);
            if I < 1 then I := Length(L) + 1;
            M := Copy(L, 1, I - 1);
            Delete(L,1, I);
            if (M <> '') and (M[1] = '*') then
                Delete(M, 1,1);
            M:=NLS(PrefixLSM + ExpandMetaID(M));
            if Length(M) > MetaFieldWidth then
                MetaFieldWidth := Length(M);
        end;
        Inc(MetaFieldWidth, 2);
    end;

    procedure ListPackages;
    var
        Pkgs : PPackageList;
        X, Y : LongInt;
    begin
        X := MemAvail;

        Pkgs := PPackageList(NewPackageList(nil));
        Pkgs^.GetInstalled;
        case ListMode of
            0: Pkgs^.ForEach(DisplayFile);
            1: Pkgs^.ForEach(DisplayPkgTitle);
            2: begin
                CalcMetaFieldWidth;
                Pkgs^.ForEach(DisplayPkgMetaData);
            end;
        end;

        Y := MemAvail;

        if PkgShown = 0 then begin
            if WildSearch <> '' then
                WriteLn(NLSStr('PKG.NOTFOUND', WildSearch))
            else
                WriteLn(NLSStr('PKG.NOTFOUND', PkgWildCard));
            if PkgTesting then  Halt(2);
        end else begin
            WriteLn('');
            if PkgShown > 1 then begin
                Write(ReplaceStr(ReplaceStr(NLS('PACKAGES'),
                    '$0', NumberStr(PkgShown), True),
                    '$1', NumberStr(Pkgs^.Count), True));
                ShowStats(', ', TotalFiles, TotalMissing, TotalBytes);
            end{ else
                ShowStats('', TotalFiles, TotalMissing, TotalBytes); }
        end;
        Dispose(Pkgs, Destroy);
     { WriteLn(NLS('MEMORY.USAGE'), X - Y, ' / ', MemAvail - X); }
    end;

    function Options(Option : String; var NextParam : Integer) : boolean; far;
    begin
        Options := True;
        if Option = 'N' then begin
            ListMode := 0
        end else if Option = 'L' then begin
            ListMode := 1;
        end else if Option = 'I' then begin
            ListMode := 2;
            DetailLevel := 0;
        end else if Option = 'D' then begin
            DetailLevel := 1;
            ListMode := 2;
        end else if Option = 'R' then begin
            if ListFiles < 1 then ListFiles := 1;
            ReportMissing := True;
        end else if Option = 'U' then begin
            if ListFiles < 1 then ListFiles := 1;
            ReportUsage := True;
        end else if Option = 'E' then begin
            if ListFiles < 2 then ListFiles := 2;
            ReportEXEs := True;
        end else if Option = 'A' then begin
            if ListFiles < 3 then ListFiles := 3;
        end else if Option = 'S' then begin
            WildSearch := ParamStr(NextParam);
            Inc(NextParam);
         end else
            Options := False;
    end;


begin
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('');
    ParseCommandLine(Options);
    ListPackages;
end.
