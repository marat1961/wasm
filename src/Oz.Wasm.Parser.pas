(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Parser;

interface

uses
  Oz.Wasm.Utils, Oz.Wasm.Value, Oz.Wasm.Module;

{$T+}
{$SCOPEDENUMS ON}

{$Region 'TWasmParser'}

type
  TParserResult<T> = record
    first: PByte;
    second: T;
  end;

  TWasmParser = record
  private
    function parseByte(const pos, ends: PByte): TParserResult<Byte>; inline;
    function parseValue<T: record>(const pos, ends: PByte): TParserResult<T>; inline;
    procedure raiseEOF;
  public
    // Parses input` into a Module.
    //  input    The WebAssembly binary. No need to persist by the caller,
    //           since all relevant parts will be copied.
    //  returns  The parsed module.
    function parse(input: TBytesView): PModule;
  end;

{$EndRegion}

implementation

{$Region 'TWasmParser'}

function TWasmParser.parse(input: TBytesView): PModule;
begin

end;

procedure TWasmParser.raiseEOF;
begin
  raise WasmError.Create('unexpected EOF');
end;

function TWasmParser.parseByte(const pos, ends: PByte): TParserResult<Byte>;
begin
  if pos >= ends then raiseEOF;
  Result.first := pos + 1;
  Result.second := pos^;
end;

function TWasmParser.parseValue<T>(const pos, ends: PByte): TParserResult<T>;
type
  Pt = ^T;
var
  size: Uint32;
begin
  size := sizeof(T);
  if ends - pos < size then raiseEOF;
  Result.first := pos + size;
  Result.second := Pt(pos)^;
end;

{$EndRegion}

end.

