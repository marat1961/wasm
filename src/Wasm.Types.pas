unit Wasm.Types;

interface

uses
  System.Classes, System.SysUtils;

{$T+}
{$SCOPEDENUMS ON}

const
  // table-types
  FuncRef: Byte = $70;

type

  // Value types
  TValType = (
    i32 = $7f,
    i64 = $7e,
    f32 = $7d,
    f64 = $7c);

  // Function types classify the signature of functions,
  // mapping a vector of parameters to a vector of results.
  // They are also used to classify the inputs and outputs of instructions.
  TFuncType = record
    inputs: TArray<TValType>;
    outputs: TArray<TValType>;
    function Equals(const ft: TFuncType): Boolean;
  end;

  // Limits classify the size range of resizeable storage
  // associated with memory types and table types.
  // If no maximum is given, the respective storage can grow to any size.
  TLimits = record
    min: Cardinal;
    max: Cardinal;
  end;

  // All indices are encoded with their respective value.
  type TTypeIdx = Cardinal;
  type TFuncIdx = Cardinal;
  type TTableIdx = Cardinal;
  type TMemIdx = Cardinal;
  type TGlobalIdx = Cardinal;
  type TLocalIdx = Cardinal;

  // Code Section

  // Function locals.
  TLocals = record
    count: Cardinal;
    typ: TValType;
  end;

  TTable = record
    limits: TLimits;
  end;

implementation

{ TFuncType }

function TFuncType.Equals(const ft: TFuncType): Boolean;
begin
  Result := (inputs = ft.inputs) and (outputs = ft.outputs);
end;

end.

