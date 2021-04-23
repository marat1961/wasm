(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.ParseExpression;

interface

uses
  System.SysUtils,
  Oz.Wasm.Value, Oz.Wasm.Utils, Oz.Wasm.Buffer, Oz.Wasm.Instruction,
  Oz.Wasm.Types, Oz.Wasm.Module;

{$T+}
{$SCOPEDENUMS ON}

// Parses 'expr', i.e. a function's instructions residing in the code section.
// https://webassembly.github.io/spec/core/binary/instructions.html#binary-expr
// parameters:
//   buf       Input buffer.
//   funcIdx   Index of the function being parsed.
//   locals    Vector of local type and counts for the function being parsed.
//   module    Module that this code is part of.
//   returns   The parsed code.
function parseExpr(var buf: TInputBuffer; funcIidx: TFuncIdx;
  const locals: TArray<TLocals>; const module: TModule): TCode;

implementation

// The control frame to keep information about labels and blocks as defined in
// Wasm Validation Algorithm https://webassembly.github.io/spec/core/appendix/algorithm.html.
type

  TControlFrame = record
  var
    // The instruction that created the label.
    instruction: TInstruction;
    // Return result type of the frame.
    typ: TOptional<TValType>;
    // The target instruction code offset.
    code_offset: Integer ;
    // The frame stack height of the parent frame.
    parent_stack_height: Integer;
    // Whether the remainder of the block is unreachable (used to handle stack-polymorphic typing
    // after branches).
    unreachable: Boolean;
    // Offsets of br/br_if/br_table instruction immediates, to be filled at the end of the block
    br_immediate_offsets: TArray<Integer>;
  public
    constructor From(instr: TInstruction; typ: TOptional<TValType>;
      parentStackHeight: Integer = 0; codeOffset: Integer = 0);
  end;

  TOperandStackType = (
    none = 0,
    i32 = $7f,
    i64 = $7e,
    f32 = $7d,
    f64 = $7c);

  TUtils = record
    class procedure store<T>(dst: PByte; const value: T); static; inline;
    class procedure push<T>(var b: TBytes; const value: T); static; inline;
  end;

constructor TControlFrame.From(instr: TInstruction; typ: TOptional<TValType>;
  parentStackHeight, codeOffset: Integer);
begin
  Self.instruction := instr;
  Self.typ := typ;
  Self.code_offset := code_offset;
  Self.parent_stack_height := parentStackHeight;
end;

class procedure TUtils.store<T>(dst: PByte; const value: T);
begin
  Move(value, dst^, sizeof(value));
end;

class procedure TUtils.push<T>(var b: TBytes; const value: T);
var
  storage: TBytes;
begin
  SetLength(storage, sizeof(value));
  store(@storage[0], value);
  b := b + storage;
end;

function from_valtype(val_type: TValType): TOperandStackType; inline;
begin
  Result := TOperandStackType(val_type);
end;

function type_matches(actual_type: TOperandStackType; expected_type: TValType): Boolean; overload; inline;
begin
  Result :=
    (actual_type = TOperandStackType.none) or
    (TValType(actual_type) = expected_type);
end;

function type_matches(actual_type, expected_type: TOperandStackType): Boolean; overload; inline;
begin
  Result :=
    (expected_type = TOperandStackType.none) or
    (actual_type = TOperandStackType.none) or
    (expected_type = actual_type);
end;

// Spec: https://webassembly.github.io/spec/core/binary/types.html#binary-blocktype.
// Parses blocktype. Return optional type of the block result.
function parse_blocktype(var buf: TInputBuffer): TOptional<TValType>;
const
  // The byte meaning an empty wasm result type.
  // https://webassembly.github.io/spec/core/binary/types.html#result-types
  BlockTypeEmpty: Byte = $40;
begin
  var typ := buf.readByte;
  if typ = BlockTypeEmpty then
    Result.Reset
  else
    Result := TOptional<TValType>.From(validateValtype(typ));
end;

procedure update_operand_stack(
  const frame: TControlFrame;
  operand_stack: TStack<TOperandStackType>;
  inputs, outputs: TSpan<TValType>);
begin
  var frame_stack_height := Integer(operand_stack.Size);
  var inputs_size := Integer(inputs.Size);

  // Stack is polymorphic after unreachable instruction: underflow is ignored,
  // but we need to count stack growth to detect extra values at the end of the block.
  if not frame.unreachable and
     (frame_stack_height < frame.parent_stack_height + inputs_size) then
    raise EWasmError.Create('stack underflow');

  // Update operand_stack.

  for var i := 0 to inputs.Size - 1 do
  begin
    var expected_type := inputs.Items[i];
    // Underflow is ignored for unreachable frame.
    if frame.unreachable and (Integer(operand_stack.size) = frame.parent_stack_height) then
      break;
    var actual_type := operand_stack.pop;
    if not type_matches(actual_type, expected_type) then
      raise EWasmError.Create('type mismatch');
  end;
  // Push output values even if frame is unreachable.
  for var i := 0 to inputs.Size - 1 do
  begin
    var output_type := outputs.Items[i];
    operand_stack.push(from_valtype(output_type));
  end;
end;

procedure drop_operand(
  const frame: TControlFrame;
  operand_stack: TStack<TOperandStackType>;
  expected_type: TOperandStackType); overload; inline ;
begin
  if not frame.unreachable and
     (Integer(operand_stack.size) < frame.parent_stack_height + 1) then
    raise EWasmError.Create('stack underflow');
  if Integer(operand_stack.size) = frame.parent_stack_height then
  begin
    Assert(frame.unreachable);  // implied from stack underflow check above
    exit;
  end;
  if not type_matches(operand_stack.pop, expected_type) then
   raise EWasmError.Create('type mismatch');
end;

procedure drop_operand(
  const frame: TControlFrame;
  operand_stack: TStack<TOperandStackType>;
  expected_type: TValType); overload; inline ;
begin
  drop_operand(frame, operand_stack, from_valtype(expected_type));
end;

procedure update_result_stack(
  const frame: TControlFrame;
  operand_stack: TStack<TOperandStackType>);
begin
  var frame_stack_height := Integer(operand_stack.Size);
  // This is checked by "stack underflow".
  Assert(frame_stack_height >= frame.parent_stack_height);
  var arity := Ord(frame.typ.hasValue);
  if frame_stack_height > frame.parent_stack_height + arity then
    raise EWasmError.Create('too many results');
  if arity <> 0 then
    drop_operand(frame, operand_stack, from_valtype(frame.typ.value));
end;

function get_branch_frame_type(const frame: TControlFrame): TOptional<TValType>; inline;
begin
  // For loops arity is considered always 0, because br executed in loop jumps to the top,
  // resetting frame stack to 0, so it should not keep top stack value even if loop has a result.
  if frame.instruction = TInstruction.loop then
    Result.Reset
  else
    Result := frame.typ;
end;

function get_branch_arity(const frame: TControlFrame): Uint32; inline;
begin
  Result := Ord(get_branch_frame_type(frame).hasValue);
end;

procedure update_branch_stack(const current_frame, branch_frame: TControlFrame;
  operand_stack: TStack<TOperandStackType>); inline;
begin
  Assert(Integer(operand_stack.Size) >= current_frame.parent_stack_height);
  var branch_frame_type := get_branch_frame_type(branch_frame);
  if branch_frame_type.hasValue then
    drop_operand(current_frame, operand_stack, from_valtype(branch_frame_type.value));
end;

procedure push_branch_immediates(const branch_frame: TControlFrame;
  stack_height: Integer; instructions: TArray<Byte>);
begin
  // How many stack items to drop when taking the branch.
  var stack_drop := stack_height - branch_frame.parent_stack_height;

  // Push frame start location as br immediates - these are final if frame is loop,
  // but for block/if/else these are just placeholders, to be filled at end instruction.
  TUtils.push<Uint32>(instructions, Uint32(branch_frame.code_offset));
  TUtils.push<Uint32>(instructions, Uint32(stack_drop));
end;

function parseExpr(var buf: TInputBuffer; funcIidx: TFuncIdx;
  const locals: TArray<TLocals>; const module: TModule): TCode;
begin

end;

end.

