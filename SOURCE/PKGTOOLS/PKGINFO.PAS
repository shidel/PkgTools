{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}
program Package_Info;

uses QDOS, QClass, QStrings, QNLS, QPkgLSM;

const
    Version : String = '2021-07-20';
    ListDetails : String ='id;title;(version)';

    procedure ProgramMessages; assembler;
    asm
        db 'PROG.NAME=PkgInfo',0
        db 'PROG.TITLE=PkgInfo',0
        db 'PROG.VERSION=Version $',0
        db 'PROG.DESC=Package Information Utility',0
        db 'MEM.USAGE=Memory Usage',0
        db 'LSM.LSM.TITLE=Title',0
        db 'LSM.ENTERED-DATE=Date',0
        db 'LSM.DESCRIPTION:Description',0
        db 'LSM.SUMMARY=Summary',0
        db 'LSM.CNANGES=What',$27,'s New',0
        db 'LSM.KEYWORDS=Keywords',0
        db 'LSM.AUTHOR=Author',0
        db 'LSM.MAINTAINED-BY=Maintainer',0
        db 'LSM.PLATFORMS=Supported Plaforms',0
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
        Item:=PDirItem(AObject);
        WriteLn(BaseNameOf(Item^.Name));
        DisplayFile := 0;
    end;

    function DisplayPkgTitle(AObject : PObject) : integer; far;
    var
        Item : PDirItem;
        LSM : PPackageLSM;
        Err : integer;
        T, V : String;
    begin
        Item:=PDirItem(AObject);
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
        DisplayPkgTitle := 0;
    end;

    function DisplayPkgMetadata(AObject : PObject) : integer; far;
    var
        Item : PDirItem;
        LSM : PPackageLSM;
        Err : integer;
        T, V : String;
    begin
        Item:=PDirItem(AObject);
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
        DisplayPkgMetadata := 0;
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
        s := ReplaceStr(S, '$', GetEXEBase, True);
        if W < 0 then Halt(1);
        H := W;
        while (H = W) do begin
            WriteLn(S);
            Inc(I);
            W := GetNLS('HELP.' + IntStr(I), S);
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
            if (UCase(ParamStr(I)) = '/H')
            or (UCase(ParamStr(I)) = '/?')
            or (UCase(ParamStr(I)) = '/HELP') then
                DisplayHelp
            else if (UCase(ParamStr(I)) = '/NLS') then
                SetLanguage(ParamStr(I+1));

        I := 1;
        while I <= ParamCount do begin
            Opt:=UCase(ParamStr(I));
            Inc(I);
            if Opt = '/NLS' then begin end
            else if Opt = '/L' then
                ListPackages(0)
            else if Opt = '/LIST' then
                ListPackages(1)
            else begin
                H := PackageWildCard;
                PackageWildCard := Opt;
                ListPackages(2);
                PackageWildCard := H;
            end;
        end;
    end;

begin
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('');
    ParseCommandLine;
end.
