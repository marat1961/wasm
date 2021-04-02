unit Wasm.Interpreter;

interface

uses
  System.Classes, System.SysUtils, Wasm.Limits, Wasm.Module, Wasm.Value, Wasm.Types;

{$T+}
{$SCOPEDENUMS ON}

type

  // The result of an execution.
  ExecutionResult = record
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

  // The storage for information shared by calls in the same execution "thread".
  // Users may decide how to allocate the execution context, but some good defaults are available.
  TExecutionContext = class
  type
    // Call depth increment guard.
    // It will automatically decrement the call depth to the original value
    // when going out of scope.
    TGuard = class
    end;
  end;


  TResult = record

  end;

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

implementation

{ ExecutionResult }

constructor ExecutionResult.From(success: Boolean);
begin

end;

constructor ExecutionResult.From(const value: TValue);
begin

end;

end.

