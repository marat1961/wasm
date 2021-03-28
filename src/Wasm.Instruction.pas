unit Wasm.Instruction;

interface

uses
  System.Classes, System.SysUtils;

{$T+}
{$SCOPEDENUMS ON}

type
  TOp = record
    code: Integer;
    name: string;
    function From(code: Integer; const name: string): Integer;
  end;

implementation

{ TOp }

function TOp.From(code: Integer; const name: string): Integer;
begin

end;

end.

