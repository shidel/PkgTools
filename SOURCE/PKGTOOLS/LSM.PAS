unit LSM;

interface

    uses QClass, QDOS, QFiles;

    type
        PLSM = ^TLSM;
        TLSM = object (TObject)
        public
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
    GetDirList(GetEnv('DOSDIR') + '\APPINFO\*.LSM', faAnyFile);
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
    RegisterObject('TLSM', NewLSM);
    RegisterObject('TPackageList', NewPackageList);
end.