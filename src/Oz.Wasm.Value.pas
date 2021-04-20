(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Value;

interface

uses
  System.SysUtils;

{$T+}
{$SCOPEDENUMS ON}

{$Region 'WasmError'}

type
  EWasmError = class(Exception)
  const
    NotImplemented = 0;
    EofEncounterd = 1;
    InvalidSize = 2;
  public
    constructor Create(ErrNo: Integer); overload;
  end;

{$EndRegion}

{$Region 'TValue'}

  PValue = ^TValue;
  TValue = record
  public
    constructor From(v: Uint64); overload;
    constructor From(v: Uint32); overload;
    function AsInt32: Int32;
    function AsUint32: Uint32;
    function AsUint64: Uint64;
    function AsInt64: Int64;
    function AsSingle: Single;
    function AsDouble: Double;
  var
    case Integer of
      1: (i32: Uint32);
      2: (i64: Uint64);
      3: (f32: Single);
      4: (f64: Double);
  end;

{$EndRegion}

implementation

{$Region 'WasmError'}

constructor EWasmError.Create(ErrNo: Integer);
var Msg: string;
begin
  case ErrNo of
    NotImplemented: Msg := 'not implemented';
    EofEncounterd: Msg := 'eof encounterd';
    InvalidSize: Msg := 'invalid size';
    else Msg := 'Error: ' + IntToStr(ErrNo);
  end;
  Create(Msg);
end;

{$EndRegion}

{$Region 'TValue'}

constructor TValue.From(v: Uint64);
begin
  Self.i64 := v;
end;

constructor TValue.From(v: Uint32);
begin
  Self.i32 := v;
end;

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

{$EndRegion}

end.

