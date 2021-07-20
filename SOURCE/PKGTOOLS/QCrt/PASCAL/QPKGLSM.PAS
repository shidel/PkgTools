{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}

unit QPkgLSM;

interface

    uses QClass, QDOS, QAsciiZ, QNLS;

    var
        PackageLSMPath : String;
        PackageLSTPath : String;

    type
        PPackageLSM = ^TPackageLSM;
        TPackageLSM = object (TObject)
        public
            DLang : Pointer;
            DSize : word;
            ULang : Pointer;
            USize : word;
            constructor Create(AOwner : PObject);
            function ReadMetaData (APackage : String) : integer; virtual;
            function WriteMetaData (APackage : String) : integer; virtual;
            function GetClassName : String; virtual;
            function SizeOfObject : LongInt; virtual;
            procedure Clear; virtual;
            function FieldPtr(AID : String) : Pointer; virtual;
            function DataPtr(AID : String) : Pointer; virtual;
            function DataLen(AID : String) : word; virtual;
            function DataStr(AID : String) : String; virtual;
        end;

        PPackageList = ^TPackageList;
        TPackageList = object (TDirList)
        public
            constructor Create (AOwner : PObject);
            function GetClassName : String; virtual;
            function SizeOfObject : LongInt; virtual;
            function GetInstalled : integer; virtual;
        end;

function NewPackageLSM(AOwner:PObject) : PObject;
function NewPackageList(AOwner:PObject) : PObject;

implementation

{ TPackageLSM }
constructor TPackageLSM.Create(AOwner : PObject);
begin
    inherited Create(AOwner);
    DLang := nil;
    ULang := nil;
    DSize := 0;
    USize := 0;
end;

function TPackageLSM.ReadMetaData (APackage : String) : integer;
var
    I  : Word;

begin
    if Assigned(DLang) then Clear;
    ReadMetaData := 0;
    DLang := LoadAsciiFile(TailDelim(PackageLSMPath) + APackage + '.LSM', DSize);
    if Not Assigned(DLang) then begin
        ReadMetaData := DSize;
        Exit;
    end;
    if FileExists(TailDelim(PackageLSMPath) + APackage + '.' + UserLanguage) then begin
        ULang := LoadAsciiFile(TailDelim(PackageLSMPath) + APackage + '.' + UserLanguage, USize);
        if Not Assigned(ULang) then begin
            ReadMetaData := USize;
            Exit;
        end;

    end
end;

function TPackageLSM.WriteMetaData (APackage : String) : integer;
begin
    WriteMetaData := 0;
end;

function TPackageLSM.GetClassName : String;
begin
    GetClassName := 'TPackageLSM';
end;

function TPackageLSM.SizeOfObject : LongInt;
begin
    SizeOfObject := SizeOf(TPackageLSM);
end;

procedure TPackageLSM.Clear;
begin
    if Assigned(DLang) then FreeMem(DLang, DSize);
    if Assigned(ULang) then FreeMem(ULang, USize);
    DLang := nil;
    ULang := nil;
    DSize := 0;
    USize := 0;
end;

function TPackageLSM.FieldPtr(AID : String) : Pointer;
begin
    FieldPtr := nil;
end;

function TPackageLSM.DataPtr(AID : String) : Pointer;
begin
    DataPtr := nil;
end;

function TPackageLSM.DataLen(AID : String) : word;
begin
    DataLen := 0;
end;

function TPackageLSM.DataStr(AID : String) : String;
begin
    DataStr := '';
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

function NewPackageLSM(AOwner:PObject) : PObject;
begin
    NewPackageLSM := New(PPackageLSM, Create(AOwner));
end;

function NewPackageList(AOwner:PObject) : PObject;
begin
    NewPackageList := New(PPackageList, Create(AOwner));
end;

{ initialization & finalization routines }
begin
    PackageLSMPath := TailDelim(GetEnv('DOSDIR')) + 'APPINFO';
    PackageLSTPath := TailDelim(GetEnv('DOSDIR')) + 'PACKAGES';
    RegisterObject('TPackageLSM', NewPackageLSM);
    RegisterObject('TPackageList', NewPackageList);
end.