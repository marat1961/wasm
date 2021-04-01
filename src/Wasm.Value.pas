unit Wasm.Value;

interface

uses
  System.Classes, System.SysUtils;

{$T+}
{$SCOPEDENUMS ON}

type

  TValue = record
  public
    function AsInt32: Int32;
    function AsUint32: Uint32;
    function AsUint64: Uint64;
    function AsInt64: Int64;
    function AsSingle: Single;
    function AsDouble: Double;
  private
    case Integer of
      1: (i32: Uint32);
      2: (i64: Uint64);
      3: (f32: Single);
      4: (f64: Double);
  end;

implementation

function TValue.AsInt32: Int32;
begin
  Result := i64;
end;

function TValue.AsUint32: Uint32;
begin
  Result := i32;
end;

function TValue.AsInt64: Int64;
begin
  Result := i64;
end;

function TValue.AsUint64: Uint64;
begin
  Result := i64;
end;

function TValue.AsSingle: Single;
begin
  Result := f64;
end;

function TValue.AsDouble: Double;
begin
  Result := f64;
end;

end.
