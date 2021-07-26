{
Copyright 2021, Jerome Shidel
Released Under Mozilla Public License 2.0

This project and related files are subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file, You
can obtain one at http://mozilla.org/MPL/2.0/.
}
unit PkgComn;


interface

    uses QDOS, QStrings, QNLS;

    const
        Version : String = 'alpha0';
        Tab : String = '    ';
        TabStop : word = 4;
        PkgWildCard : String = '*';
        TumblerRate : integer = 10;

    type
        TCommandLineOption = function (Option : String; var NextParam : Integer) : boolean;

    procedure TestBreak;
    procedure DisplayVersion;
    procedure DisplayHelp;
    procedure ParseCommandLine(const OptionHandler : TCommandLineOption);

    function ErrorMsg(Err : integer; Data : String) : string;
    function NLSPlural(AID :String; D :String; Plural : boolean) : String;
    function SizeStr(I : Longint; Human : boolean) : String;

    procedure WriteHalt(Data : String; ExitCode : integer);

    procedure Tumbler;
    procedure TumblerDone;
    function  ElapsedTicks(Reset : boolean) : LongInt; { Could use improvement,
      eventually. At present, it is not used for anything import. So, don't
      care about roll-overs and such pesky little things. }

    function ValidPkgName(AID : String) : boolean;

implementation

    var
        TimerTick : LongInt absolute $0040:$006c;  { Timer tick counter }

    const
        LastTick  : Longint = -1;
        LastCount : integer = MaxInt - 1;
        TumblePos : byte = 0;
        TumbleChar : string = '|/-\';
        LastTime : LongInt = MaxLongInt;

    function ElapsedTicks(Reset : boolean) : LongInt;
    var
        Present, X : LongInt;
    begin
        Present := TimerTick;
        if Present < LastTime then
            X := MaxLongInt
        else
            X := (Present - LastTime);
        if Reset then
            LastTime := Present;
        ElapsedTicks := X;
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

    procedure WriteHalt (Data : String; ExitCode : integer);
    begin
        WriteLn(Data);
        Halt(ExitCode);
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
        S, X : String;
        R : {$IFOPT N+} Extended {$ELSE} Real {$ENDIF};
    begin
        S := '';
        if Human then begin
            X := 'BYTE';
            if I >= 2048 then begin
                X := 'KBYTE';
                R := I / 1024;
                if R >= 2048 then begin
                    X := 'MBYTE';
                    R := R / 1024;
                end;
            end;
            if X = 'BYTE' then
                S := NLSPlural('BYTE', IntStr(I), I <> 1)
            else
                S := NLSPlural(X, RealStr(R, 1), True)
        end;
        if S = '' then
            S := IntStr(I);
        SizeStr := S;
    end;

    procedure TestBreak;
    begin
        if CtrlCPressed then begin
            WriteLn('^C -- ', NLS('PROG.ABORT'));
            Halt(1);
        end
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

    procedure ParseCommandLine(const OptionHandler : TCommandLineOption);
    const
        VersionShow : boolean = false;
        VersionToggle : boolean = false;
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
            if Length(Opt) < 1 then
                continue { should never happen }
            else if (Opt[1] = SwitchChar) then begin
                if Opt = SwitchChar + 'NLS' then
                    Inc(I)
                else if Opt = SwitchChar + 'VER' then
                    VersionShow := True
                else if Assigned(OptionHandler) and
                OptionHandler(Copy(Opt, 2, Length(Opt)),I) then begin
                    VersionToggle := True
                end else begin
                    WriteLn(NLSStr('BAD.SWITCH', OPT));
                    Halt(1)
                end
            end else begin
                PkgWildCard := Opt; { Already Uppercase :-) }
                VersionToggle := True;
            end;
        end;
        if VersionShow then begin
            DisplayVersion;
            if (not VersionToggle) then Halt(0);
        end;
        { ProcessPackages; Do it in utility }
    end;

    procedure Tumbler;
    begin
        if LastTick = TimerTick then Exit;
        LastTick := TimerTick;
        Inc(LastCount);
        If LastCount < TumblerRate then Exit;
        LastCount := 0;
        if TumblePos > 0 then Write(#8);
        Inc(TumblePos);
        If TumblePos > Length(TumbleChar) then TumblePos := 1;
        Write(TumbleChar[TumblePos]);
    end;

    procedure TumblerDone;
    begin
        LastTick := -1;
        LastCount := MaxInt - 1;
        if TumblePos > 0 then Write(#8' '#8);
        TumblePos := 0;
    end;

    function ValidPkgName(AID : String) : boolean;
    begin
        ValidPkgName := False;
        if (ExtensionOf(AID) <> '') and (ExtensionOf(AID) <> 'LSM') then Exit;
        AID := BaseNameOf(AID);
        if (AID <> OnlyAlphaNum(AID)) then exit;
        ValidPkgName := (AID <> '');
    end;

end.
