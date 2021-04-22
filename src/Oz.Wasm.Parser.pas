(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Parser;

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections,
  Oz.Wasm.Utils, Oz.Wasm.Value, Oz.Wasm.Buffer,  Oz.Wasm.Types, Oz.Wasm.Module;

{$T+}
{$SCOPEDENUMS ON}

type
  TCodeView = TBytesView;

{$Region 'TWasmParser'}

  TWasmParser = record
  const
    WasmPrefix: array [0..7] of Byte = ($00, $61, $73, $6d, $01, $00, $00, $00);
  private
    // Validates and converts the given byte to valtype.
    class function validateValtype(v: Byte): TValType; static;
    // Validates constant expression
    procedure validateConstantExpression(const expr: TConstantExpression;
      const module: TModule; expectedTtype: TValType);
    // Parse code
    function parseCode(codeBinary: TCodeView; funcIdx: TFuncIdx;
      const module: TModule): TCode;
  public
    // Parses input into a Module.
    // parameters:
    //   input    The WebAssembly binary. No need to persist by the caller,
    //            since all relevant parts will be copied.
    //   returns  The parsed module.
    function parse(input: TBytesView): PModule;
  end;

{$EndRegion}

implementation

function parseVec32(const buf: TInputBuffer): TArray<Uint32>;
var
  size: UInt32;
begin
  size := buf.readUint32;
  Assert(size < 128);
  SetLength(result, size);
  for var i := 0 to size - 1 do
    Result[i] := buf.readUint32;
end;

// Parses a string and validates it against UTF-8 encoding rules
function parseString(const buf: TInputBuffer): System.UTF8String;
begin
  Result := buf.readUTF8String;
end;

function parseValType(const buf: TInputBuffer): TValType;
begin
  Result := TWasmParser.validateValtype(buf.readByte);
end;

function parseLimits(const buf: TInputBuffer): TLimits;
begin
  var kind := buf.readByte;
  case kind of
    $00:
      begin
        result.min := buf.readUint32;
        result.max.Reset;
      end;
    $01:
      begin
        result.min := buf.readUint32;
        result.max := TOptional<Uint32>.From(buf.readUint32);
        if result.min > result.max.value then
          raise EWasmError.Create('malformed limits (minimum is larger than maximum)');
      end;
    else
      raise EWasmError.CreateFmt('invalid limits %d', [kind]);
  end;
end;

function parseTable(const buf: TInputBuffer): TTable;
begin
  var elemtype := buf.readByte;
  if elemtype <> FuncRef then
    raise EWasmError.CreateFmt('unexpected table elemtype: %d', [elemtype]);
  Result.limits := parseLimits(buf);
end;

function parseMemory(const buf: TInputBuffer): TMemory;
begin

end;

function parseGlobal(const buf: TInputBuffer): TGlobal;
begin

end;

function parseImport(const buf: TInputBuffer): TImport;
begin
  result.module := buf.readString;
  result.name := buf.readString;
  var kind := buf.readByte;
  case kind of
    $00:
      begin
        Result.kind := TExternalKind.Function;
        Result.desc.functionTypeIndex := buf.readUint32;
      end;
    $01:
      begin
        Result.kind := TExternalKind.Table;
        Result.desc.table := parseTable(buf);
      end;
    $02:
      begin
        Result.kind := TExternalKind.Memory;
        Result.desc.memory := parseMemory(buf);
      end;
    $03:
      begin
        Result.kind := TExternalKind.Global;
        Result.desc.global := buf.readValue<TGlobalType>;
      end;
    else
      raise EWasmError.CreateFmt('unexpected import kind value %d', [kind]);
  end;
end;

function parseTypeIdx(const buf: TInputBuffer): TTypeIdx;
begin

end;

function parseExport(const buf: TInputBuffer): TExport;
begin

end;

function parseElement(const buf: TInputBuffer): TElement;
begin

end;

function parseCodeView(const buf: TInputBuffer): TCodeView;
begin

end;

function parseFuncType(const buf: TInputBuffer): TFuncType;
begin
  var kind := buf.readByte;
  if kind <> $60 then
    raise EWasmError.CreateFmt(
      'unexpected byte value %d , expected $60 for functype', [Ord(kind)]);
  Result.inputs := buf.readArray<TValType>(parseValType);
  Result.outputs := buf.readArray<TValType>(parseValType);
  if Length(Result.outputs) > 1 then
    raise EWasmError.Create('function has more than one result');
end;

function parseData(const buf: TInputBuffer): TData;
begin

end;

function parseLocals(const buf: TInputBuffer): TLocals;
begin

end;

// Parses 'expr', i.e. a function's instructions residing in the code section.
// https://webassembly.github.io/spec/core/binary/instructions.html#binary-expr
// parameters:
//   buf       Input buffer.
//   funcIdx   Index of the function being parsed.
//   locals    Vector of local type and counts for the function being parsed.
//   module    Module that this code is part of.
//   returns   The parsed code.
function parseExpr(buf: TInputBuffer; funcIidx: TFuncIdx;
  const locals: TArray<TLocals>; const module: TModule): TCode;
begin

end;

{$Region 'TWasmParser'}

function TWasmParser.parse(input: TBytesView): PModule;
var
  buf: TInputBuffer;
  module: PModule;
  id: TSectionId;
  codeBinaries: TArray<TCodeView>;
  lastId: TSectionId;
  expectedSectionEnd: PByte;
  size: Uint32;
  exportNames: TDictionary<string, Integer>;
begin
  buf := TInputBuffer.From(input);

  var prefix := TBytesView.From(@WasmPrefix[0], sizeof(WasmPrefix));
  if not buf.startsWith(prefix) then
    raise EWasmError.Create('invalid wasm module prefix');
  buf.skip(sizeof(WasmPrefix));

  module := GetMemory(sizeof(TModule));

  lastId := TSectionId.custom;
  while not buf.Eof do
  begin
    id := TSectionId(buf.readByte);
    if id <> TSectionId.custom then
    begin
      if id <= lastId then
        raise EWasmError.Create('unexpected out-of-order section type');
      lastId := id;
    end;

    size := buf.readUint32;
    buf.checkUnread(size);
    expectedSectionEnd := buf.current + size;
    case id of
      TSectionId.type:
        module.typesec := buf.readArray<TFuncType>(parseFuncType);
      TSectionId.import:
        module.importsec := buf.readArray<TImport>(parseImport);
      TSectionId.function:
        module.funcsec := buf.readArray<TTypeIdx>(parseTypeIdx);
      TSectionId.table:
        module.tablesec := buf.readArray<TTable>(parseTable);
      TSectionId.memory:
        module.memorysec := buf.readArray<TMemory>(parseMemory);
      TSectionId.global:
        module.globalsec := buf.readArray<TGlobal>(parseGlobal);
      TSectionId.export:
        module.exportsec := buf.readArray<TExport>(parseExport);
      TSectionId.start:
        module.startfunc := TOptional<TFuncIdx>.From(TFuncIdx(buf.readUint32));
      TSectionId.element:
        module.elementsec := buf.readArray<TElement>(parseElement);
      TSectionId.code:
        codeBinaries := buf.readArray<TCodeView>(parseCodeView);
      TSectionId.data:
        module.datasec := buf.readArray<TData>(parseData);
      TSectionId.custom:
        begin
          // NOTE: this section can be ignored, but the name must be parseable (and valid UTF-8)
          parseString(buf);
          // These sections are ignored for now.
          buf.skip(size);
        end
      else
        raise EWasmError.CreateFmt('unknown section encountered %d', [Ord(id)]);
    end;
    if buf.current <> expectedSectionEnd then
      raise EWasmError.CreateFmt('incorrect section %d size, difference: %d',
        [Ord(id), buf.current - expectedSectionEnd]);
  end;

  // Validation checks

  // Split imports by kind
  for var import in module.importsec do
  begin
    case import.kind of
      TExternalKind.Function:
        begin
          if import.desc.functionTypeIndex >= Length(module.typesec) then
            raise EWasmError.Create('invalid type index of an imported function');
          module.importedFunctionTypes := module.importedFunctionTypes
            + [module.typesec[import.desc.functionTypeIndex]];
        end;
      TExternalKind.Table:
        module.importedTableTypes := module.importedTableTypes + [import.desc.table];
      TExternalKind.Memory:
        module.importedMemoryTypes := module.importedMemoryTypes + [import.desc.memory];
      TExternalKind.Global:
        module.importedGlobalTypes := module.importedGlobalTypes  + [import.desc.global];
      else
        raise EWasmError.Create('unreachable');
    end;
  end;

  for var typeIdx in module.funcsec do
    if typeIdx >= Length(module.typesec) then
      raise EWasmError.Create('invalid function type index');

  if Length(module.tablesec) > 1 then
    raise EWasmError.Create('too many table sections (at most one is allowed)');

  if Length(module.memorysec) > 1 then
    raise EWasmError.Create('too many memory sections (at most one is allowed)');

  if Length(module.importedMemoryTypes) > 1 then
    raise EWasmError.Create('too many imported memories (at most one is allowed)');

  if (Length(module.memorysec) > 0) and (Length(module.importedMemoryTypes) > 0) then
    raise EWasmError.Create(
      'both module memory and imported memory are defined' +
      '(at most one of them is allowed)');

  if (Length(module.datasec) <> 0) and not module.hasMemory then
    raise EWasmError.Create(
      'invalid memory index 0 (data section encountered without a memory section)');

  for var data in module.datasec do
    // Offset expression is required to have i32 result value
    // https://webassembly.github.io/spec/core/valid/modules.html#data-segments
    validateConstantExpression(data.offset, module^, TValType.i32);

  if Length(module.importedTableTypes) > 1 then
    raise EWasmError.Create('too many imported tables (at most one is allowed)');

  if (Length(module.tablesec) > 0) and (Length(module.importedTableTypes) > 0) then
    raise EWasmError.Create(
      'both module table and imported table are defined (at most one of them is allowed)');

  if (Length(module.elementsec) > 0) and not module.hasTable then
    raise EWasmError.Create(
      'invalid table index 0 (element section encountered without a table section)');

  var total_func_count := module.getFunctionCount;

  for var element in module.elementsec do
  begin
    // Offset expression is required to have i32 result value
    // https://webassembly.github.io/spec/core/valid/modules.html#element-segments
    validateConstantExpression(element.offset, module^, TValType.i32);
    for var funcIdx in element.init do
      if funcIdx >= total_func_count then
        raise EWasmError.Create('invalid function index in element section');
  end;

  var totalGlobalCount := module.getGlobalCount;
  for var global in module.globalsec do
  begin
    validateConstantExpression(global.expression, module^, global.typ.valueType);

    // Wasm spec section 3.3.7 constrains initialization by another global to const imports only
    // https://webassembly.github.io/spec/core/valid/instructions.html#expressions
    if (global.expression.kind = TConstantExpression.TKind.GlobalGet) and
       (global.expression.globalIndex >= Length(module.importedGlobalTypes)) then
      raise EWasmError.Create(
        'global can be initialized by another const global only if it''s imported');
  end;

  if Length(module.funcsec) <> Length(codeBinaries) then
    raise EWasmError.Create(
      'malformed binary: number of function and code entries must match');

  // Validate exports.
  exportNames := TDictionary<string, Integer>.Create;
  try
    for var e in module.exportsec do
    begin
      case e.kind of
        TExternalKind.Function:
          if e.index >= total_func_count then
            raise EWasmError.Create('invalid index of an exported function');
        TExternalKind.Table:
          if (e.index <> 0) or not module.hasTable then
            raise EWasmError.Create('invalid index of an exported table');
        TExternalKind.Memory:
          if (e.index <> 0) or not module.hasMemory then
            raise EWasmError.Create('invalid index of an exported memory');
        TExternalKind.Global:
          if e.index >= totalGlobalCount then
            raise EWasmError.Create('invalid index of an exported global');
        else
          raise EWasmError.Create('unreachable');
      end;
      if exportNames.ContainsKey(e.name) then
        raise EWasmError.Create('duplicate export name ' + e.name);
      exportNames. AddOrSetValue(e.name, 0);
    end;
  finally
    exportNames.Free;
  end;

  if module.startfunc.hasValue then
  begin
    if module.startfunc.value >= total_func_count then
      raise EWasmError.Create('invalid start function index');

    var func_type := module.getFunctionType(module.startfunc.value);
    if (Length(func_type.inputs) > 0) or (Length(func_type.outputs) > 0) then
      raise EWasmError.Create('invalid start function type');
  end;

  // Process code.
  SetLength(module.codesec, Length(codeBinaries));
  for var i := 0 to Length(codeBinaries) - 1 do
  begin
    var code := parseCode(codeBinaries[i], TFuncIdx(i), module^);
    module.codesec := module.codesec + [code];
  end;

  Result := module;
end;

function TWasmParser.parseCode(codeBinary: TCodeView; funcIdx: TFuncIdx;
  const module: TModule): TCode;
var
  localCount: Uint64;
  b: TInputBuffer;
begin
  b := TInputBuffer.From(codeBinary);
  var localsVec := b.readArray<TLocals>(parseLocals);

  localCount := 0;
  for var l in localsVec do
  begin
    Inc(localCount, l.count);
    if localCount > Uint32.MaxValue then
      raise EWasmError.Create('too many local variables');
  end;

  Assert(localCount + Length(module.typesec[module.funcsec[funcIdx]].inputs) <= Uint32.MaxValue);
  var code := parseExpr(b, funcIdx, localsVec, module);

  // Size is the total bytes of locals and expressions.
  if b.current <> b.ends then
    raise EWasmError.Create('malformed size field for function');

  code.localCount := Uint32(localCount);
  Result := code;
end;

procedure TWasmParser.validateConstantExpression(const expr: TConstantExpression;
  const module: TModule; expectedTtype: TValType);
begin

end;

class function TWasmParser.validateValtype(v: Byte): TValType;
begin
  if InRange(v, $7C, $7F) then
    Result := TValType(v)
  else
    raise EWasmError.CreateFmt('invalid TValType %d', [v]);
end;

procedure validateConstantExpression(const expr: TConstantExpression;
  const module: TModule; expectedTtype: TValType);
begin
  if expr.kind = TConstantExpression.TKind.Constant then exit;
  var globalIdx := expr.globalIndex;
  if globalIdx >= module.getGlobalCount then
    raise EWasmError.Create('invalid global index in constant expression');
  var globalType := module.getGlobalType(globalIdx);
  if globalType.isMutable then
    raise EWasmError.Create('constant expression can use global.get only for const globals');
  if globalType.valueType <> expectedTtype then
    raise EWasmError.Create('constant expression type mismatch');
end;

{$EndRegion}

end.

