(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Value;

interface

{$T+}
{$SCOPEDENUMS ON}

type

  PValue = ^TValue;
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
  Result := f32;
end;

function TValue.AsDouble: Double;
begin
  Result := f64;
end;

end.

