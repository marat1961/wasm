(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Interpreter;

interface

uses
  System.SysUtils, Oz.Wasm.Utils, Oz.Wasm.Limits, Oz.Wasm.Module,
  Oz.Wasm.Value, Oz.Wasm.Types, Oz.Wasm.Instruction;

{$T+}
{$SCOPEDENUMS ON}

type

{$Region 'TExecutionResult: The result of an execution'}

  TExecutionResult = record
    // This is true if the execution has trapped.
    trapped: Boolean;
    // This is true if value contains valid data.
    has_value: Boolean;
    // The result value. Valid if `has_value = true`.
    value: TValue;
    // Constructs result with a value.
    constructor From(const value: TValue); overload;
    // Constructs result in "void" or "trap" state depending on the success flag.
    // Prefer using Void and Trap constants instead.
    constructor From(success: Boolean); overload;
  end;
const
  BranchImmediateSize = 2 * sizeof(uint32);
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
    const args: PValue; var ctx: TExecutionContext): TExecutionResult;

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

{$Region 'TVm'}

  TVm = record
  private
    instance: PInstance;
    code: TCode;
    memory: TBytes;
    stack: TOperandStack;
    pc: PByte;
    vi: Uint64;
    function CheckLoad<SrcT>: Boolean; inline;
    function LoadFromMemory<T: record>: T; inline;
    function CheckStore<DstT>: Boolean; inline;
    procedure StoreToMemory<T>(const value: T);
    procedure Branch(arity: Uint32);
    // Increases the size of memory by delta_pages.
    function GrowMemory(deltaPages, memoryPagesLimit: Uint32): Uint32; inline;
  public
    procedure Init(instance: PInstance; func_idx: TFuncIdx; const args: PValue);
    procedure Execute(var ctx: TExecutionContext);
  end;

{$EndRegion}

{$Region 'PByteHelper'}

  PByteHelper = record helper for PByte
    function read<T>: T; inline;
    procedure store<T>(offset: Cardinal; value: T); inline;
    function load<T>(offset: Cardinal): T; inline;
  end;

{$EndRegion}

{$Region 'execute functions'}

// Execute a function from an instance with execution context
// starting with default depth of 0.
// Arguments and behavior is the same as in the other execute.
function Execute(instance: PInstance; func_idx: TFuncIdx;
  const args: PValue): TExecutionResult; inline; overload;

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
  const args: PValue; var ctx: TExecutionContext): TExecutionResult; overload;

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

function TExecuteFunction.Call(instance: PInstance; const args: PValue;
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
  Self.func := func;
  input_types := TSpan<TValType>.From(@typ.inputs[0], Length(typ.inputs));
  output_types := TSpan<TValType>.From(@typ.outputs[0], Length(typ.outputs));
end;

constructor TExternalFunction.From(const func: TExecuteFunction; const input_types,
  output_types: TSpan<TValType>);
begin
  Self.func := func;
  Self.input_types := input_types;
  Self.output_types := output_types;
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

{$Region 'PByteHelper'}

function PByteHelper.read<T>: T;
type Pt = ^T;
begin
  Result := Pt(Self)^;
  Inc(Self, sizeof(T));
end;

procedure PByteHelper.store<T>(offset: Cardinal; value: T);
type Pt = ^T;
begin
  Pt(Self + offset)^ := value;
end;

function PByteHelper.load<T>(offset: Cardinal): T;
type Pt = ^T;
begin
  Result := Pt(Self + offset)^;
end;

{$EndRegion}

{$Region 'TVm'}

procedure TVm.Init(instance: PInstance; func_idx: TFuncIdx; const args: PValue);
var
  func_type: TFuncType;
begin
  Self.instance := instance;
  Self.code := instance.module.get_code(func_idx);
  Self.memory := instance.memory;
  func_type := instance.module.get_function_type(func_idx);
  Self.stack := TOperandStack.From(args, Length(func_type.inputs), code.local_count, code.max_stack_height);
  Self.pc := @code.instructions[0];
end;

function TVm.CheckLoad<SrcT>: Boolean;
var
  address, offset: Int32;
begin
  address := stack.Top.AsInt32;
  // NOTE: alignment is dropped by the parser
  offset := pc.read<Uint32>;
  vi := Uint64(address) + offset;
  // Addressing is 32-bit, but we keep the value as 64-bit to detect overflows.
  Result := vi + sizeof(SrcT) <= Length(memory);
end;

function TVm.LoadFromMemory<T>: T;
type Pt = ^T;
begin
  var pv: PByte := @memory[0];
  Inc(pv, vi);
  Result := Pt(pv)^;
end;

function TVm.CheckStore<DstT>: Boolean;
var
  address, offset: Int32;
begin
  address := stack.Pop.AsInt32;
  // NOTE: alignment is dropped by the parser
  offset := pc.read<Uint32>;
  vi := Uint64(address) + offset;
  // Addressing is 32-bit, but we keep the value as 64-bit to detect overflows.
  Result := vi + sizeof(DstT) <= Length(memory);
end;

procedure TVm.StoreToMemory<T>(const value: T);
begin
  var pv: PByte := @memory[0];
  pv.store(vi, value);
end;

procedure TVm.Branch(arity: Uint32);
var
  code_offset, stack_drop: Uint32;
  r: TValue;
begin
  code_offset := pc.read<Uint32>;
  stack_drop := pc.read<Uint32>;

  pc := PByte(@code.instructions) + code_offset;

  // When branch is taken, additional stack items must be dropped.
  assert(Integer(stack_drop) >= 0);
  assert(stack.Size >= stack_drop + arity);
  if arity <> 0 then
  begin
    assert(arity = 1);
    r := stack.top^;
    stack.drop(stack_drop);
    stack.top^ := r;
  end
  else
    stack.drop(stack_drop);
end;

function TVm.GrowMemory(deltaPages, memoryPagesLimit: Uint32): Uint32;
begin
  var curPages := Length(memory) div PageSize;
  // These Assertions are guaranteed by allocation in instantiate
  // and this function for subsequent increases.
  Assert(Length(memory) mod PageSize = 0);
  Assert(memoryPagesLimit <= MaxMemoryPagesLimit);
  Assert(curPages <= memoryPagesLimit);
  var newPages := Uint64(curPages) + deltaPages;
  if newPages > memoryPagesLimit then
    exit(Uint32(-1));
  try
    // newPages <= memory_pages_limit <= MaxMemoryPagesLimit guarantees multiplication
    // will not overflow Uint32.
    Assert(newPages * PageSize <= Uint32.MaxValue);
    SetLength(memory, newPages * PageSize);
    exit(Uint32(curPages));
  except
    exit(Uint32(-1));
  end;
end;

function invoke_function(const func_type: TFuncType; func_idx: Uint32;
  instance: PInstance; var stack: TOperandStack; var ctx: TExecutionContext): Boolean; inline;
begin
  var num_args := Length(func_type.inputs);
  Assert(stack.Size >= num_args);
  var call_args := PValue(PByte(stack.rend) - num_args);

  var ctx_guard := ctx.increment_call_depth;
  var ret := Execute(instance, TFuncIdx(func_idx), call_args, ctx);

  // Bubble up traps
  if ret.trapped then
    exit(false);

  stack.drop(num_args);

  var num_outputs := Length(func_type.outputs);
  // NOTE: we can assume these two from validation
  Assert(num_outputs <= 1);
  Assert(ret.has_value = (num_outputs = 1));
  // Push back the result
  if num_outputs <> 0 then
    stack.push(ret.value);
  Result := True;
end;

procedure TVm.Execute(var ctx: TExecutionContext);
label
  traps, ends;
var
  instruction: TInstruction;
begin
  repeat
    instruction := TInstruction(pc^);
    Inc(pc);
    case instruction of
      TInstruction.unreachable:
        goto traps;
      TInstruction.nop, TInstruction.block, TInstruction.loop:
        ;
      TInstruction.if_:
        begin
          if stack.pop.AsUint32 <> 0 then
            pc := pc + sizeof(Uint32)  // Skip the immediate for else instruction.
          else
          begin
            var target_pc := pc.read<Uint32>;
            pc := PByte(@code.instructions[0]) + target_pc;
          end;
        end;
      TInstruction.else_:
        begin
          // We reach else only after executing if block ("then" part),
          // so we need to skip else block now.
          var target_pc := pc.read<Uint32>;
          pc := PByte(@code.instructions[0]) + target_pc;
        end;
      TInstruction.end_:
        begin
          // End execution if it's a final end instruction.
          if pc = @code.instructions[Length(code.instructions)] then
            goto ends;
        end;
      TInstruction.br, TInstruction.br_if, TInstruction.return_:
        begin
          var arity := pc.read<Uint32>;
          // Check condition for br_if.
          if (instruction = TInstruction.br_if) and (stack.pop.AsUint32 = 0) then
            pc := pc + BranchImmediateSize;
          Branch(arity);
        end;
      TInstruction.br_table:
        begin
          var br_table_size := pc.read<Uint32>;
          var arity := pc.read<Uint32>;
          var br_table_idx := stack.pop.AsUint32;
          var label_idx_offset: Uint32;
          if br_table_idx < br_table_size then
            label_idx_offset := br_table_idx * BranchImmediateSize
          else
            label_idx_offset := br_table_size * BranchImmediateSize;
          pc := pc + label_idx_offset;
          Branch(arity);
        end;
      TInstruction.call:
        begin
          var called_func_idx := pc.read<Uint32>;
          var called_func_type := instance.module.get_function_type(called_func_idx);
          if not invoke_function(called_func_type, called_func_idx, instance, stack, ctx) then
            goto traps;
        end;
      TInstruction.call_indirect:
        begin
          assert(instance.table <> nil);
          var expected_type_idx := pc.read<Uint32>;
          assert(expected_type_idx < Length(instance.module.typesec));
          var elem_idx := stack.pop.AsUint32;
          if elem_idx >= Length(instance.table^) then
            goto traps;

          var called_func := instance.table^[elem_idx];
          if called_func.instance = nil then
            // Table element not initialized.
            goto traps;

          // check actual type against expected type
          var actual_type := called_func.instance.module.get_function_type(called_func.func_idx);
          var expected_type := instance.module.typesec[expected_type_idx];
          if not expected_type.Equals(actual_type) then
            goto traps;
          if not invoke_function(actual_type, called_func.func_idx, called_func.instance, stack, ctx) then
            goto traps;
        end;
      TInstruction.drop:
        stack.pop;
      TInstruction.select:
        begin
          var condition := stack.pop.AsUint32;
          // NOTE: these two are the same type (ensured by validation)
          var val2 := stack.pop;
          var val1 := stack.pop;
          if condition = 0 then
            stack.push(val2)
          else
            stack.push(val1);
        end;
      TInstruction.local_get:
        begin
          var idx := pc.read<Uint32>;
          stack.push(stack.local(idx)^);
        end;
      TInstruction.local_set:
        begin
          var idx := pc.read<Uint32>;
          stack.local(idx)^ := stack.pop;
        end;
      TInstruction.local_tee:
        begin
          var idx := pc.read<Uint32>;
          stack.local(idx)^ := stack.top^;
        end;
      TInstruction.global_get:
        begin
          var idx := pc.read<Uint32>;
          assert(idx < Length(instance.imported_globals) + Length(instance.globals));
          if (idx < Length(instance.imported_globals)) then
            stack.push(instance.imported_globals[idx].value)
          else
          begin
            var module_global_idx := idx - Length(instance.imported_globals);
            assert(module_global_idx < Length(instance.module.globalsec));
            stack.push(instance.globals[module_global_idx]);
          end;
        end;
      TInstruction.global_set:
        begin
          var idx := pc.read<Uint32>;
          if idx < Length(instance.imported_globals) then
          begin
            assert(instance.imported_globals[idx].typ.is_mutable);
            instance.imported_globals[idx].value := stack.pop;
          end
          else
          begin
            var module_global_idx := idx - Length(instance.imported_globals);
            assert(module_global_idx < Length(instance.module.globalsec));
            assert(instance.module.globalsec[module_global_idx].typ.is_mutable);
            instance.globals[module_global_idx] := stack.pop;
          end;
        end;
      TInstruction.i32_load:
        begin
          if not CheckLoad<Uint32> then goto traps;
          stack.Top.i32 := LoadFromMemory<Uint32>;
        end;
      TInstruction.i64_load:
        begin
          if not CheckLoad<Uint64> then goto traps;
          stack.Top.i64 := LoadFromMemory<Uint64>;
        end;
      TInstruction.f32_load:
        begin
          if not CheckLoad<Single> then goto traps;
          stack.Top.f32 := LoadFromMemory<Single>;
        end;
      TInstruction.f64_load:
        begin
          if not CheckLoad<Double> then goto traps;
          stack.Top.f64 := LoadFromMemory<Double>;
        end;
      TInstruction.i32_load8_s:
        begin
          if not CheckLoad<Int8> then goto traps;
          stack.Top.i32 := LoadFromMemory<Int8>;
        end;
      TInstruction.i32_load8_u:
        begin
          if not CheckLoad<Uint8> then goto traps;
          stack.Top.i32 := LoadFromMemory<Uint8>;
        end;
      TInstruction.i32_load16_s:
        begin
          if not CheckLoad<Int16> then goto traps;
          stack.Top.i32 := LoadFromMemory<Int16>;
        end;
      TInstruction.i32_load16_u:
        begin
          if not CheckLoad<Uint8> then goto traps;
          stack.Top.i32 := LoadFromMemory<Uint8>;
        end;
      TInstruction.i64_load8_s:
        begin
          if not CheckLoad<Int8> then goto traps;
          stack.Top.i64 := LoadFromMemory<Int8>;
        end;
      TInstruction.i64_load8_u:
        begin
          if not CheckLoad<Uint8> then goto traps;
          stack.Top.i64 := LoadFromMemory<Uint8>;
        end;
      TInstruction.i64_load16_s:
        begin
          if not CheckLoad<Int16> then goto traps;
          stack.Top.i64 := LoadFromMemory<Int16>;
        end;
      TInstruction.i64_load16_u:
        begin
          if not CheckLoad<Uint16> then goto traps;
          stack.Top.i64 := LoadFromMemory<Uint16>;
        end;
      TInstruction.i64_load32_s:
        begin
          if not CheckLoad<Int32> then goto traps;
          stack.Top.i64 := LoadFromMemory<Int32>;
        end;
      TInstruction.i64_load32_u:
        begin
          if not CheckLoad<Uint32> then goto traps;
          stack.Top.i64 := LoadFromMemory<Uint32>;
        end;
      TInstruction.i32_store:
        begin
          var value := stack.Pop.i32;
          if not CheckStore<Uint32> then goto traps;
          StoreToMemory<Uint32>(value);
        end;
      TInstruction.i64_store:
        begin
          var value := stack.Pop.i64;
          if not CheckStore<Int64> then goto traps;
          StoreToMemory<Int64>(value);
        end;
      TInstruction.f32_store:
        begin
          var value := stack.Pop.f32;
          if not CheckStore<Single> then goto traps;
          StoreToMemory<Single>(value);
        end;
      TInstruction.f64_store:
        begin
          var value := stack.Pop.f64;
          if not CheckStore<Double> then goto traps;
          StoreToMemory<Double>(value);
        end;
      TInstruction.i32_store8, TInstruction.i64_store8:
        begin
          var value := stack.Pop.i64;
          if not CheckStore<Uint8> then goto traps;
          StoreToMemory<Uint8>(value);
        end;
      TInstruction.i32_store16, TInstruction.i64_store16:
        begin
          var value := stack.Pop.i64;
          if not CheckStore<Uint16> then goto traps;
          StoreToMemory<Uint16>(value);
        end;
      TInstruction.i64_store32:
        begin
          var value := stack.Pop.i64;
          if not CheckStore<Uint32> then goto traps;
          StoreToMemory<Uint32>(value);
        end;
      TInstruction.memory_size:
        begin
          assert(Length(memory) mod PageSize = 0);
          stack.push(TValue.From(Uint32(Length(memory) div PageSize)));
        end;
      TInstruction.memory_grow:
        stack.top.i64 := GrowMemory(stack.top.AsUint32, instance.memory_pages_limit);
      TInstruction.i32_const, TInstruction.f32_const:
        begin
          var value := pc.read<Uint32>;
          stack.push(value);
        end;
      TInstruction.i64_const, TInstruction.f64_const:
        begin
          var value := pc.read<Int64>;
          stack.push(value);
        end;
      TInstruction.i32_eqz:
        stack.top.i32 := Uint32(stack.top.AsUint32 = 0);
      TInstruction.i32_eq:
        comparison_op(stack, std::equal_to<Uint32>);
      TInstruction.i32_ne:
        comparison_op(stack, std::not_equal_to<Uint32>);
      TInstruction.i32_lt_s:
        comparison_op(stack, std::less<Int32>);
      TInstruction.i32_lt_u:
        comparison_op(stack, std::less<Uint32>);
      TInstruction.i32_gt_s:
        comparison_op(stack, std::greater<Int32>);
      TInstruction.i32_gt_u:
        comparison_op(stack, std::greater<Uint32>);
      TInstruction.i32_le_s:
        comparison_op(stack, std::less_equal<Int32>);
      TInstruction.i32_le_u:
        comparison_op(stack, std::less_equal<Uint32>);
      TInstruction.i32_ge_s:
        comparison_op(stack, std::greater_equal<Int32>);
      TInstruction.i32_ge_u:
        comparison_op(stack, std::greater_equal<Uint32>);
      TInstruction.i64_eqz:
        stack.top = Uint32(stack.top.i64 = 0);
      TInstruction.i64_eq:
        comparison_op(stack, std::equal_to<Int64>);
      TInstruction.i64_ne:
        comparison_op(stack, std::not_equal_to<Int64>);
      TInstruction.i64_lt_s:
        comparison_op(stack, std::less<int64_t>);
      TInstruction.i64_lt_u:
        comparison_op(stack, std::less<Int64>);
      TInstruction.i64_gt_s:
        comparison_op(stack, std::greater<int64_t>);
      TInstruction.i64_gt_u:
        comparison_op(stack, std::greater<Int64>);
      TInstruction.i64_le_s:
        comparison_op(stack, std::less_equal<int64_t>);
      TInstruction.i64_le_u:
        comparison_op(stack, std::less_equal<Int64>);
      TInstruction.i64_ge_s:
        comparison_op(stack, std::greater_equal<int64_t>);
      TInstruction.i64_ge_u:
        comparison_op(stack, std::greater_equal<Int64>);
       TInstruction.f32_eq:
        comparison_op(stack, std::equal_to<Single>);
      TInstruction.f32_ne:
        comparison_op(stack, std::not_equal_to<Single>);
      TInstruction.f32_lt:
        comparison_op(stack, std::less<Single>);
      TInstruction.f32_gt:
        comparison_op<Single>(stack, std::greater<Single>);
      TInstruction.f32_le:
        comparison_op(stack, std::less_equal<Single>);
      TInstruction.f32_ge:
        comparison_op(stack, std::greater_equal<Single>);
      TInstruction.f64_eq:
        comparison_op(stack, std::equal_to<Double>);
      TInstruction.f64_ne:
        comparison_op(stack, std::not_equal_to<Double>);
      TInstruction.f64_lt:
        comparison_op(stack, std::less<Double>);
      TInstruction.f64_gt:
        comparison_op<Double>(stack, std::greater<Double>);
      TInstruction.f64_le:
        comparison_op(stack, std::less_equal<Double>);
      TInstruction.f64_ge:
        comparison_op(stack, std::greater_equal<Double>);
      TInstruction.i32_clz:
         unary_op(stack, clz32);
      TInstruction.i32_ctz:
        unary_op(stack, ctz32);
      TInstruction.i32_popcnt:
        unary_op(stack, popcnt32);
      TInstruction.i32_add:
        binary_op(stack, add<Uint32>);
      TInstruction.i32_sub:
        binary_op(stack, sub<Uint32>);
      TInstruction.i32_mul:
        binary_op(stack, mul<Uint32>);
      TInstruction.i32_div_s:
      begin
        var rhs := stack.pop.as<Int32>;
        var lhs := stack.top.as<Int32>;
        if (rhs = 0) or (lhs = std::numeric_limits<Int32>::min) and (rhs = -1) then
          goto traps;
        stack.top := div(lhs, rhs);
      end;
      TInstruction.i32_div_u:
      begin
        var rhs := stack.pop.AsUint32;
        if rhs = 0 then
          goto traps;
        var lhs := stack.top.AsUint32;
        stack.top := div(lhs, rhs);
      end;
      TInstruction.i32_rem_s:
      begin
        var rhs := stack.pop.as<Int32>;
        if rhs = 0 then
          goto traps;
        var lhs := stack.top.as<Int32>;
        if (lhs = std::numeric_limits<Int32>::min) and (rhs = -1) then
          stack.top := int32_tbegin0end;;
        else
          stack.top := rem(lhs, rhs);
      end;
      TInstruction.i32_rem_u:
      begin
        var rhs := stack.pop.AsUint32;
        if rhs = 0 then
          goto traps;
        var lhs := stack.top.AsUint32;
        stack.top := rem(lhs, rhs);
      end;
      TInstruction.i32_and:
        binary_op(stack, std::bit_and<Uint32>);
      TInstruction.i32_or:
        binary_op(stack, std::bit_or<Uint32>);
      TInstruction.i32_xor:
        binary_op(stack, std::bit_xor<Uint32>);
      TInstruction.i32_shl:
        binary_op(stack, shift_left<Uint32>);
      TInstruction.i32_shr_s:
        binary_op(stack, shift_right<Int32>);
      TInstruction.i32_shr_u:
        binary_op(stack, shift_right<Uint32>);
      TInstruction.i32_rotl:
        binary_op(stack, rotl<Uint32>);
      TInstruction.i32_rotr:
        binary_op(stack, rotr<Uint32>);

      TInstruction.i64_clz:
        unary_op(stack, clz64);
      TInstruction.i64_ctz:
        unary_op(stack, ctz64);
      TInstruction.i64_popcnt:
        unary_op(stack, popcnt64);
      TInstruction.i64_add:
        binary_op(stack, add<Int64>);
      TInstruction.i64_sub:
        binary_op(stack, sub<Int64>);
      TInstruction.i64_mul:
        binary_op(stack, mul<Int64>);
      TInstruction.i64_div_s:
      begin
        var rhs := stack.pop.as<int64_t>;
        var lhs := stack.top.as<int64_t>;
        if (rhs = 0) or (lhs = std::numeric_limits<int64_t>::min) and (rhs = -1) then
          goto traps;
        stack.top := div(lhs, rhs);
      end;
      TInstruction.i64_div_u:
      begin
        var rhs := stack.pop.i64;
        if rhs = 0 then
          goto traps;
        var lhs := stack.top.i64;
        stack.top := div(lhs, rhs);
      end;
      TInstruction.i64_rem_s:
      begin
        var rhs := stack.pop.as<int64_t>;
        if rhs = 0 then
          goto traps;
        var lhs := stack.top.as<int64_t>;
        if (lhs = std::numeric_limits<int64_t>::min) and (rhs = -1) then
          stack.top := int64_tbegin0end;;
        else
          stack.top := rem(lhs, rhs);
      end;
      TInstruction.i64_rem_u:
      begin
        var rhs := stack.pop.i64;
        if rhs = 0 then
          goto traps;
        var lhs := stack.top.i64;
        stack.top := rem(lhs, rhs);
      end;
      TInstruction.i64_and:
        binary_op(stack, std::bit_and<Int64>);
      TInstruction.i64_or:
        binary_op(stack, std::bit_or<Int64>);
      TInstruction.i64_xor:
        binary_op(stack, std::bit_xor<Int64>);
      TInstruction.i64_shl:
        binary_op(stack, shift_left<Int64>);
      TInstruction.i64_shr_s:
        binary_op(stack, shift_right<int64_t>);
      TInstruction.i64_shr_u:
        binary_op(stack, shift_right<Int64>);
      TInstruction.i64_rotl:
        binary_op(stack, rotl<Int64>);
      TInstruction.i64_rotr:
        binary_op(stack, rotr<Int64>);

      TInstruction.f32_abs:
        unary_op(stack, fabs<Single>);
      TInstruction.f32_neg:
        unary_op(stack, fneg<Single>);
      TInstruction.f32_ceil:
        unary_op(stack, fceil<Single>);
      TInstruction.f32_floor:
        unary_op(stack, ffloor<Single>);
      TInstruction.f32_trunc:
          unary_op(stack, ftrunc<Single>);
      TInstruction.f32_nearest:
        unary_op(stack, fnearest<Single>);
      TInstruction.f32_sqrt:
        unary_op(stack, static_cast<Single ( *)(Single)>(std::sqrt));

      TInstruction.f32_add:
        binary_op(stack, add<Single>);
      TInstruction.f32_sub:
        binary_op(stack, sub<Single>);
      TInstruction.f32_mul:
        binary_op(stack, mul<Single>);
      TInstruction.f32_div:
        binary_op(stack, fdiv<Single>);
      TInstruction.f32_min:
        binary_op(stack, fmin<Single>);
      TInstruction.f32_max:
        binary_op(stack, fmax<Single>);
      TInstruction.f32_copysign:
        binary_op(stack, fcopysign<Single>);

      TInstruction.f64_abs:
        unary_op(stack, fabs<Double>);
      TInstruction.f64_neg:
        unary_op(stack, fneg<Double>);
      TInstruction.f64_ceil:
        unary_op(stack, fceil<Double>);
      TInstruction.f64_floor:
        unary_op(stack, ffloor<Double>);
      TInstruction.f64_trunc:
        unary_op(stack, ftrunc<Double>);
      TInstruction.f64_nearest:
        unary_op(stack, fnearest<Double>);
      TInstruction.f64_sqrt:
        unary_op(stack, static_cast<Double ( *)(Double)>(std::sqrt));

      TInstruction.f64_add:
          binary_op(stack, add<Double>);
      TInstruction.f64_sub:
        binary_op(stack, sub<Double>);
      TInstruction.f64_mul:
        binary_op(stack, mul<Double>);
      TInstruction.f64_div:
        binary_op(stack, fdiv<Double>);
      TInstruction.f64_min:
        binary_op(stack, fmin<Double>);
      TInstruction.f64_max:
        binary_op(stack, fmax<Double>);
      TInstruction.f64_copysign:
        binary_op(stack, fcopysign<Double>);

      TInstruction.i32_wrap_i64:
        stack.top := static_cast<Uint32>(stack.top.i64);
      TInstruction.i32_trunc_f32_s:
        if not trunc<Single, Int32>(stack) then
            goto traps;
      TInstruction.i32_trunc_f32_u:
        if not trunc<Single, Uint32>(stack) then
          goto traps;
      TInstruction.i32_trunc_f64_s:
        if not trunc<Double, Int32>(stack) then
          goto traps;
      TInstruction.i32_trunc_f64_u:
        if not trunc<Double, Uint32>(stack) then
          goto traps;
      TInstruction.i64_extend_i32_s:
        stack.top := int64(stack.top.as<Int32>);
      TInstruction.i64_extend_i32_u:
        stack.top := uint64(stack.top.i32); then
      TInstruction.i64_trunc_f32_s:
        if not trunc<Single, int64_t>(stack) then
            goto traps;
      TInstruction.i64_trunc_f32_u:
        if not trunc<Single, Int64>(stack) then
            goto traps;
      TInstruction.i64_trunc_f64_s:
        if not trunc<Double, int64_t>(stack) then
            goto traps;
      TInstruction.i64_trunc_f64_u:
        if (not trunc<Double, Int64>(stack))
            goto traps;
      TInstruction.f32_convert_i32_s:
        convert<Int32, Single>(stack);
      TInstruction.f32_convert_i32_u:
        convert<Uint32, Single>(stack);
      TInstruction.f32_convert_i64_s:
        convert<int64_t, Single>(stack);
      TInstruction.f32_convert_i64_u:
        convert<Int64, Single>(stack);
      TInstruction.f32_demote_f64:
        stack.top = demote(stack.top.f64);
      TInstruction.f64_convert_i32_s:
        convert<Int32, Double>(stack);
      TInstruction.f64_convert_i32_u:
        convert<Uint32, Double>(stack);
      TInstruction.f64_convert_i64_s:
        convert<int64_t, Double>(stack);
      TInstruction.f64_convert_i64_u:
        convert<Int64, Double>(stack);
      TInstruction.f64_promote_f32:
        stack.top = doublebeginstack.top.f32end;;
      TInstruction.i32_reinterpret_f32:
        reinterpret<Single, Uint32>(stack);
      TInstruction.i64_reinterpret_f64:
        reinterpret<Double, Int64>(stack);
      TInstruction.f32_reinterpret_i32:
        reinterpret<Uint32, Single>(stack);
      TInstruction.f64_reinterpret_i64:
        reinterpret<Int64, Double>(stack);
      else
        assert(False, 'unreachable')
    end;
  until False;
ends:
  assert(pc = &code.instructions[code.instructions.size]);
  // End of code must be reached.
  assert(stack.size = instance.module.get_function_type(func_idx).outputs.size);

  if stack.size <> 0 then
    exit(ExecutionResultbeginstack.top)
  else
    exit(Void);
traps:
    exit(Trap);
end;

{$EndRegion}

{$Region 'execute functions'}

function Execute(instance: PInstance; func_idx: TFuncIdx;
  const args: PValue): TExecutionResult; inline; overload;
var
  ctx: TExecutionContext;
begin
  Result := execute(instance, func_idx, args, ctx);
end;

function Execute(instance: PInstance; func_idx: TFuncIdx;
  const args: PValue; var ctx: TExecutionContext): TExecutionResult;
var
  vm: TVm;
begin
  Assert(ctx.depth >= 0);
  if ctx.depth >= CallStackLimit then
    exit(Trap);

  Assert(Length(instance.module.imported_function_types) = Length(instance.imported_functions));
  if func_idx < Cardinal(Length(instance.imported_functions)) then
    exit(instance.imported_functions[func_idx].func.Call(instance, args, ctx));

  vm.Init(instance, func_idx, args);
  vm.Execute;
end;

{$EndRegion}

end.

