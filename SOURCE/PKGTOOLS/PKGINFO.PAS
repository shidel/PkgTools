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
    ListDetails : String ='id;title;(version)';

    procedure ProgramMessages; assembler;
    asm
        db 'PROG.NAME=PkgInfo',0
        db 'PROG.TITLE=Package Information Utility',0
        db 'MEM.USAGE=Memory Usage',0
        db 0
    end;

    function DisplayFile(AObject : PObject) : integer; far;
    var
        Item : PDirItem;
    begin
        Item:=PDirItem(AObject);
        WriteLn(RSpace(BaseNameOf(Item^.Name), 9), ':');
        DisplayFile := 0;
    end;

    procedure ListPackages;
    var
        Pkgs : PPackageList;
        X, Y : LongInt;
    begin
        X := MemAvail;

        Pkgs := PPackageList(NewPackageList(nil));
        Pkgs^.GetInstalled;
        Pkgs^.ForEach(DisplayFile);

        Y := MemAvail;

        Dispose(Pkgs, Destroy);
        WriteLn('Memory Usage ', X - Y, ' / ', MemAvail - X);
    end;


begin
    SetBuiltInLanguage(@ProgramMessages);
    SetLanguage('es');
    WriteLn(NLS('PROG.TITLE'));
    Halt(0);
    ListPackages;
end.
