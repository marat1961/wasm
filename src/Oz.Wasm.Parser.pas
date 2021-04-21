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
  strict private
    buf: TInputBuffer;
  private
    function parseByte: Byte; inline;
    function parseValue<T: record>: T; inline;
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
    //
    function parseVec<T>: TArray<T>;
    // Validates and converts the given byte to valtype.
    function validateValtype(v: Byte): TValType;
    // Validates constant expression
    procedure validateConstantExpression(const expr: TConstantExpression;
      const module: TModule; expectedTtype: TValType);
    // Parse code
    function parseCode(codeBinary: TCodeView; funcIdx: TFuncIdx; 
      const module: TModule): TCode;
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

  procedure checkPrefix;
  begin
    var prefix := TBytesView.From(@WasmPrefix[0], sizeof(WasmPrefix));
    if not buf.startsWith(prefix) then
      raise EWasmError.Create('invalid wasm module prefix');
    buf.skip(sizeof(WasmPrefix));
  end;

var 
  module: PModule;
  id: TSectionId;
  codeBinaries: TArray<TCodeView>;
  lastId: TSectionId;
  expectedSectionEnd: PByte;
  size: Uint32;
  exportNames: TDictionary<string, Integer>;
begin
  buf := TInputBuffer.From(input);
  checkPrefix;
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
        module.typesec := parseVec<TFuncType>;
      TSectionId.import:
        module.importsec := parseVec<TImport>;
      TSectionId.function:
        module.funcsec := parseVec<TTypeIdx>;
      TSectionId.table:
        module.tablesec := parseVec<TTable>;
      TSectionId.memory:
        module.memorysec := parseVec<TMemory>;
      TSectionId.global:
        module.globalsec := parseVec<TGlobal>;
      TSectionId.export:
        module.exportsec := parseVec<TExport>;
      TSectionId.start:
        module.startfunc := TOptional<TFuncIdx>.From(TFuncIdx(buf.readUint32));
      TSectionId.element:
        module.elementsec := parseVec<TElement>;
      TSectionId.code:
        codeBinaries := parseVec<TCodeView>;
      TSectionId.data:
        module.datasec := parseVec<TData>;
      TSectionId.custom:
        begin
          // NOTE: this section can be ignored, but the name must be parseable (and valid UTF-8)
          parseString;
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

function TWasmParser.parseByte: Byte;
begin
  Result := buf.readByte;
end;

function TWasmParser.parseCode(codeBinary: TCodeView; funcIdx: TFuncIdx;
  const module: TModule): TCode;
begin

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

function TWasmParser.parseVec<T>: TArray<T>;
begin

end;

procedure TWasmParser.validateConstantExpression(const expr: TConstantExpression;
  const module: TModule; expectedTtype: TValType);
begin

end;

function TWasmParser.validateValtype(v: Byte): TValType;
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

