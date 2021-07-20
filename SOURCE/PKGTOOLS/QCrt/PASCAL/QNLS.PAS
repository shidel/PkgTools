{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}
unit QNLS;

interface

uses QClass, QDos, QStrings, QFiles;

    const
        Language : Str2 = '';

    procedure SetLanguage(ALang : String);

implementation


procedure SetLanguage(ALang : String);
begin
    Language := UCase(Trim(ALang));
end;

begin
    SetLanguage(GetEnv('LANG'));
end.