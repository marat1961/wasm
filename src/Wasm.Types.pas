unit Wasm.Types;

interface

uses
  System.Classes, System.SysUtils, Wasm.Value;

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
  // Each section consists of
  //  * a one-byte section id,
  //  * the u32 size of the contents, in bytes,
  //  * the actual contents, whose structure is depended on the section id.
  // Every section is optional; an omitted section is equivalent to the section
  // being present with empty contents.

  // The following section ids are used:
  // --------------------
  // Id  Section
  // --------------------
  //  0  custom section
  //  1  type section
  //  2  import section
  //  3  function section
  //  4  table section
  //  5  memory section
  //  6  global section
  //  7  export section
  //  8  start section
  //  9  element section
  // 10  code section
  // 11  data section
  // 12  data count section
  // --------------------

  // Function locals.
  TLocals = record
    count: Cardinal;
    typ: TValType;
  end;

  TTable = record
    limits: TLimits;
  end;

  TMemory = record
    limits: TLimits;
  end;

  TConstantExpression = record
  type
    TKind = (Constant, GlobalGet);
  var
    kind: TKind;
    case Integer of
      0: (constant: TValue);
      1: (global_index: Cardinal);
  end;

  TGlobalType = record
    value_type: TValType;
    is_mutable: Boolean;
  end;

implementation

{ TFuncType }

function TFuncType.Equals(const ft: TFuncType): Boolean;
begin
  Result := (inputs = ft.inputs) and (outputs = ft.outputs);
end;

end.

