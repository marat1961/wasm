(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Parser;

interface

uses
  System.SysUtils, System.Math, Oz.Wasm.Utils, Oz.Wasm.Value, Oz.Wasm.Buffer, 
  Oz.Wasm.Types, Oz.Wasm.Module;

{$T+}
{$SCOPEDENUMS ON}

type

{$Region 'TWasmParser'}

  TWasmParser = record
  strict private
    buf: TInputBuffer;
  private 
    //
    function parseByte: Byte; inline;
    // 
    function parseValue<T: record>: T;
    // Parses 'expr', i.e. a function's instructions residing in the code section.
    // https://webassembly.github.io/spec/core/binary/instructions.html#binary-expr
    // parameters:
    //   pos       The beginning of the expr binary input.
    //   ends      The end of the binary input.
    //   funcIdx   Index of the function being parsed.
    //   locals    Vector of local type and counts for the function being parsed.
    //   module    Module that this code is part of.
    //   returns   The parsed code.
    function parseExpr(funcIidx: TFuncIdx; const locals: TArray<TLocals>; 
      const module: TModule): TCode;
    // Parses a string and validates it against UTF-8 encoding rules.
    // parameters:
    //   pos      The beginning of the string input.
    //   ends     The end of the string input.
    //   returns  The parsed and UTF-8 validated string.
    function parseString: System.UTF8String;
    // Parses the vec of i32 values. This is used in parseExpr.
    function parseVec32: TArray<Uint32>;
    // Validates and converts the given byte to valtype.
    function validateValtype(v: Byte): TValType;
  public
    // Parses input into a Module.
    // parameters:
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

function TWasmParser.parseByte: Byte;
begin
  Result := buf.readByte;
end;

function TWasmParser.parseValue<T>: T;
begin
  Result := buf.readValue<T>;
end;

function TWasmParser.parseExpr(funcIidx: TFuncIdx; const locals: TArray<TLocals>; 
  const module: TModule): TCode;
begin

end;

function TWasmParser.parseString: System.UTF8String;
begin

end;

function TWasmParser.parseVec32: TArray<Uint32>;
begin
end;

function TWasmParser.validateValtype(v: Byte): TValType;
begin
  if InRange(v, $7C, $7F) then
    Result := TValType(v)
  else
    raise EWasmError.CreateFmt('invalid TValType %d', [v]);
end;

{$EndRegion}

end.

