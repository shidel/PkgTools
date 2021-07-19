program Package_Info;

uses QDOS, QClass, QStrings, LSM, NLS;

const
    ListDetails : String ='id;title;(version)';


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
    ListPackages;
end.
