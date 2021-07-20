{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}
unit QNLS;

interface

uses QClass, QDos, QStrings, QASCIIZ;

    const
        Language : Str2 = '';

    { When Language data is set, it is stored in reverse order. So, defining
      a string again overrides any previous definitions. Also, defining
      frequently used strings later means they will be found quicker. But,
      if Performance is critical, cache the results from NLS in a string
      variable. }

    procedure SetBuiltInLanguage(AAddr : Pointer);
    procedure SetLanguage(ALang : String);

    function GetNLS(AID : String; var AString : String) : integer;
    { Returns 0 for Success, 1 for Success from BuiltIn, -1 for Failure }

    function NLS(AID : String) : String;

    function HasNLS(AID : String) : boolean;
    { Reports True if AID is set in the NLS Translation. If it is only BuiltIn
      or not present it reports False. It is assumed all required strings
      are already built-in  }

implementation

var
    LangData : Pointer;
    LangBuiltIn : Pointer;

procedure SetBuiltInLanguage(AAddr : Pointer);
begin
    LangBuiltIn := AAddr;
end;

procedure SetLanguage(ALang : String);
begin
    Language := UCase(Trim(ALang));
end;

function GetNLS(AID : String; var AString : String) : integer;
var
    P : Pointer;
    Ret : Integer;
begin
    Ret := -1;
    AString := '';
    if Assigned(LangBuiltIn) then
        begin
            P := FindAsciiZ(LangBuiltIn, AID);
            if Assigned(P) then begin
                AString:=PascalStr(P^);
                Ret := 1;
            end;
        end;

    GetNLS := Ret;
end;

function NLS(AID : String) : String;
var
    T : String;
begin
    GetNLS(AID, T); { Don't care where it came from }
    NLS := T;
end;

function HasNLS(AID : String) : boolean;
begin
    HasNLS := False;
end;


begin
    LangBuiltIn := nil;
    LangData := nil;
end.