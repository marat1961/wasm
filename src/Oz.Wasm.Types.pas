(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Types;

interface

uses
  System.Classes, System.SysUtils, Oz.Wasm.Utils, Oz.Wasm.Value;

{$T+}
{$SCOPEDENUMS ON}

const
  // table-types
  FuncRef: Byte = $70;

type

  // Value types
  TValType = (
    none = 0,
    i32 = $7f,
    i64 = $7e,
    f32 = $7d,
    f64 = $7c);

  // Instruction signature. Wasm 1.0 spec only has instructions
  // which take at most 2 parameters and return at most 1 result.
  TInstructionType = record
    inputs: array [0..1] of TValType;
    outputs: TValType;
    function inputsSize: Uint32;
    function outputsSize: Uint32;
  end;

  // Function types classify the signature of functions,
  // mapping a vector of parameters to a vector of results.
  // They are also used to classify the inputs and outputs of instructions.
  TFuncType = record
    inputs: TArray<TValType>;
    outputs: TArray<TValType>;
    constructor From(const ityp: TInstructionType);
    function Equals(const sinputs, soutputs: TSpan<TValType>): Boolean; overload;
    function Equals(const ft: TFuncType): Boolean; overload;
    class function EqualTypes(const a: TArray<TValType>; b: TSpan<TValType>): Boolean; static;
  end;

  // Limits classify the size range of resizeable storage
  // associated with memory types and table types.
  // If no maximum is given, the respective storage can grow to any size.
  TLimits = record
    min: Uint32;
    max: Uint32;
  end;

  // All indices are encoded with their respective value.
  type TTypeIdx = Uint32;
  type TFuncIdx = Uint32;
  type TTableIdx = Uint32;
  type TMemIdx = Uint32;
  type TGlobalIdx = Uint32;
  type TLocalIdx = Uint32;

  // Code Section
  // Each section consists of
  //  * a one-byte section id,
  //  * the u32 size of the contents, in bytes,
  //  * the actual contents, whose structure is depended on the section id.
  // Every section is optional; an omitted section is equivalent to the section
  // being present with empty contents.

  // The following section ids are used:
  // --------------------
  // Id  Section
  // --------------------
  //  0  custom section
  //  1  type section
  //  2  import section
  //  3  function section
  //  4  table section
  //  5  memory section
  //  6  global section
  //  7  export section
  //  8  start section
  //  9  element section
  // 10  code section
  // 11  data section
  // 12  data count section
  // --------------------

  TSectionId = (
    custom = 0,
    &type = 1,
    import = 2,
    &function = 3,
    table = 4,
    memory = 5,
    global = 6,
    &export = 7,
    start = 8,
    element = 9,
    code = 10,
    data = 11);

  // Function locals.
  TLocals = record
    count: Uint32;
    typ: TValType;
  end;

  TTable = record
    limits: TLimits;
  end;

  TMemory = record
    limits: TLimits;
  end;

  TConstantExpression = record
  type
    TKind = (Constant, GlobalGet);
  var
    kind: TKind;
    case Integer of
      0: (constant: TValue);
      1: (globalIndex: Uint32);
  end;

  TGlobalType = record
    valueType: TValType;
    isMutable: Boolean;
  end;

  TGlobal = record
    typ: TGlobalType;
    expression: TConstantExpression;
  end;

  TExternalKind = (
    &Function = $00,
    Table = $01,
    Memory = $02,
    Global = $03);

  TDescUnion = record
    case Integer of
      0: (functionTypeIndex: TTypeIdx);
      1: (memory: TMemory);
      2: (global: TGlobalType);
      3: (table: TTable);
  end;

  TImport = record
    module: string;
    name: string;
    kind: TExternalKind;
    desc: TDescUnion;
  end;

  TExport = record
    name: string;
    kind: TExternalKind;
    index: Uint32;
  end;

  TElement = record
    offset: TConstantExpression;
    init: TArray<TFuncIdx>;
  end;

  // The element of the code section.
  TCode = record
    maxStackHeight: Integer;
    localCount: Uint32;
    // The instructions bytecode interleaved with decoded immediate values.
    instructions: TArray<Byte>;
  end;

  // The memory index is omitted from the recordure as the parser ensures it to be 0
  TData = record
    offset: TConstantExpression;
    init: TBytes;
  end;

implementation

{$Region 'TInstructionType'}

function TInstructionType.inputsSize: Uint32;
begin
  Result := Ord(inputs[0] <> TValType.none) + Ord(inputs[1] <> TValType.none);
end;

function TInstructionType.outputsSize: Uint32;
begin
  Result := Ord(outputs <> TValType.none);
end;

{$EndRegion}

{$Region 'TFuncType'}

constructor TFuncType.From(const ityp: TInstructionType);
begin
  var n := ityp.inputsSize;
  SetLength(inputs, n);
  for var i := 0 to ityp.inputsSize - 1 do
    inputs[i] := ityp.inputs[i];
  if ityp.outputs <> TValType.none then
    outputs[0] := ityp.outputs;
end;

function TFuncType.Equals(const ft: TFuncType): Boolean;
begin
  Result := (High(inputs) = High(ft.inputs)) and (High(outputs) = High(ft.outputs));
  if Result then
  begin
    for var i := 0 to High(inputs) do
      if inputs[i] <> ft.inputs[i] then
        exit(False);
    for var i := 0 to High(outputs) do
      if outputs[i] <> ft.outputs[i] then
        exit(False);
  end;
end;

function TFuncType.Equals(const sinputs, soutputs: TSpan<TValType>): Boolean;
begin
  Result := EqualTypes(inputs, sinputs) and EqualTypes(outputs, soutputs);
end;

class function TFuncType.EqualTypes(const a: TArray<TValType>; b: TSpan<TValType>): Boolean;
begin
  Result := Length(a) = b.Size;
  if Result then
    for var i := 0 to High(a) do
      if a[i] <> b.Items[i] then
        exit(False);
end;

{$EndRegion}

end.

