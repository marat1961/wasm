(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Parser;

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, 
  Oz.Wasm.Utils, Oz.Wasm.Buffer, Oz.Wasm.Value, Oz.Wasm.Limits, Oz.Wasm.Instruction, 
  Oz.Wasm.Types, Oz.Wasm.Module, Oz.Wasm.ParseExpression;

{$T+}
{$SCOPEDENUMS ON}

type
  TCodeView = TBytesView;

{$Region 'TWasmParser'}

  TWasmParser = record
  const
    WasmPrefix: array [0..7] of Byte = ($00, $61, $73, $6d, $01, $00, $00, $00);
  private
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

// Parses a string and validates it against UTF-8 encoding rules
function parseString(var buf: TInputBuffer): System.UTF8String;
begin
  Result := buf.readUTF8String;
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

function parseValType(var buf: TInputBuffer): TValType;
begin
  Result := validateValtype(buf.readByte);
end;

function parseLimits(var buf: TInputBuffer): TLimits;
begin
  var kind := buf.readByte;
  case kind of
    $00:
      begin
        Result.min := buf.readUint32;
        Result.max.Reset;
      end;
    $01:
      begin
        Result.min := buf.readUint32;
        Result.max := TOptional<Uint32>.From(buf.readUint32);
        if Result.min > Result.max.value then
          raise EWasmError.Create('malformed limits (minimum is larger than maximum)');
      end;
    else
      raise EWasmError.CreateFmt('invalid limits %d', [kind]);
  end;
end;

function parseTable(var buf: TInputBuffer): TTable;
begin
  var elemtype := buf.readByte;
  if elemtype <> FuncRef then
    raise EWasmError.CreateFmt('unexpected table elemtype: %d', [elemtype]);
  Result.limits := parseLimits(buf);
end;

function parseMemory(var buf: TInputBuffer): TMemory;
begin
  Result.limits := parseLimits(buf);
  if (Result.limits.min > MaxMemoryPagesLimit) or
     (Result.limits.max.hasValue and (Result.limits.max.value > MaxMemoryPagesLimit)) then
    raise EWasmError.Create('maximum memory page limit exceeded');
end;

function parseConstantExpression(var buf: TInputBuffer; 
  expectedType: TValType): TConstantExpression;
begin
  // Module is needed to know the type of globals accessed with global.get,
  // therefore here we can validate the type only for const instructions.
  var constantActualType := TValType.none;
  var opcode := buf.readByte;

  var instr := TInstruction(opcode);
  case instr of
    TInstruction.end:
      raise EWasmError.Create('constant expression is empty');
    TInstruction.global_get:
      begin
        Result.kind := TConstantExpression.TKind.GlobalGet;
        Result.globalIndex := buf.readUint32;
      end;
    TInstruction.i32_const:
      begin
        Result.kind := TConstantExpression.TKind.Constant;
        var value := buf.readUint32;
        Result.constant.i32 := value;
        constantActualType := TValType.i32;
      end;
    TInstruction.i64_const:
      begin
        Result.kind := TConstantExpression.TKind.Constant;
        var value := buf.readUint32;
        Result.constant.i64 := Uint64(value);
        constantActualType := TValType.i64;
      end;
    TInstruction.f32_const:
      begin
        Result.kind := TConstantExpression.TKind.Constant;
        Result.constant.f32 := buf.readValue<Uint32>;
        constantActualType := TValType.f32;
      end;
    TInstruction.f64_const:
      begin
        Result.kind := TConstantExpression.TKind.Constant;
        Result.constant.f64 := buf.readValue<Uint64>;
        constantActualType := TValType.f64;
      end;
    else
      raise EWasmError.CreateFmt(
        'unexpected instruction in the constant expression: %d', [buf.current - 1]);
  end;

  var endOpcode := buf.readByte;

  if TInstruction(endOpcode) <> TInstruction.end then
    raise EWasmError.Create('constant expression has multiple instructions');

  if (constantActualType = TValType.none) and (constantActualType <> expectedType) then
    raise EWasmError.Create('constant expression type mismatch');
end;

function parseGlobalType(var buf: TInputBuffer): TGlobalType;
begin
  Result.valueType := parseValType(buf);
  var mutability := buf.readByte;
  if not (mutability in [0, 1]) then
    raise EWasmError.CreateFmt(
      'unexpected byte value, expected 0 or 1 for global mutability', [mutability]);
  Result.isMutable := Boolean(mutability);
end;

function parseGlobal(var buf: TInputBuffer): TGlobal;
begin
  Result.typ := parseGlobalType(buf);
  Result.expression := parseConstantExpression(buf, Result.typ.valueType);
end;

function parseImport(var buf: TInputBuffer): TImport;
begin
  Result.module := buf.readString;
  Result.name := buf.readString;
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
        Result.desc.global := parseGlobalType(buf);
      end;
    else
      raise EWasmError.CreateFmt('unexpected import kind value %d', [kind]);
  end;
end;

function parseTypeIdx(var buf: TInputBuffer): TTypeIdx; inline;
begin
  Result := buf.readUint32;
end;

function parseVecFuncIdx(var buf: TInputBuffer): TArray<TFuncIdx>; inline;
begin
  Result := parseVec32(buf);  
end;

function parseExport(var buf: TInputBuffer): TExport;
begin
  Result.name := buf.readString;
  var kind := buf.readByte;
  case kind of
    $00:
      Result.kind := TExternalKind.Function;
    $01:
      Result.kind := TExternalKind.Table;
    $02:
      Result.kind := TExternalKind.Memory;
    $03:
      Result.kind := TExternalKind.Global;
    else
      raise EWasmError.CreateFmt('unexpected export kind value %d', [kind]);
  end;
  Result.index := buf.readUint32;
end;

function parseElement(var buf: TInputBuffer): TElement;
begin
  var table_index: TTableIdx := buf.readUint32;
  if table_index <> 0 then
    raise EWasmError.CreateFmt(
      'invalid table index %d (only table 0 is allowed)', [table_index]);

  // Offset expression is required to have i32 result value
  // https://webassembly.github.io/spec/core/valid/modules.html#element-segments
  Result.offset := parseConstantExpression(buf, TValType.i32);
  Result.init := parseVecFuncIdx(buf);
end;

function parseCodeView(var buf: TInputBuffer): TCodeView;
begin
  var codeSize := buf.readUint32;
  var codeBegin := buf.current;
  if codeBegin + codeSize > buf.ends then
    raise EWasmError.Create('unexpected EOF');
  // Only record the code reference in wasm binary.
  Result := TCodeView.From(codeBegin, codeSize);
end;

function parseFuncType(var buf: TInputBuffer): TFuncType;
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

function parseData(var buf: TInputBuffer): TData;
begin
  var memoryIndex := buf.readUint32;
  if memoryIndex <> 0 then
    raise EWasmError.CreateFmt(
      'invalid memory index %d (only memory 0 is allowed)', [memoryIndex]);
  // Offset expression is required to have i32 result value
  // https://webassembly.github.io/spec/core/valid/modules.html#data-segments
  Result.offset := parseConstantExpression(buf, TValType.i32);
  Result.init := buf.readBytes;
end;

function parseLocals(var buf: TInputBuffer): TLocals;
begin
  Result.count := buf.readUint32;
  Result.typ := parseValType(buf);
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
  for var v in localsVec do
  begin
    Inc(localCount, v.count);
    if localCount > Uint32.MaxValue then
      raise EWasmError.Create('too many local variables');
  end;

  Assert(localCount + Uint64(Length(module.typesec[module.funcsec[funcIdx]].inputs)) <= Uint32.MaxValue);
  var code := parseExpr(b, funcIdx, localsVec, module);

  // Size is the total bytes of locals and expressions.
  if b.current <> b.ends then
    raise EWasmError.Create('malformed size field for function');

  code.localCount := Uint32(localCount);
  Result := code;
end;

{$EndRegion}

end.

