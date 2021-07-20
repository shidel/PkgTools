{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}
unit QNLS;

interface

uses QClass, QDos, QStrings;

    const
        Language : Str2 = '';

    procedure SetBuiltInLanguage(AAddr : Pointer);
    procedure SetLanguage(ALang : String);

    function GetNLS(AID : String; var AString : String) : integer;
    { Returns 0 for Success, 1 for Success from BuiltIn, -1 for Failure }

    function NLS(AID : String) : String;

    function HasNLS(AID : String) : boolean;
    { Reports True if AID is set in the NLS Translation. If it is only BuiltIn
      or not present it reports False  }

implementation

procedure SetBuiltInLanguage(AAddr : Pointer);
begin
end;

procedure SetLanguage(ALang : String);
begin
    Language := UCase(Trim(ALang));
end;

function GetNLS(AID : String; var AString : String) : integer;
begin
    AString := '';
    GetNLS := -1;
end;

function NLS(AID : String) : String;
begin
    NLS := '';
end;

function HasNLS(AID : String) : boolean;
begin
    HasNLS := False;
end;


begin
    SetLanguage(GetEnv('LANG'));
end.