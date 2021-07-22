{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}

{$M 32678,102400,655360}
{$S+}
{$DEFINE FAKELOST}
program Package_Info;

uses QDOS, QClass, QStrings, QNLS, QPkgLSM, QAsciiZ, QFiles;

    procedure TestBreak;
    begin
        if CtrlCPressed then begin
            WriteLn('^C -- ', NLS('PROG.ABORT'));
            Halt(1);
        end
    end;

const
    Version : String = '2021-07-20';
    Tab : String = '    ';
    TabStop : word = 4;

    ListDetails : String = '*title;*version;*copying;description';
    ListMore : String = '*title;*version;entered;' +
        'description;summary;changes;keywords;author;maintained;' +
        'primary;alternate;wiki;mirror;*copying';
    ListMode : integer = 1;

    Execuatable : String = ';EXE;COM;BAT;';
    PrefixLSM : Str4 = 'LSM.';

    DetailLevel : integer = 0;
    MetaFieldWidth : word = 0;
    PkgWildCard : String = '*';
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
    ListFiles : integer = 0; { 0 = don't; 1 = invisible for Missing & Usage;
                               2 = EXE, COM & BAT; 3 = Everything }


    procedure ProgramMessages; assembler;
    asm
        db 'PROG.NAME=PkgInfo',0
        db 'PROG.TITLE=PkgInfo',0
        db 'PROG.VERSION=Version $',0
        db 'PROG.DESC=Package Information Utility',0
        db 'PROG.ABORT=^C - aborted',0
        db 'MEM.USAGE=Memory Usage',0
        db 'BAD.SWITCH=invalid switch $',0
        db 'PKG.INSTALLED=package $ is installed',0
        db 'PKG.NOTFOUND=package $ not found',0
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
        db 'ALLFILES=File list',0
        db 'BINARIES=File list',0
        db 'MISSING.SOME=Missing files',0
        db 'MISSING.NONE=No missing files',0
        db 'MISSING.ALL=All files are missing',0
        db 'HELP.0=no built-in help available',0

        db 0
    end;

    function ErrorMsg(Err : integer; Data : String) : string;
    var
        R : String;
    begin
        R := NLSstr('ERROR.' + IntStr(Err),IntStr(Err));
        if R = '' then begin
            R := NLSstr('ERROR.NUMBER',IntStr(Err));
        end;
        R := NLSStr('ERROR', R);
        if Data <> '' then
            R := Trim(R) + ', ' + DATA;
        ErrorMsg := Trim(R);

    end;

    function NLSPlural(AID :String; D :String; Plural : boolean) : String;
    var
        S : String;
    begin
        if Plural then S := NLSstr(AID + 'S', D) else S := '';
        if (Not Plural) or (S = '') then S := NLSstr(AID, D);
        if S = '' then S := NLSstr(AID + 'S', D);
        NLSPlural := S;
    end;

    function SizeStr(I : Longint; Human : boolean) : String;
    var
        S : String;
    begin
        S := '';
        if Human then
            S := NLSPlural('BYTE', IntStr(I), I <> 1);
        if S = '' then
            S := IntStr(I);
        SizeStr := S;
    end;

    function NumberStr(I : Longint) : String;
    begin
        NumberStr := IntStr(I);
    end;

    function FilesStr(I : Longint) : String;
    begin
        FilesStr := NLSPlural('FILE', IntStr(I), I <> 1);
    end;

    function ListPackageFiles(APkg : String) : integer;
    var
        FL : TDiskFile;
        Size : longint;
        S : String;
        I, MS : integer;
        LenOK : boolean;
        Indent : String;
        IndentX : integer;
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
                WriteLn(Indent, ErrorMsg(FL.Result, TailDelim(PackageLSTPath) + APkg + FileExtLST));
                break;
            end;
            if Trim(S) = '' then Continue;
            Inc(I);
            if Not LenOK then begin
                WriteLn(Indent, NLSstr('LINE.TOOLONG', IntStr(I)));
                Continue;
            end;

            Size := SizeOfFile(S {$IFDEF FAKELOST}+ 'x' {$ENDIF});
            if DOSError <> 0 then begin
                if ReportMissing then WriteLn(Indent, ErrorMsg(DOSError, S));
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
            Write(Indent);
            if ReportUsage then Write(RSpace(SizeStr(Size, false), MS));
            WriteLn(S);
{            if S = '' then Break; }
        end;
        if (PkgMissing = 0) then begin
            if ReportMissing then
                Write(Indent, NLS('MISSING.NONE'));
        end else if (PkgFiles = 0) then
            Write(Indent, NLS('MISSING.ALL'))
        else
            Write(Indent, ReplaceStr(
                ReplaceStr(NLSPlural('MISSING.SOME', '$', PkgFiles <> 1), '$0', NumberStr(PkgMissing), True),
                '$1', NumberStr(I), True));

        if ReportUsage then begin
            if (PkgMissing = 0) and (not ReportMissing) then begin
                WriteLn(Indent, FilesStr(PkgFiles), ', ', SizeStr(PkgBytes, True))
            end else if PkgMissing = 0 then
                WriteLn(', ', FilesStr(PkgFiles), ', ', SizeStr(PkgBytes, True))
            else
                WriteLn(', ', SizeStr(PkgBytes, True));
        end else if (PkgMissing <> 0) then WriteLn;

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
        WriteLn(BaseNameOf(Item^.Name));
        if ListFiles > 0 then ListPackageFiles(BaseNameOf(Item^.Name));
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
        Inc(PkgShown);
        LSM := PPackageLSM(NewPackageLSM(nil));
        Err := LSM^.ReadMetaData(BaseNameOf(Item^.Name));
        if Err <> 0 then
            WriteLn(RSpace(BaseNameOf(Item^.Name), 9), '-> ', NLSStr('ERROR.NUMBER', IntStr(Err)))
        else begin
            T := LSM^.DataStr('title');
            V := LSM^.DataStr('version');
            if V <> '' then V := '(' + V + ')';
            if (T <> '') and (V <> '') then V := #32 + V;
            WriteLn(RSpace(BaseNameOf(Item^.Name), 9), ': ', T, V);
            Dispose(LSM, Destroy);
        end;
        if ListFiles > 0 then ListPackageFiles(BaseNameOf(Item^.Name));
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
                WriteLn;
                X := TabStop + MetaFieldWidth;
                { if X > 16 then begin
                    X := 16;
                    Write(Tab, Tab);
                end else begin }
                    Write(Tab, Space(MetaFieldWidth));
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
        WriteLn;
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
        Inc(PkgShown);
        if (PkgShown > 1) then WriteLn;
        LSM := PPackageLSM(NewPackageLSM(nil));
        Err := LSM^.ReadMetaData(BaseNameOf(Item^.Name));
        if Err <> 0 then
            WriteLn(RSpace(BaseNameOf(Item^.Name), 9), '-> ', NLSStr('ERROR.NUMBER', IntStr(Err)))
        else begin
            WriteLn(BaseNameOf(Item^.Name), ':');
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
                    Write(Tab, RSpace(NLS(PrefixLSM + M) + ':', MetaFieldWidth));
                    if not Assigned(P) then
                        WriteLn(NLS(PrefixLSM + 'NA'))
                    else
                        WrapWriteLn(P);
                end;
            end;
            if ListFiles > 0 then
                Err := ListPackageFiles(BaseNameOf(Item^.Name));
            Dispose(LSM, Destroy);
        end;
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

        Dispose(Pkgs, Destroy);
        if PkgShown = 0 then begin
            WriteLn(NLSStr('PKG.NOTFOUND', PkgWildCard));
            if PkgTesting then  Halt(2);
        end;
        { WriteLn(NLS('MEMORY.USAGE'), X - Y, ' / ', MemAvail - X); }
    end;

    procedure DisplayVersion;
    begin
        WriteLn(NLS('PROG.TITLE'), ', ', NLSstr('PROG.VERSION', Version));
        WriteLn(NLS('PROG.DESC'));
        WriteLn;
    end;

    procedure DisplayHelp;
    var
        I, W, H : integer;
        S : String;
    begin
        DisplayVersion;
        I := 0;
        W := GetNLS('HELP.' + IntStr(I), S);
        S := ReplaceStr(S, '$', GetEXEBase, True);
        if W < 0 then Halt(1);
        H := W;
        while (H = W) do begin
            WriteLn(S);
            Inc(I);
            W := GetNLS('HELP.' + IntStr(I), S);
            S := ReplaceStr(S, '$', SwitchChar, True);
        end;
        WriteLn;
        Halt(0);
    end;

    procedure ParseCommandLine;
    var
        I : integer;
        Opt, H : String;
    begin
         for I := 1 to ParamCount do
            if ParamStr(I) = '//' then SwitchChar := '/';
         for I := 1 to ParamCount do
            if (UCase(ParamStr(I)) = SwitchChar + 'H')
            or (UCase(ParamStr(I)) = SwitchChar + '?')
            or (UCase(ParamStr(I)) = SwitchChar + 'HELP') then
                DisplayHelp
            else if (UCase(ParamStr(I)) = SwitchChar + 'NLS') then
                SetLanguage(ParamStr(I+1));

        I := 1;
        while I <= ParamCount do begin
            Opt:=UCase(ParamStr(I));
            Inc(I);
            if Opt = SwitchChar + 'NLS' then begin Inc(I) end
            else if Opt = SwitchChar + 'N' then
                ListMode := 0
            else if Opt = SwitchChar + 'L' then
                ListMode := 1
            else if Opt = SwitchChar + 'I' then begin
                ListMode := 2;
                DetailLevel := 0;
            end else if Opt = SwitchChar + 'D' then begin
                DetailLevel := 1;
                ListMode := 2;
            end else if Opt = SwitchChar + 'R' then begin
                if ListFiles < 1 then ListFiles := 1;
                ReportMissing := True;
            end else if Opt = SwitchChar + 'U' then begin
                if ListFiles < 1 then ListFiles := 1;
                ReportUsage := True;
            end else if Opt = SwitchChar + 'E' then begin
                if ListFiles < 2 then ListFiles := 2;
                ReportEXEs := True;
            end else if Opt = SwitchChar + 'A' then begin
                if ListFiles < 3 then ListFiles := 3;
            end else if Opt[1] = SwitchChar then begin
                WriteLn(NLSStr('BAD.SWITCH', OPT));
                Halt(1);
            end else begin
                PkgWildCard := Opt; { Already Uppercase :-) }
            end;
        end;
        if (ListMode >= 0) then ListPackages;
    end;

begin
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('');
    ParseCommandLine;
end.
