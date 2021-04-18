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
  PTable = ^TTableElements;

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
    value: TValue;
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
    table: PTable;
    // Table limits.
    tableLimits: TLimits;
    // Instance globals (excluding imported globals).
    globals: TArray<TValue>;
    // Imported functions.
    importedFunctions: TArray<TExternalFunction>;
    // Imported globals.
    importedGlobals: TArray<TExternalGlobal>;
  public
    constructor From(const module: TModule;
      const memory: TBytes;
      const memoryLimits: TLimits;
      const memoryPagesLimit: Uint32;
      table: PTable; tableLimits: TLimits;
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
  const memoryPagesLimit: Uint32 = DefaultMemoryPagesLimit): PInstance;


implementation

uses
  Oz.Wasm.Interpreter;

function Instantiate(
  const module: TModule;
  const importedFunctions: TArray<TExternalFunction>;
  const importedTables: TArray<TExternalTable>;
  const importedMemories: TArray<TExternalMemory>;
  const importedGlobals: TArray<TExternalGlobal>;
  const memoryPagesLimit: Uint32): PInstance;
begin

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
  table: PTable; tableLimits: TLimits;
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

