(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Instantiate;

interface

uses
  System.SysUtils, System.Math, Oz.Wasm.Utils, Oz.Wasm.Limits, Oz.Wasm.Module,
  Oz.Wasm.Value, Oz.Wasm.Types, Oz.Wasm.Instruction;

{$T+}
{$SCOPEDENUMS ON}

type

  WasmError = class(Exception);

{$Region 'TExecutionResult: The result of an execution'}

  TExecutionResult = record
    // This is true if the execution has trapped.
    trapped: Boolean;
    // This is true if value contains valid data.
    hasValue: Boolean;
    // The result value. Valid if `hasValue = true`.
    value: TValue;
    // Constructs result with a value.
    constructor From(const value: TValue); overload;
    // Constructs result in "void" or "trap" state depending on the success flag.
    // Prefer using Void and Trap constants instead.
    constructor From(success: Boolean); overload;
  end;
const
  BranchImmediateSize = 2 * sizeof(Uint32);
  // Shortcut for execution that resulted in successful execution,
  // but without a result.
  Void: TExecutionResult = (hasValue: False);
  // Shortcut for execution that resulted in a trap.
  Trap: TExecutionResult = (trapped: True);

{$EndRegion}

{$Region 'TExecutionContext: execution context'}

type
  // The storage for information shared by calls in the same execution "thread".
  // Users may decide how to allocate the execution context,
  // but some good defaults are available.
  TExecutionContext = class
  type
    // Call depth increment guard.
    // It will automatically decrement the call depth to the original value
    // when going out of scope.
    TGuard = class
      // Reference to the guarded execution context.
      FExecutionContext: TExecutionContext;
      constructor Create(ctx: TExecutionContext);
      destructor Destroy; override;
    end;
  var
    depth: Integer;  // Current call depth.
  public
    // Increments the call depth and returns the guard object which decrements
    // the call depth back to the original value when going out of scope.
    function IncrementCallDepth: TGuard;
  end;

{$EndRegion}

{$Region 'TTableElement: Table element, which references a function in any instance'}

  PInstance = ^TInstance;
  PTableElement = ^TTableElement;
  TTableElement = record
    // Pointer to function's instance or nullptr when table element is not initialized.
    instance: PInstance;
    // Index of the function in instance.
    funcIdx: TFuncIdx;
    // This pointer is empty most of the time and is used only to keep instance alive
    // in one edge case, when start function traps, but instantiate has already
    // modified some elements of a shared (imported) table.
    sharedInstance: PInstance;
  end;

  TTableElements = TArray<TTableElement>;

{$EndRegion}

{$Region 'ExecuteFunction: WebAssembly or host function execution'}

  THostFunctionPtr = function(hostContext: TObject; Instance: Pointer;
    const args: PValue; var ctx: TExecutionContext): TExecutionResult;

  TExecuteFunction = class
  private
    // Pointer to WebAssembly function instance.
    // Equals nullptr in case this ExecuteFunction represents host function.
    FInstance: PInstance;
    // Index of WebAssembly function.
    // Equals 0 in case this ExecuteFunction represents host function.
    FFuncIdx: TFuncIdx;
    // Pointer to a host function.
    // Equals nullptr in case this ExecuteFunction represents WebAssembly function.
    FHostFunction: THostFunctionPtr;
    // Opaque context of host function execution,
    // which is passed to it as hostContext parameter.
    // Doesn't have value in case this ExecuteFunction represents WebAssembly function.
    FHostContext: TObject;
  public
    constructor Create(instance: PInstance; funcIdx: TFuncIdx); overload;
    // Host function constructor without context.
    // The function will always be called with empty hostContext argument.
    constructor Create(f: THostFunctionPtr); overload;
    // Host function constructor with context.
    // The function will be called with a reference to @a hostContext.
    // Copies of the function will have their own copy of @a hostContext.
    constructor Create(f: THostFunctionPtr; hostContext: TObject); overload;
    // Function call operator.
    function Call(instance: PInstance; const args: PValue;
      var ctx: TExecutionContext): TExecutionResult;
    // Function pointer stored inside this object.
    function GetHostFunction: THostFunctionPtr;
  end;

{$EndRegion}

{$Region 'TExternalFunction: imported and exported functions'}

  PExternalFunction = ^TExternalFunction;
  TExternalFunction = record
  var
    func: TExecuteFunction;
    inputTypes: TSpan<TValType>;
    outputTypes: TSpan<TValType>;
  public
    constructor From(const func: TExecuteFunction; const inputTypes: TSpan<TValType>;
      const outputTypes: TSpan<TValType>); overload;
    constructor From(const func: TExecuteFunction; const typ: TFuncType); overload;
  end;

{$EndRegion}

{$Region 'TExternalTable'}

  TExternalTable = record
    table: TTableElements;
    limits: TLimits;
  end;

{$EndRegion}

{$Region 'TExternalMemory'}

  TExternalMemory = record
    data: TBytes;
    limits: TLimits;
  end;

{$EndRegion}

{$Region 'TExternalGlobal'}

  TExternalGlobal = record
    value: PValue;
    typ: TGlobalType;
  end;

{$EndRegion}

{$Region 'TInstance: The module instance'}

  TInstance = record
  var
    // Module of this instance.
    module: TModule;
    // Instance memory.
    memory: TBytes;
    // Memory limits.
    memoryLimits: TLimits;
    // Hard limit for memory growth in pages, checked when memory is defined
    // as unbounded in module.
    memoryPagesLimit: Uint32;
    // Instance table.
    table: TTableElements;
    // Table limits.
    tableLimits: TLimits;
    // Instance globals (excluding imported globals).
    globals: TArray<TValue>;
    // Imported functions.
    importedFunctions: TArray<TExternalFunction>;
    // Imported globals.
    importedGlobals: TArray<TExternalGlobal>;
  public
    constructor From(const module: TModule; const memory: TBytes;
      const memoryLimits: TLimits; const memoryPagesLimit: Uint32;
      const table: TTableElements; tableLimits: TLimits;
      const globals: TArray<TValue>;
      const importedFunctions: TArray<TExternalFunction>;
      const importedGlobals: TArray<TExternalGlobal>);
  end;

{$EndRegion}

function Instantiate(
  const module: TModule;
  const importedFunctions: TArray<TExternalFunction> = nil;
  const importedTables: TArray<TExternalTable> = nil;
  const importedMemories: TArray<TExternalMemory> = nil;
  const importedGlobals: TArray<TExternalGlobal> = nil;
  memoryPagesLimit: Uint32 = DefaultMemoryPagesLimit): PInstance;

implementation

uses
  Oz.Wasm.Interpreter;

procedure matchImportedFunctions(const moduleFuncType: TArray<TFuncType>;
  const importedFunc: TArray<TExternalFunction>);
const
  Err1 = 'module requires %d imported functions, %d provided';
  Err2 = 'function %d type doesn''t match module''s imported function type';
begin
  if Length(moduleFuncType) <> Length(importedFunc) then
    raise WasmError.CreateFmt(Err1, [Length(moduleFuncType), Length(importedFunc)]);
  for var i := 0 to High(importedFunc) do
  begin
    var f := @importedFunc[i];
    if not moduleFuncType[i].equals(f.inputTypes, f.outputTypes) then
     raise WasmError.CreateFmt(Err2, [i]);
  end;
end;

procedure matchLimits(const externalLimits, moduleLimits: TLimits);
const
  Err1 = 'provided import''s min limit is above import''s max limit';
  Err2 = 'provided import''s min is below import''s min defined in module';
  Err3 = 'provided import''s max is above import''s max defined in module';
begin
  if externalLimits.max.hasValue and
    (externalLimits.min > externalLimits.max.value) then
    raise WasmError.Create(Err1);
  if externalLimits.min < moduleLimits.min then
    raise WasmError.Create(Err2);
  if not moduleLimits.max.hasValue then
    exit;
  if externalLimits.max.hasValue and (externalLimits.max.value <= moduleLimits.max.value) then
    exit;
  raise WasmError.Create(Err3);
end;

procedure matchImportedTables(const moduleImportedTables: TArray<TTable>;
  const importedTables: TArray<TExternalTable>);
const
  Err1 = 'only 1 imported table is allowed';
  Err2 = 'trying to provide imported table to a module that doesn''t define one';
  Err3 = 'module defines an imported table but none was provided';
  Err4 = 'provided imported table has a null pointer to data';
  Err5 = 'provided imported table doesn''t fit provided limits';
begin
  Assert(Length(moduleImportedTables) <= 1);
  if Length(importedTables) > 1 then
    raise WasmError.Create(Err1);
  if Length(moduleImportedTables) = 0 then
  begin
    if Length(importedTables) > 0 then
     raise WasmError.Create(Err2);
  end
  else
  begin
    if Length(importedTables) = 0 then
      raise WasmError.Create(Err3);
    matchLimits(importedTables[0].limits, moduleImportedTables[0].limits);
    if importedTables[0].table = nil then
      raise WasmError.Create(Err4);
    var size := Length(importedTables[0].table);
    var min := importedTables[0].limits.min;
    var max := importedTables[0].limits.max;
    if (size < min) or (max.hasValue and (size > max.value)) then
      raise WasmError.Create(Err5);
  end;
end;

procedure matchImportedMemories(const moduleImportedMemories: TArray<TMemory>;
  const importedMemories: TArray<TExternalMemory>);
const
  Err1 = 'only 1 imported memory is allowed';
  Err2 = 'trying to provide imported memory to a module that doesn''t define one';
  Err3 = 'module defines an imported memory but none was provided';
  Err4 = 'provided imported memory has a null pointer to data';
  Err5 = 'provided imported memory size must be multiple of page size';
  Err6 = 'provided imported memory doesn''t fit provided limits';
begin
  Assert(Length(moduleImportedMemories) <= 1);
  if Length(importedMemories) > 1 then
    raise WasmError.Create(Err1);
  if Length(moduleImportedMemories) = 0 then
  begin
    if Length(importedMemories) > 0 then
      raise WasmError.Create(Err2);
  end
  else
  begin
    if Length(importedMemories) = 0 then
      raise WasmError.Create(Err3);
    matchLimits(importedMemories[0].limits, moduleImportedMemories[0].limits);
    if importedMemories[0].data = nil then
      raise WasmError.Create(Err4);
    var size := Length(importedMemories[0].data);
    if size mod PageSize <> 0 then
      raise WasmError.Create(Err5);
    var min := importedMemories[0].limits.min;
    var max := importedMemories[0].limits.max;
    if (size < min * PageSize) or
       (max.hasValue and (size > max.value * PageSize)) then
      raise WasmError.Create(Err6);
  end;
end;

procedure matchImportedGlobals(const moduleImportedGlobals: TArray<TGlobalType>;
  const importedGlobals: TArray<TExternalGlobal>);
const
  Err1 = 'module requires %d imported globals %d provided';
  Err2 = 'global %d value type doesn''t match module''s global type';
  Err3 = 'global %d mutability doesn''t match module''s global mutability';
  Err4 = 'global %d has a null pointer to value';
begin
  if Length(moduleImportedGlobals) <> Length(importedGlobals) then
    raise WasmError.CreateFmt(Err1, [Length(moduleImportedGlobals), Length(importedGlobals)]);
  for var i := 0 to Length(importedGlobals) do
  begin
    if importedGlobals[i].typ.valueType <> moduleImportedGlobals[i].valueType then
      raise WasmError.CreateFmt(Err2, [i]);
    if importedGlobals[i].typ.isMutable <> moduleImportedGlobals[i].isMutable then
      raise WasmError.CreateFmt(Err3, [i]);
    if importedGlobals[i].value = nil then
      raise WasmError.Create(Err4);
  end;
end;

function evalConstantExpression(expr: TConstantExpression;
  const importedGlobals: TArray<TExternalGlobal>;
  const globals: TArray<TValue>): TValue;
begin
  if expr.kind = TConstantExpression.TKind.Constant then
    Result := expr.constant
  else
  begin
    Assert(expr.kind = TConstantExpression.TKind.GlobalGet);
    var globalIndex := expr.globalIndex;
    Assert(globalIndex < Length(importedGlobals) + Length(globals));
    if globalIndex < Length(importedGlobals) then
      Result := importedGlobals[globalIndex].value^
    else
      Result := globals[globalIndex - Length(importedGlobals)];
  end;
end;

procedure allocateTable(const moduleTables: TArray<TTable>;
  const importedTables: TArray<TExternalTable>;
  var table: TTableElements; var limits: TLimits);
begin
  Assert(Length(moduleTables) + Length(importedTables) <= 1);
  if Length(moduleTables) = 1 then
  begin
    limits := moduleTables[0].limits;
    SetLength(table, limits.min);
  end
  else if Length(importedTables) = 1 then
  begin
    limits := importedTables[0].limits;
    table := importedTables[0].table;
  end
  else
  begin
    limits := Default(TLimits);
    table := nil;
  end
end;

procedure allocateMemory(const moduleMemories: TArray<TMemory>;
  const importedMemories: TArray<TExternalMemory>; memoryPagesLimit: Uint32;
  var memory: TBytes; var limits: TLimits);
const
  Err1 = 'hard memory limit cannot exceed %d bytes';
  Err2 = 'cannot exceed hard memory limit of %d bytes';
  Err3 = 'imported memory limits cannot exceed hard memory limit of %d bytes';
var
  lim: PLimits;
begin
  if memoryPagesLimit > MaxMemoryPagesLimit then
    raise WasmError.CreateFmt(Err1, [Uint64(MaxMemoryPagesLimit) * PageSize]);
  Assert(Length(moduleMemories) + Length(importedMemories) <= 1);
  if Length(moduleMemories) = 1 then
  begin
    lim := @moduleMemories[0].limits;
    if (lim.min > memoryPagesLimit) or
       (lim.max.hasValue and (lim.max.value > memoryPagesLimit)) then
      raise WasmError.CreateFmt(Err2, [memoryPagesLimit * PageSize]);

    SetLength(memory, lim.min * PageSize);
    limits := moduleMemories[0].limits;
  end
  else if Length(importedMemories) = 1 then
  begin
    lim := @importedMemories[0].limits;
    if (lim.min > memoryPagesLimit) or
       (lim.max.hasValue and (lim.max.value > memoryPagesLimit)) then
      raise WasmError.CreateFmt(Err3, [memoryPagesLimit * PageSize]);

    memory := importedMemories[0].data;
    limits := importedMemories[0].limits;
  end
  else
  begin
    memory := nil;
    limits := Default(TLimits);
  end;
end;

function Instantiate(
  const module: TModule;
  const importedFunctions: TArray<TExternalFunction>;
  const importedTables: TArray<TExternalTable>;
  const importedMemories: TArray<TExternalMemory>;
  const importedGlobals: TArray<TExternalGlobal>;
  memoryPagesLimit: Uint32): PInstance;
var
  globals: TArray<TValue>;
  datasecOffsets: TArray<Uint64>;
  elementsecOffsets: TArray<Uint64>;
  table: TTableElements;
  tableLimits: TLimits;
  memory: TBytes;
  memoryLimits: TLimits;
  instance: PInstance;
begin
  Assert(Length(module.funcsec) = Length(module.codesec));

  matchImportedFunctions(module.importedFunctionTypes, importedFunctions);
  matchImportedTables(module.importedTableTypes, importedTables);
  matchImportedMemories(module.importedMemoryTypes, importedMemories);
  matchImportedGlobals(module.importedGlobalTypes, importedGlobals);

  // Init globals
  SetLength(globals, Length(module.globalsec));
  for var global in module.globalsec do
  begin
    // Constraint to use global.get only with imported globals is checked at validation.
    Assert((global.expression.kind <> TConstantExpression.TKind.GlobalGet) or
      (global.expression.globalIndex < Length(importedGlobals)));
    var value := evalConstantExpression(global.expression, importedGlobals, globals);
    globals := globals + [value];
  end;

  allocateTable(module.tablesec, importedTables, table, tableLimits);
  allocateMemory(module.memorysec, importedMemories, memoryPagesLimit, memory, memoryLimits);

  // In case upper limit for local/imported memory is defined,
  // we adjust the hard memory limit, to ensure memory.grow will fail when exceeding it.
  // Note: allocateMemory ensures memory's max limit is always below memoryPagesLimit.
  if memoryLimits.max.hasValue then
  begin
    Assert(memoryLimits.max.value <= memoryPagesLimit);
    memoryPagesLimit := memoryLimits.max.value;
  end;

  // Before starting to fill memory and table,
  // check that data and element segments are within bounds.
  SetLength(datasecOffsets, Length(module.datasec));
  for var data in module.datasec do
  begin
    // Offset is validated to be i32, but it's used in 64-bit calculation below.
    var offset: Uint64 := evalConstantExpression(data.offset, importedGlobals, globals).i32;
    if offset + Length(data.init) > Length(memory) then
      raise WasmError.Create('data segment is out of memory bounds');
    datasecOffsets := datasecOffsets + [offset];
  end;

  Assert((Length(module.elementsec) = 0) or (table <> nil));

  SetLength(elementsecOffsets, Length(module.elementsec));
  for var element in module.elementsec do
  begin
    // Offset is validated to be i32, but it's used in 64-bit calculation below.
    var offset: Uint64 := evalConstantExpression(element.offset, importedGlobals, globals).i32;
    if offset + Length(element.init) > Length(table) then
      raise WasmError.Create('element segment is out of table bounds');
    elementsecOffsets := elementsecOffsets + [offset];
  end;

  // Fill out memory based on data segments
  for var i := 0 to High(module.datasec) do
  begin
    // NOTE: these instructions can overlap
    var first: Pbyte := @module.datasec[i].init[0];
    var last: Pbyte := Pbyte(first) + Length(module.datasec[i].init) * sizeof(TData);
    var dest := Pbyte(@memory[0]) + datasecOffsets[i];
    TStd.Copy<TData>(first^, last^, dest^);
  end;

  // We need to create instance before filling table,
  // because table functions will capture the pointer to instance.
  instance := AllocMem(sizeof(TInstance));
  instance^ := TInstance.From(module, memory, memoryLimits,
    memoryPagesLimit, table, tableLimits, globals,
    importedFunctions, importedGlobals);

  // Fill the table based on elements segment
  for var i := 0 to High(instance.module.elementsec) do
  begin
    // Overwrite table[offset..] with element.init
    var idx := elementsecOffsets[i];
    var it: PTableElement := @instance.table[idx];
    var pme := instance.module.elementsec[i];
    for var j := 0 to High(pme.init) do
    begin
      idx := pme.init[j];
      it.instance := instance;
      it.funcIdx := idx;
      it.sharedInstance := nil;
      it := PTableElement(PByte(it) + sizeof(TTableElement));
    end;
  end;

  // Run start function if present
  if instance.module.startfunc.hasValue then
  begin
    var funcidx := instance.module.startfunc.value;
    Assert(funcidx < Uint32(Length(instance.importedFunctions) + Length(instance.module.funcsec)));
    if Execute(instance, funcidx, nil).trapped then
    begin
      // When element section modified imported table, and then start function
      // trapped, modifications to the table are not rolled back.
      // Instance in this case is not being returned to the user, so it needs
      // to be kept alive as long as functions using it are alive in the table.
      if (Length(importedTables) > 0) and (Length(instance.module.elementsec) > 0) then
      begin
        // Instance may be used by several functions added to the table,
        // so we need a shared ownership here.
        var sharedInstance: PInstance := instance;
        for var i := 0 to High(sharedInstance.module.elementsec) do
        begin
          var idx := elementsecOffsets[i];
          var it: PTableElement := @sharedInstance.table[idx];
          var pme := sharedInstance.module.elementsec[i];
          for var j := 0 to High(pme.init) do
          begin
            // Capture shared instance in table element.
            it.sharedInstance := sharedInstance;
            it := PTableElement(PByte(it) + sizeof(TTableElement));
          end;
        end;
      end;
      raise WasmError.Create('start function failed to execute');
    end;
  end;

  Result := instance;
end;

{$Region 'TExecutionResult'}

constructor TExecutionResult.From(const value: TValue);
begin
  Self.hasValue := True;
  Self.value := value;
end;

constructor TExecutionResult.From(success: Boolean);
begin
  Self.trapped := not success;
end;

{$EndRegion}

{$Region 'TExecutionContext.TGuard'}

constructor TExecutionContext.TGuard.Create(ctx: TExecutionContext);
begin
  Self.FExecutionContext := ctx;
end;

destructor TExecutionContext.TGuard.Destroy;
begin
  Dec(FExecutionContext.depth);
  inherited;
end;

{$EndRegion}

{$Region 'TExecutionContext'}

function TExecutionContext.IncrementCallDepth: TGuard;
begin
  Inc(depth);
  Result := TGuard.Create(Self);
end;

{$EndRegion}

{$Region 'ExecuteFunction'}

constructor TExecuteFunction.Create(instance: PInstance; funcIdx: TFuncIdx);
begin
  inherited Create;
  FInstance := instance;
  FFuncIdx := funcIdx;
end;

constructor TExecuteFunction.Create(f: THostFunctionPtr);
begin
  inherited Create;
  FHostFunction := f;
end;

constructor TExecuteFunction.Create(f: THostFunctionPtr; hostContext: TObject);
begin
  inherited Create;
  FHostFunction := f;
  FHostContext := hostContext;
end;

function TExecuteFunction.Call(instance: PInstance; const args: PValue;
  var ctx: TExecutionContext): TExecutionResult;
begin
  if FInstance <> nil then
    Result := Execute(FInstance, FFuncIdx, args, ctx)
  else
    Result := FHostFunction(FHostContext, instance, args, ctx);
end;

function TExecuteFunction.GetHostFunction: THostFunctionPtr;
begin
  Result := FHostFunction;
end;

{$EndRegion}

{$Region 'TExternalFunction'}

constructor TExternalFunction.From(const func: TExecuteFunction; const typ: TFuncType);
begin
  Self.func := func;
  inputTypes := TSpan<TValType>.From(@typ.inputs[0], Length(typ.inputs));
  outputTypes := TSpan<TValType>.From(@typ.outputs[0], Length(typ.outputs));
end;

constructor TExternalFunction.From(const func: TExecuteFunction; const inputTypes,
  outputTypes: TSpan<TValType>);
begin
  Self.func := func;
  Self.inputTypes := inputTypes;
  Self.outputTypes := outputTypes;
end;

{$EndRegion}

{$Region 'TInstance'}

constructor TInstance.From(const module: TModule; const memory: TBytes;
  const memoryLimits: TLimits; const memoryPagesLimit: Uint32;
  const table: TTableElements; tableLimits: TLimits;
  const globals: TArray<TValue>;
  const importedFunctions: TArray<TExternalFunction>;
  const importedGlobals: TArray<TExternalGlobal>);
begin
  Self.module := module;
  Self.memory := memory;
  Self.memoryLimits := memoryLimits;
  Self.memoryPagesLimit := memoryPagesLimit;
  Self.table := table;
  Self.tableLimits := tableLimits;
  Self.globals := globals;
  Self.importedFunctions := importedFunctions;
  Self.importedGlobals := importedGlobals;
end;

{$EndRegion}

end.

