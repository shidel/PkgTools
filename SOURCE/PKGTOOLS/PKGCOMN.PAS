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

    type
        TCleanUpProc = procedure;
        TCommandLineOption = function (Option : String; var NextParam : Integer) : boolean;

    const
        Version : String = '2021-08-22';
        Tab : String = '    ';
        TabStop : word = 4;
        PkgWildCard : String = '*';
        TumblerRate : integer = 10;
        CleanUpProc : TCleanUpProc = nil;
        IsOutCON : boolean = true;
        PagePause : boolean = false;

     const
        ErrBadOpt   = 'BADOPT';
        ErrNoTemp   = 'NOTEMP';
        ErrBadDrv   = 'BADDRV';
        ErrLowMem   = 'LOWMEM';
        ErrLnLen    = 'LONGLN';
        ErrIsULFN   = 'ISULFN';

    procedure TestBreak;
    procedure TestBreakWait;
    procedure DisplayVersion;
    procedure DisplayHelp;
    procedure ParseCommandLine(const OptionHandler : TCommandLineOption);

    function ErrorMsg(Err : integer; Data : String) : string;
    function ErrorTxt(Err : String; Data : String) : string;
    function NLSPlural(AID :String; D :String; Plural : boolean) : String;
    function SizeStr(I : Longint; Human : boolean) : String;

    procedure WriteHalt(Data : String; ExitCode : integer);

    procedure Tumbler;
    procedure TumblerDone;
    function  ElapsedTicks(Reset : boolean) : LongInt; { Could use improvement,
      eventually. At present, it is not used for anything import. So, don't
      care about roll-overs and such pesky little things. }

    function ValidPkgName(var AID : String) : boolean;
    procedure MemStat;

    procedure Write(S : String);
    procedure WriteLn(S : String);


implementation

    const
        ScreenX : integer = 1;
        ScreenY : integer = 1;

    procedure DoNewLine(NL : boolean);
    var
        S : String;
    begin
        ScreenX := 1;
        Inc(ScreenY);
        if NL then System.WriteLn;
        if ScreenY > 24 then begin
            ScreenY := 1;
            S := NLS('PAUSED');
            System.Write(S);
            TestBreakWait;
            System.Write(ChrStr(#8, Length(S)) + SPace(Length(S)) + ChrStr(#8, Length(S)));
        end;
    end;

    procedure Write(S : String);
    var
        T : String;
        X : integer;
    begin
        if Not PagePause then
            system.Write(S)
        else
        while S <> '' do begin
            T := Copy(S, 1, 80 - ScreenX);
            ScreenX := ScreenX + Length(T);
            Delete(S, 1, Length(T));
            System.Write(T);
            if ScreenX >= 80 then DoNewLine(False);
        end;

    end;

    procedure WriteLn(S : String);
    begin
        if Not PagePause then
            system.WriteLn(S)
        else begin
            Write(S);
            DoNewLine(True);
        end;
    end;

    var
        OrgMemAvail : LongInt;
        OrgMaxAvail : LongInt;

    procedure MemStat;
    begin
        WriteLn('MemAvail: ' + IntStr(MemAvail));
        WriteLn('MaxAvail: ' + IntStr(MaxAvail));
        WriteLn('OrgMem:   ' + IntStr(OrgMemAvail));
        WriteLn('OrgMAx:   ' + IntStr(OrgMaxAvail));
        WriteLn('HeapPtr:  ' + HexPtr(HeapPtr) );
        WriteLn('HeapEnd:  ' + HexPtr(HeapEnd) );
    end;

    procedure ShrinkHeap;
    var
        Size:Word;
        ParentPSP : word;
    begin
        { OldHeapEnd:=HeapEnd; }
        HeapEnd := HeapPtr;
        Size:=(Ofs(HeapPtr^) shr 4) + 1;
        Size:=Size + Seg(HeapPtr^) - PrefixSeg;
        asm
            push ES
            mov  AH, $4A
            mov  BX, Size
            mov  ES, PrefixSeg
            int  $21
            pop  ES
            jnc  @@Done
            mov  Size, BX
        @@Done:
        end;
    end;


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

    function ErrorTxt(Err : String; Data : String) : string;
    var
        R : String;
    begin
        R := NLSstr('ERROR.' + Err, Err);
        if R = '' then R := NLSstr('ERROR.NUMBER',Err);
        R := NLSStr('ERROR', R);
        if Data <> '' then
            R := Trim(R) + ', ' + DATA;
        ErrorTxt := Trim(R);
    end;

    function ErrorMsg(Err : integer; Data : String) : string;
    begin
        ErrorMsg := ErrorTxt(IntStr(Err), Data);
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
    var
        HoldProc : TCleanUpProc;
    begin
        if CtrlCPressed then begin
            WriteLn('^C -- ' + NLS('PROG.ABORT'));
            if Assigned(CleanUpProc) then begin
                HoldProc := CleanUpProc;
                CleanUpProc := nil;
                HoldProc;
            end;
            Halt(1);
        end
    end;

    procedure TestBreakWait;
    var
        HoldProc : TCleanUpProc;
    begin
        if WaitCtrlCPressed then begin
            WriteLn('^C -- ' + NLS('PROG.ABORT'));
            if Assigned(CleanUpProc) then begin
                HoldProc := CleanUpProc;
                CleanUpProc := nil;
                HoldProc;
            end;
            Halt(1);
        end
    end;

    procedure DisplayVersion;
    begin
        WriteLn(NLS('PROG.TITLE') + ', ' + NLSstr('PROG.VERSION', Version));
        WriteLn(NLS('PROG.DESC'));
        WriteLn('');
    end;

    procedure DisplaySupport;
    var
        S : String;
    begin
        S:=NLSstr('SUPPORT', NLS('PROG.TITLE'));
        if S <> '' then begin
            WriteLn(S);
            WriteLn('');
        end;
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
        WriteLn('');
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
        for I := 1 to ParamCount do begin
            if (UCase(ParamStr(I)) = SwitchChar + 'P') or
            (UCase(ParamStr(I)) = SwitchChar + 'P+') or
            (UCase(ParamStr(I)) = SwitchChar +  '+P') then begin
                PagePause := IsOutCON;
            end else if (UCase(ParamStr(I)) = SwitchChar + 'P-') or
            (UCase(ParamStr(I)) = SwitchChar + '-P') then begin
                PagePause := False;
            end;
        end;
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
                if Opt = SwitchChar + 'NLS' then begin
                    { ignore }
                    Inc(I)
                end else if (Opt = '//') or (Opt = SwitchChar + 'P') or
                (Opt = SwitchChar + 'P+') or (Opt = SwitchChar + '+P') or
                (Opt = SwitchChar + 'P-') or (Opt = SwitchChar + '-P') then begin
                    { ignore }
                end else if Opt = SwitchChar + 'VER' then begin
                    VersionShow := True
                end else if Assigned(OptionHandler) and
                OptionHandler(Copy(Opt, 2, Length(Opt)),I) then begin
                    VersionToggle := True
                end else begin
                    H := NLSStr('ERROR.' + ErrBadOpt, OPT);
                    if H = '' then H := NLSStr('BAD.SWITCH', OPT);
                    WriteLn(H);
                    Halt(1)
                end
            end else begin
                PkgWildCard := Opt; { Already Uppercase :-) }
                VersionToggle := True;
            end;
        end;
        if VersionShow then begin
            if (not VersionToggle) then WriteLn('');
            DisplayVersion;
            if (not VersionToggle) then begin
                DisplaySupport;
                Halt(0);
            end;
        end;
        { ProcessPackages; Do it in utility }
    end;

    procedure Tumbler;
    begin
        if not IsOutCON then exit;
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

    function ValidPkgName(var AID : String) : boolean;
    var
        NAID : String;
    begin
        NAID := AID;
        ValidPkgName := False;
        if (ExtensionOf(NAID) <> '') and (ExtensionOf(NAID) <> 'LSM') then Exit;
        NAID := BaseNameOf(NAID);
        if (NAID <> OnlyAlphaNum(NAID)) then exit;
        if (NAID <> '') then begin
            ValidPkgName := true;
            AID := NAID;
        end;
    end;

begin
    IsOutCON := not IsRedirectedOutput;
    OrgMaxAvail := MaxAvail;
    OrgMemAvail := MemAvail;
end.
