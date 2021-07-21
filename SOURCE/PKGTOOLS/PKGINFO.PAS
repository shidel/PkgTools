{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}

{$M 32678,102400,655360}
program Package_Info;

uses QDOS, QClass, QStrings, QNLS, QPkgLSM, QAsciiZ;

    procedure TestBreak;
    begin
        if CtrlCPressed then begin
            WriteLn('^C -- ', NLS('PROG.ABORT'));
            Halt(1);
        end
    end;

const
    Version : String = '2021-07-20';
    ListDetails : String = '*title;*version;*copying;description';
    ListMore : String = '*title;*version;*copying;entered;' +
        'description;summary;changes;keywords;author;maintained;platforms;' +
        'primary,alternate;wiki;mirror';
    WidthDetails : word = 0;
    DetailLevel : integer = 0;
    WildCard : String = '*';

    procedure ProgramMessages; assembler;
    asm
        db 'PROG.NAME=PkgInfo',0
        db 'PROG.TITLE=PkgInfo',0
        db 'PROG.VERSION=Version $',0
        db 'PROG.DESC=Package Information Utility',0
        db 'PROG.ABORT=program aborted',0
        db 'MEM.USAGE=Memory Usage',0
        db 'LSM.TITLE=Title',0
        db 'LSM.ENTERED-DATE=Date',0
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
        db 'HELP.0=embedded help not available',0

        db 0
    end;

    function DisplayFile(AObject : PObject) : integer; far;
    var
        Item : PDirItem;
    begin
        TestBreak;
        DisplayFile := 0;
        Item:=PDirItem(AObject);
        if (WildCard <> '*') and
            (MatchWildCard(WildCard, BaseNameOf(Item^.Name)) = false) then exit;
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
        if (WildCard <> '*') and
            (MatchWildCard(WildCard, BaseNameOf(Item^.Name)) = false) then exit;
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

    function DisplayPkgMetadata(AObject : PObject) : integer; far;
    var
        Item : PDirItem;
        LSM : PPackageLSM;
        Err, I : integer;
        P : PAsciiZ;
        L, M, D : String;
        R : boolean;
    begin
        TestBreak;
        DisplayPkgMetadata := 0;
        Item:=PDirItem(AObject);
        { Filenames in DOS are Uppercase (Excluding LFN, which isn't supported
          at this time). Also, OPT is Uppercased in the command line parser
          before it sets the WILDCARD. So, All Checking is using Uppercase
          letters.}
        if (WildCard <> '*') and
            (MatchWildCard(WildCard, BaseNameOf(Item^.Name)) = false) then exit;
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
                M:=ExpandMetaID(M);
                P := LSM^.DataPtr(M);
                if R or Assigned(P) then begin
                    Write(#9, RSpace(NLS('LSM.' + M) + ':', WidthDetails),
                        M, ', ', Assigned(P));
                    WriteLn;
                end;
            end;
            Dispose(LSM, Destroy);
        end;
    end;


    procedure ListPackages(Mode:integer);
    var
        Pkgs : PPackageList;
        X, Y : LongInt;
    begin
        X := MemAvail;

        Pkgs := PPackageList(NewPackageList(nil));
        Pkgs^.GetInstalled;
        case Mode of
            0: Pkgs^.ForEach(DisplayFile);
            1: Pkgs^.ForEach(DisplayPkgTitle);
            2: Pkgs^.ForEach(DisplayPkgMetaData);
        end;

        Y := MemAvail;

        Dispose(Pkgs, Destroy);
        WriteLn(NLS('MEMORY.USAGE'), X - Y, ' / ', MemAvail - X);
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
        ListMode : integer;
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

        ListMode := 1;
        I := 1;
        while I <= ParamCount do begin
            Opt:=UCase(ParamStr(I));
            Inc(I);
            if Opt = SwitchChar + 'NLS' then begin Inc(I) end
            else if Opt = SwitchChar + 'N' then
                ListMode := 0
            else if Opt = SwitchChar + 'L' then
                ListMode := 1
            else if Opt = SwitchChar + 'D' then
                ListMode := 2
            else if Opt = SwitchChar + 'M' then
                DetailLevel := 1
            else begin
                WildCard := Opt; { Already Uppercase :-) }
            end;
        end;
        if (ListMode >= 0) then
            ListPackages(ListMode);
    end;

begin
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('');
    ParseCommandLine;
end.
