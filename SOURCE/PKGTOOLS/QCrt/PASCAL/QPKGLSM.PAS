{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}

unit QPkgLSM;

interface

    uses QClass, QDOS, QFiles;

    var
        PackageLSMPath : String;
        PackageLSTPath : String;

    type
        PLSM = ^TLSM;
        TLSM = object (TObject)
        public
            function ReadMetaData (APackage : String) : integer; virtual;
            function WriteMetaData (APackage : String) : integer; virtual;
            function GetClassName : String; virtual;
            function SizeOfObject : LongInt; virtual;
        end;

        PPackageList = ^TPackageList;
        TPackageList = object (TDirList)
        public
            constructor Create (AOwner : PObject);
            function GetClassName : String; virtual;
            function SizeOfObject : LongInt; virtual;
            function GetInstalled : integer; virtual;
        end;

function NewLSM(AOwner:PObject) : PObject;
function NewPackageList(AOwner:PObject) : PObject;

implementation

{ TLSM }
function TLSM.ReadMetaData (APackage : String) : integer;
begin
    ReadMetaData := 0;
end;

function TLSM.WriteMetaData (APackage : String) : integer;
begin
    WriteMetaData := 0;
end;

function TLSM.GetClassName : String;
begin
    GetClassName := 'TLSM';
end;

function TLSM.SizeOfObject : LongInt;
begin
    SizeOfObject := SizeOf(TLSM);
end;

{ TPackageList }
constructor TPackageList.Create (AOwner : PObject);
begin
    inherited Create(AOwner);
    IncludeParent := False;
    IncludeDirs := False;
end;

function TPackageList.GetClassName : String;
begin
    GetClassName := 'TPackageList';
end;

function TPackageList.SizeOfObject : LongInt;
begin
    SizeOfObject := SizeOf(TPackageList);
end;

function TPackageList.Getinstalled : integer;
begin
    GetDirList(TailDelim(PackageLSMPath) + '*.LSM', faAnyFile);
    GetInstalled := Count;
end;

function NewLSM(AOwner:PObject) : PObject;
begin
    NewLSM := New(PLSM, Create(AOwner));
end;

function NewPackageList(AOwner:PObject) : PObject;
begin
    NewPackageList := New(PPackageList, Create(AOwner));
end;

{ initialization & finalization routines }
begin
    PackageLSMPath := TailDelim(GetEnv('DOSDIR')) + 'APPINFO';
    PackageLSTPath := TailDelim(GetEnv('DOSDIR')) + 'PACKAGES';
    RegisterObject('TLSM', NewLSM);
    RegisterObject('TPackageList', NewPackageList);
end.