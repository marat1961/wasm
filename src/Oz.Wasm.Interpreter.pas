(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: Apache-2.0
 *)
unit Oz.Wasm.Interpreter;

interface

uses
  System.SysUtils, Oz.Wasm.Limits, Oz.Wasm.Module, Oz.Wasm.Value, Oz.Wasm.Types;

{$T+}
{$SCOPEDENUMS ON}

type

{$Region 'TExecutionResult: The result of an execution'}

  TExecutionResult = record
    // This is true if the execution has trapped.
    trapped: Boolean;
    // This is true if value contains valid data.
    has_value: Boolean;
    // The result value. Valid if `has_value == true`.
    value: TValue;
    // Constructs result with a value.
    constructor From(const value: TValue); overload;
    // Constructs result in "void" or "trap" state depending on the success flag.
    // Prefer using Void and Trap constants instead.
    constructor From(success: Boolean); overload;
  end;
const
  // Shortcut for execution that resulted in successful execution,
  // but without a result.
  Void: TExecutionResult = (has_value: False);
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
      m_execution_context: TExecutionContext;
      constructor Create(ctx: TExecutionContext);
      destructor Destroy; override;
    end;
  var
    depth: Integer;  // Current call depth.
  public
    // Increments the call depth and returns the guard object which decrements
    // the call depth back to the original value when going out of scope.
    function increment_call_depth: TGuard;
  end;

{$EndRegion}

{$Region 'TTableElement: Table element, which references a function in any instance'}

  PInstance = ^TInstance;
  TTableElement = record
    // Pointer to function's instance or nullptr when table element is not initialized.
    instance: PInstance;
    // Index of the function in instance.
    func_idx: TFuncIdx;
    // This pointer is empty most of the time and is used only to keep instance alive
    // in one edge case, when start function traps, but instantiate has already
    // modified some elements of a shared (imported) table.
    shared_instance: PInstance;
  end;

  table_elements = TArray<TTableElement>;
  table_ptr = ^table_elements;

{$EndRegion}

{$Region 'TExternalFunction: imported and exported functions'}

  TExternalFunction = record

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
    // Memory is either allocated and owned by the instance or imported as already
    // allocated bytesand owned externally. For these cases unique_ptr would
    // either have a normal deleter or no-op deleter respectively
    memory: TBytes;
    // Memory limits.
    memory_limits: TLimits;
    // Hard limit for memory growth in pages, checked when memory is defined
    // as unbounded in module.
    memory_pages_limit: Cardinal;
    // Instance table.
    // Table is either allocated and owned by the instance or imported and owned
    // externally. For these cases unique_ptr would either have a normal deleter
    // or no-op deleter respectively.
    table: table_ptr;
    // Table limits.
    table_limits: TLimits;
    // Instance globals (excluding imported globals).
    globals: TArray<TValue>;
    // Imported functions.
    imported_functions: TArray<TExternalFunction>;
    // Imported globals.
    imported_globals: TArray<TExternalGlobal>;
  public
    constructor From(const module: TModule;
      const memory: TBytes;
      const memory_limits: TLimits;
      const memory_pages_limit: Cardinal;
      table: table_ptr; table_limits: TLimits;
      const globals: TArray<TValue>;
      const imported_functions: TArray<TExternalFunction>;
      const imported_globals: TArray<TExternalGlobal>);
  end;

{$EndRegion}

// Execute a function from an instance.
// Parameters
//   instance  The instance.
//   func_idx  The function index. MUST be a valid index, otherwise undefined behaviour
//             (including crash) happens.
//   args      The pointer to the arguments. The number of items and their types must
//             match the expected number of input parameters of the function, otherwise
//             undefined behaviour (including crash) happens.
//   ctx       Execution context.
function execute(var instance: TInstance; func_idx: TFuncIdx;
  const args: TValue; var ctx: TExecutionContext): TExecutionResult; overload;

// Execute a function from an instance with execution context starting with default
// depth of 0. Arguments and behavior is the same as in the other execute().
function execute(var instance: TInstance; func_idx: TFuncIdx;
  const args: TValue): TExecutionResult; inline; overload;

implementation

function execute(var instance: TInstance; func_idx: TFuncIdx;
  const args: TValue; var ctx: TExecutionContext): TExecutionResult;
begin
end;

function execute(var instance: TInstance; func_idx: TFuncIdx;
  const args: TValue): TExecutionResult; inline; overload;
var
  ctx: TExecutionContext;
begin
  Result := execute(instance, func_idx, args, ctx);
end;

type

  TFunctionAddress = record

  end;


  TTTableAddress = record

  end;

  TMemoryAddress = record

  end;


  TGlobalAddress = record

  end;

  TModuleInstance = record

  end;

  TWasmFunc = record

  end;

  THostFunc = record

  end;

  TTableInstance = record

  end;

  TMemoryInstance = record

  end;

  TGlobalInstance = record

  end;

  TStore = record

  end;

  TExportInstance = record

  end;

  TLabel = record

  end;

  TFrame = record

  end;

  TStack = record

  end;

  TConfiguration = record

  end;

  TArithmeticLogicUnit = record

  end;

  TMachine = record

  end;

{$Region 'TExecutionResult'}

constructor TExecutionResult.From(const value: TValue);
begin
  Self.has_value := True;
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
  Self.m_execution_context := ctx;
end;

destructor TExecutionContext.TGuard.Destroy;
begin
  Dec(m_execution_context.depth);
  inherited;
end;

{$EndRegion}

{$Region 'TExecutionContext'}

function TExecutionContext.increment_call_depth: TGuard;
begin
  Inc(depth);
  Result := TGuard.Create(Self);
end;

{$EndRegion}

{$Region 'TInstance'}

constructor TInstance.From(const module: TModule; const memory: TBytes;
  const memory_limits: TLimits; const memory_pages_limit: Cardinal;
  table: table_ptr; table_limits: TLimits;
  const globals: TArray<TValue>;
  const imported_functions: TArray<TExternalFunction>;
  const imported_globals: TArray<TExternalGlobal>);
begin
  Self.module := module;
  Self.memory := memory;
  Self.memory_limits := memory_limits;
  Self.memory_pages_limit := memory_pages_limit;
  Self.table := table;
  Self.table_limits := table_limits;
  Self.globals := globals;
  Self.imported_functions := imported_functions;
  Self.imported_globals := imported_globals;
end;

{$EndRegion}

end.

