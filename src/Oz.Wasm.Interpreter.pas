(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Interpreter;

interface

uses
  System.SysUtils, Oz.Wasm.Utils,
  Oz.Wasm.Limits, Oz.Wasm.Module, Oz.Wasm.Value, Oz.Wasm.Types;

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

{$Region 'ExecuteFunction: WebAssembly or host function execution'}

  THostFunctionPtr = function(host_context: TObject; Instance: Pointer;
    const args: TValue; var ctx: TExecutionContext): TExecutionResult;

  TExecuteFunction = class
  private
    // Pointer to WebAssembly function instance.
    // Equals nullptr in case this ExecuteFunction represents host function.
    m_instance: PInstance;
    // Index of WebAssembly function.
    // Equals 0 in case this ExecuteFunction represents host function.
    m_func_idx: TFuncIdx;
    // Pointer to a host function.
    // Equals nullptr in case this ExecuteFunction represents WebAssembly function.
    m_host_function: THostFunctionPtr;
    // Opaque context of host function execution,
    // which is passed to it as host_context parameter.
    // Doesn't have value in case this ExecuteFunction represents WebAssembly function.
    m_host_context: TObject;
  public
    constructor Create(instance: PInstance; func_idx: TFuncIdx); overload;
    // Host function constructor without context.
    // The function will always be called with empty host_context argument.
    constructor Create(f: THostFunctionPtr); overload;
    // Host function constructor with context.
    // The function will be called with a reference to @a host_context.
    // Copies of the function will have their own copy of @a host_context.
    constructor Create(f: THostFunctionPtr; host_context: TObject); overload;
    // Function call operator.
    function Call(instance: PInstance; const args: TValue;
      var ctx: TExecutionContext): TExecutionResult;
    // Function pointer stored inside this object.
    function GetHostFunction: THostFunctionPtr;
  end;

{$EndRegion}

{$Region 'TExternalFunction: imported and exported functions'}

  TExternalFunction = record
  var
    func: TExecuteFunction;
    input_types: TSpan<TValType>;
    output_types: TSpan<TValType>;
  public
    constructor From(const func: TExecuteFunction; const input_types: TSpan<TValType>;
      const output_types: TSpan<TValType>); overload;
    constructor From(const func: TExecuteFunction; const typ: TFuncType); overload;
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

{$Region 'execute functions'}

// Execute a function from an instance with execution context
// starting with default depth of 0.
// Arguments and behavior is the same as in the other execute.
function Execute(instance: PInstance; func_idx: TFuncIdx;
  const args: TValue): TExecutionResult; inline; overload;

// Execute a function from an instance.
// Parameters
//   instance  The instance.
//   func_idx  The function index. MUST be a valid index, otherwise undefined behaviour
//             (including crash) happens.
//   args      The pointer to the arguments. The number of items and their types must
//             match the expected number of input parameters of the function, otherwise
//             undefined behaviour (including crash) happens.
//   ctx       Execution context.
function Execute(instance: PInstance; func_idx: TFuncIdx;
  const args: TValue; var ctx: TExecutionContext): TExecutionResult; overload;

{$EndRegion}

implementation

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

{$Region 'ExecuteFunction'}

constructor TExecuteFunction.Create(instance: PInstance; func_idx: TFuncIdx);
begin
  inherited Create;
  m_instance := instance;
  m_func_idx := func_idx;
end;

constructor TExecuteFunction.Create(f: THostFunctionPtr);
begin
  inherited Create;
  m_host_function := f;
end;

constructor TExecuteFunction.Create(f: THostFunctionPtr; host_context: TObject);
begin
  inherited Create;
  m_host_function := f;
  m_host_context := host_context;
end;

function TExecuteFunction.Call(instance: PInstance; const args: TValue;
  var ctx: TExecutionContext): TExecutionResult;
begin
  if m_instance <> nil then
    Result := execute(m_instance, m_func_idx, args, ctx)
  else
    Result := m_host_function(m_host_context, instance, args, ctx);
end;

function TExecuteFunction.GetHostFunction: THostFunctionPtr;
begin
  Result := m_host_function;
end;

{$EndRegion}

{$Region 'TExternalFunction'}

constructor TExternalFunction.From(const func: TExecuteFunction; const typ: TFuncType);
begin

end;

constructor TExternalFunction.From(const func: TExecuteFunction; const input_types,
  output_types: TSpan<TValType>);
begin

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

{$Region 'execute functions'}

function Execute(instance: PInstance; func_idx: TFuncIdx;
  const args: TValue): TExecutionResult; inline; overload;
var
  ctx: TExecutionContext;
begin
  Result := execute(instance, func_idx, args, ctx);
end;

function Execute(instance: PInstance; func_idx: TFuncIdx;
  const args: TValue; var ctx: TExecutionContext): TExecutionResult;
var
  func_type: TFuncType;
  code: TCode;
  memory: TBytes;
  stack: TOperandStack;
  pc: PByte;
begin
  Assert(ctx.depth >= 0);
  if ctx.depth >= CallStackLimit then
    exit(Trap);
  func_type := instance.module.get_function_type(func_idx);

  Assert(Length(instance.module.imported_function_types) = Length(instance.imported_functions));
  if func_idx < Cardinal(Length(instance.imported_functions)) then
    exit(instance.imported_functions[func_idx].func.Call(instance, args, ctx));

  code := instance.module.get_code(func_idx);
  memory := instance.memory;

  stack := TOperandStack.From(@args, Length(func_type.inputs), code.local_count,
    code.max_stack_height);

  pc := @code.instructions[0];
end;

{$EndRegion}

end.

