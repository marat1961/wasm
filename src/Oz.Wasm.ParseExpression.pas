(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.ParseExpression;

interface

uses
  System.SysUtils, System.Math,
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

function parseVec32(var buf: TInputBuffer): TArray<Uint32>;

implementation

// The control frame to keep information about labels and blocks as defined in
// Wasm Validation Algorithm https://webassembly.github.io/spec/core/appendix/algorithm.html.
type
  PControlFrame = ^TControlFrame;
  TControlFrame = record
  var
    // The instruction that created the label.
    instruction: TInstruction;
    // Return result type of the frame.
    typ: TOptional<TValType>;
    // The target instruction code offset.
    code_offset: Integer;
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

function parseVec32(var buf: TInputBuffer): TArray<Uint32>;
var
  size: UInt32;
begin
  size := buf.readUint32;
  Assert(size < 128);
  SetLength(Result, size);
  for var i := 0 to size - 1 do
    Result[i] := buf.readUint32;
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

procedure updateOperandStack(frame: PControlFrame; var stack: TStack<TOperandStackType>;
  inputs, outputs: array of TValType);
begin
  var frameStackHeight := Integer(stack.Size);
  var inpSize := Length(inputs);

  // Stack is polymorphic after unreachable instruction: underflow is ignored,
  // but we need to count stack growth to detect extra values at the end of the block.
  if not frame.unreachable and
     (frameStackHeight < frame.parent_stack_height + inpSize) then
    raise EWasmError.Create('stack underflow');

  // Update stack.
  for var i := 0 to High(inputs) do
  begin
    var expectedType := inputs[i];
    // Underflow is ignored for unreachable frame.
    if frame.unreachable and
       (Integer(stack.size) = frame.parent_stack_height) then
      break;
    var actualType := stack.pop;
    if not type_matches(actualType, expectedType) then
      raise EWasmError.Create('type mismatch');
  end;
  // Push output values even if frame is unreachable.
  for var i := 0 to High(outputs) do
    stack.push(from_valtype(outputs[i]));
end;

procedure drop_operand(frame: PControlFrame; var operand_stack: TStack<TOperandStackType>;
  expected_type: TOperandStackType); overload; inline;
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

procedure drop_operand(frame: PControlFrame; var operand_stack: TStack<TOperandStackType>;
  expected_type: TValType); overload; inline ;
begin
  drop_operand(frame, operand_stack, from_valtype(expected_type));
end;

procedure update_result_stack(frame: PControlFrame; var operand_stack: TStack<TOperandStackType>);
begin
  var frame_stack_height := Integer(operand_stack.Size);
  // This is checked by 'stack underflow'.
  Assert(frame_stack_height >= frame.parent_stack_height);
  var arity := Ord(frame.typ.hasValue);
  if frame_stack_height > frame.parent_stack_height + arity then
    raise EWasmError.Create('too many results');
  if arity <> 0 then
    drop_operand(frame, operand_stack, from_valtype(frame.typ.value));
end;

function get_branch_frame_type(frame: PControlFrame): TOptional<TValType>; inline;
begin
  // For loops arity is considered always 0, because br executed in loop jumps to the top,
  // resetting frame stack to 0, so it should not keep top stack value even if loop has a result.
  if frame.instruction = TInstruction.loop then
    Result.Reset
  else
    Result := frame.typ;
end;

function get_branch_arity(frame: PControlFrame): Uint32; inline;
begin
  Result := Ord(get_branch_frame_type(frame).hasValue);
end;

procedure update_branch_stack(current_frame, branch_frame: PControlFrame;
  var operand_stack: TStack<TOperandStackType>); inline;
begin
  Assert(Integer(operand_stack.Size) >= current_frame.parent_stack_height);
  var branch_frame_type := get_branch_frame_type(branch_frame);
  if branch_frame_type.hasValue then
    drop_operand(current_frame, operand_stack, from_valtype(branch_frame_type.value));
end;

procedure push_branch_immediates(branch_frame: PControlFrame;
  stack_height: Integer; instructions: TArray<Byte>);
begin
  // How many stack items to drop when taking the branch.
  var stack_drop := stack_height - branch_frame.parent_stack_height;

  // Push frame start location as br immediates - these are final if frame is loop,
  // but for block/if/else these are just placeholders, to be filled at end instruction.
  TUtils.push<Uint32>(instructions, Uint32(branch_frame.code_offset));
  TUtils.push<Uint32>(instructions, Uint32(stack_drop));
end;

procedure mark_frame_unreachable(frame: PControlFrame;
  var operand_stack: TStack<TOperandStackType>); inline;
begin
  frame.unreachable := True;
  operand_stack.shrink(Integer(frame.parent_stack_height));
end;

procedure push_operand(var operand_stack: TStack<TOperandStackType>; typ: TValType); overload; inline;
begin
  operand_stack.push(from_valtype(typ));
end;

procedure push_operand(var operand_stack: TStack<TOperandStackType>; typ: TOperandStackType); overload; inline;
begin
  operand_stack.push(typ);
end;

function find_local_type(const params: TArray<TValType>; const locals: TArray<TLocals>;
  idx: TLocalIdx): TValType;
begin
  if idx < Length(params) then
    Result := params[idx];
  var local_idx := idx - Length(params);
  var local_count: Uint64 := 0;
  for var l in locals do
  begin
    if (local_idx >= local_count) and (local_idx < local_count + l.count) then
      exit(l.typ);
    Inc(local_count, l.count);
  end;
  raise EWasmError.Create('invalid local index');
end;

function parseExpr(var buf: TInputBuffer; funcIidx: TFuncIdx;
  const locals: TArray<TLocals>; const module: TModule): TCode;
var
  code: TCode;
  // The stack of control frames allowing to distinguish between block/if/else
  // and label instructions as defined in Wasm Validation Algorithm.
  operand_stack: TStack<TOperandStackType>;
  control_stack: TStack<TControlFrame>;
begin
  var func_type_idx := module.funcsec[funcIidx];
  Assert(func_type_idx < Length(module.typesec));
  var func_type := module.typesec[func_type_idx];

  var func_inputs := func_type.inputs;
  var func_outputs := func_type.outputs;
  // The function's implicit block.

  var tf := Default(TControlFrame);
  tf.instruction := TInstruction.block;
  if Length(func_outputs) > 0 then
    tf.typ := TOptional<TValType>.From(func_outputs[0]);
  control_stack.Emplace(tf);

  var type_table := geTInstructionTypeTable;
  var max_align_table := geTInstructionMaxAlignTable;

  var continue_parsing := True;
  while continue_parsing do
  begin
    var opcode := buf.readByte;
    var instr := TInstruction(opcode);
    var frame := control_stack.top;
    var typ := type_table[instr];
    var max_align := max_align_table[instr];

    // Update code's maxStackHeight using frame.stack_height of the previous instruction.
    // At this point frame.stack_height includes additional changes to the stack height
    // if the previous instruction is a call/call_indirect.
    // This way the update is skipped for end/else instructions (because their frame is
    // already popped/reset), but it does not matter, as these instructions do not modify
    // stack height anyway.
    if not frame.unreachable then
      code.maxStackHeight := Max(code.maxStackHeight, Integer(operand_stack.Size));

    updateOperandStack(frame, operand_stack, typ.inputs, typ.outputs);

    case instr of
      TInstruction.unreachable:
        mark_frame_unreachable(frame, operand_stack);
      TInstruction.drop:
        drop_operand(frame, operand_stack, TOperandStackType.none);
      TInstruction.select:
        begin
          var frame_stack_height := Integer(operand_stack.Size);
          // Two operands are expected, because the selector operand was already popped
          // according to instruction type table
          if not frame.unreachable and
             (frame_stack_height < frame.parent_stack_height + 2) then
            raise EWasmError.Create('stack underflow');
          var operand_type := TOperandStackType.none;
          if frame_stack_height > frame.parent_stack_height then
            operand_type := operand_stack[0]^;
          drop_operand(frame, operand_stack, operand_type);
          drop_operand(frame, operand_stack, operand_type);
          push_operand(operand_stack, operand_type);
        end;
      TInstruction.nop, TInstruction.i32_eqz,
      TInstruction.i32_eq, TInstruction.i32_ne,
      TInstruction.i32_lt_s, TInstruction.i32_lt_u,
      TInstruction.i32_gt_s, TInstruction.i32_gt_u,
      TInstruction.i32_le_s, TInstruction.i32_le_u,
      TInstruction.i32_ge_s, TInstruction.i32_ge_u,
      TInstruction.i64_eqz, TInstruction.i64_eq, TInstruction.i64_ne,
      TInstruction.i64_lt_s, TInstruction.i64_lt_u,
      TInstruction.i64_gt_s, TInstruction.i64_gt_u,
      TInstruction.i64_le_s, TInstruction.i64_le_u,
      TInstruction.i64_ge_s, TInstruction.i64_ge_u,
      TInstruction.f32_eq, TInstruction.f32_ne,
      TInstruction.f32_lt, TInstruction.f32_gt,
      TInstruction.f32_le, TInstruction.f32_ge,
      TInstruction.f64_eq, TInstruction.f64_ne,
      TInstruction.f64_lt, TInstruction.f64_gt,
      TInstruction.f64_le, TInstruction.f64_ge,
      TInstruction.i32_clz, TInstruction.i32_ctz, TInstruction.i32_popcnt,
      TInstruction.i32_add, TInstruction.i32_sub, TInstruction.i32_mul,
      TInstruction.i32_div_s, TInstruction.i32_div_u,
      TInstruction.i32_rem_s, TInstruction.i32_rem_u,
      TInstruction.i32_and, TInstruction.i32_or, TInstruction.i32_xor,
      TInstruction.i32_shl, TInstruction.i32_shr_s, TInstruction.i32_shr_u,
      TInstruction.i32_rotl, TInstruction.i32_rotr,
      TInstruction.i64_clz, TInstruction.i64_ctz, TInstruction.i64_popcnt,
      TInstruction.i64_add, TInstruction.i64_sub, TInstruction.i64_mul,
      TInstruction.i64_div_s, TInstruction.i64_div_u,
      TInstruction.i64_rem_s, TInstruction.i64_rem_u,
      TInstruction.i64_and, TInstruction.i64_or, TInstruction.i64_xor,
      TInstruction.i64_shl, TInstruction.i64_shr_s, TInstruction.i64_shr_u,
      TInstruction.i64_rotl, TInstruction.i64_rotr,
      TInstruction.f32_abs, TInstruction.f32_neg,
      TInstruction.f32_ceil, TInstruction.f32_floor, TInstruction.f32_trunc,
      TInstruction.f32_nearest, TInstruction.f32_sqrt,
      TInstruction.f32_add, TInstruction.f32_sub,
      TInstruction.f32_mul, TInstruction.f32_div,
      TInstruction.f32_min, TInstruction.f32_max,
      TInstruction.f32_copysign, TInstruction.f64_abs, TInstruction.f64_neg,
      TInstruction.f64_ceil, TInstruction.f64_floor, TInstruction.f64_trunc,
      TInstruction.f64_nearest, TInstruction.f64_sqrt,
      TInstruction.f64_add, TInstruction.f64_sub,
      TInstruction.f64_mul, TInstruction.f64_div,
      TInstruction.f64_min, TInstruction.f64_max, TInstruction.f64_copysign,
      TInstruction.i32_wrap_i64,
      TInstruction.i32_trunc_f32_s, TInstruction.i32_trunc_f32_u,
      TInstruction.i32_trunc_f64_s, TInstruction.i32_trunc_f64_u,
      TInstruction.i64_extend_i32_s, TInstruction.i64_extend_i32_u,
      TInstruction.i64_trunc_f32_s, TInstruction.i64_trunc_f32_u,
      TInstruction.i64_trunc_f64_s, TInstruction.i64_trunc_f64_u,
      TInstruction.f32_convert_i32_s, TInstruction.f32_convert_i32_u,
      TInstruction.f32_convert_i64_s, TInstruction.f32_convert_i64_u,
      TInstruction.f32_demote_f64,
      TInstruction.f64_convert_i32_s, TInstruction.f64_convert_i32_u,
      TInstruction.f64_convert_i64_s, TInstruction.f64_convert_i64_u,
      TInstruction.f64_promote_f32,
      TInstruction.i32_reinterpret_f32, TInstruction.i64_reinterpret_f64,
      TInstruction.f32_reinterpret_i32, TInstruction.f64_reinterpret_i64:
        ;
      TInstruction.block:
        begin
          var t := parse_blocktype(buf);
          // Push label with immediates offset after arity.
          control_stack.emplace(TControlFrame.From(TInstruction.block, t,
            Integer(operand_stack.Size), Length(code.instructions)));
        end;
      TInstruction.loop:
        begin
          var t: TOptional<TValType> := parse_blocktype(buf);
          control_stack.emplace(TControlFrame.From(TInstruction.loop, t,
            Integer(operand_stack.Size), Length(code.instructions)));
        end;
      TInstruction.if:
        begin
          var t := parse_blocktype(buf);
          control_stack.emplace(TControlFrame.From(TInstruction.if, t,
            Integer(operand_stack.Size), Length(code.instructions)));
          // Placeholders for immediate values,
          // filled at the matching end or else instructions.
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, 0);  // Diff to the else instruction
          continue;
        end;
      TInstruction.else:
        begin
          if frame.instruction <> TInstruction.if then
            raise EWasmError.Create('unexpected else instruction (if instruction missing)');
          update_result_stack(frame, operand_stack);  // else is the end of if.
          var if_imm_offset := frame.code_offset + 1;
          var frame_type := frame.typ;
          var frame_br_immediate_offsets := frame.br_immediate_offsets;
          control_stack.pop;
          control_stack.emplace(TControlFrame.From(TInstruction.else, frame_type,
            Integer(operand_stack.Size), Length(code.instructions)));
          // br immediates from `then` branch will need to be filled at the end of `else`
          control_stack.top.br_immediate_offsets := frame_br_immediate_offsets;
          code.instructions := code.instructions + [opcode];
          // Placeholder for the immediate value, filled at the matching end instructions.
          TUtils.push(code.instructions, 0);  // Diff to the end instruction.
          // Fill in if's immediate with the offset of first instruction in else block.
          var target_pc := Uint32(Length(code.instructions));
          // Set the imm values for if instruction.
          var if_imm := PByte(@code.instructions[0]) + if_imm_offset;
          TUtils.store(if_imm, target_pc);
          continue;
        end;
      TInstruction.end:
        begin
          update_result_stack(frame, operand_stack);
          if frame.typ.hasValue and (frame.instruction = TInstruction.if) then
            raise EWasmError.Create('missing result in else branch');
          // If end of block/if/else instruction.
          if frame.instruction <> TInstruction.loop then
          begin
            // In case it's an outermost implicit function block,
            // we want br to jump to the final end of the function.
            // Otherwise jump to the next instruction after block's end.
            var target_pc: Uint32 := Length(code.instructions);
            if control_stack.Size <> 1 then
              Inc(target_pc);
            if (frame.instruction = TInstruction.if) or
               (frame.instruction = TInstruction.else) then
            begin
              // We're at the end instruction of the if block without else or at the end of
              // else block. Fill in if/else's immediate with the offset of first instruction
              // after if/else block.
              var if_imm := PByte(@code.instructions[0]) + frame.code_offset + 1;
              TUtils.store(if_imm, target_pc);
            end;
            // Fill in immediates all br/br_table instructions jumping out of this block.
            for var br_imm_offset in frame.br_immediate_offsets do
            begin
              var br_imm := PByte(@code.instructions[0]) + br_imm_offset;
              TUtils.store(br_imm, Uint32(target_pc));
              // stack drop and arity were already stored in br handler
            end;
          end;
          var frame_type := frame.typ;
          operand_stack.shrink(Integer(frame.parent_stack_height));
          control_stack.pop;  // Pop the current frame.
          if control_stack.empty then
            continue_parsing := False
          else if frame_type.hasValue then
            push_operand(operand_stack, frame_type.value);
      end;
      TInstruction.br, TInstruction.br_if:
        begin
          var label_idx := buf.readUint32;
          if label_idx >= control_stack.Size then
            raise EWasmError.Create('invalid label index');
          var branch_frame := control_stack[label_idx];
          update_branch_stack(frame, branch_frame, operand_stack);
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, get_branch_arity(branch_frame));
          // Remember this br immediates offset to fill it at end instruction.
          branch_frame.br_immediate_offsets :=
            branch_frame.br_immediate_offsets + [Length(code.instructions)];
          push_branch_immediates(
            branch_frame, Integer(operand_stack.Size), code.instructions);
          if instr = TInstruction.br then
            mark_frame_unreachable(frame, operand_stack)
          else
          begin
            // For the case when branch is not taken for br_if,
            // we push back the block result value, that was popped in update_branch_stack.
            var branch_frame_type := get_branch_frame_type(branch_frame);
            if branch_frame_type.hasValue then
              push_operand(operand_stack, branch_frame.typ.value);
          end;
          continue;
        end;
      TInstruction.br_table:
        begin
          var label_indices := parseVec32(buf);
          var default_label_idx := buf.readUint32;
          for var label_idx in label_indices do
            if label_idx >= control_stack.Size then
              raise EWasmError.Create('invalid label index');
          if default_label_idx >= control_stack.Size then
            raise EWasmError.Create('invalid label index');
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, Uint32(Length(label_indices)));
          var default_branch_frame := control_stack[default_label_idx];
          var default_branch_type := get_branch_frame_type(default_branch_frame);
          update_branch_stack(frame, default_branch_frame, operand_stack);
          // arity is the same for all indices, so we push it once
          TUtils.push(code.instructions, get_branch_arity(default_branch_frame));
          // Remember immediates offset for all br items to fill them at end instruction.
          for var idx in label_indices do
          begin
            var branch_frame := control_stack[idx];
            if get_branch_frame_type(branch_frame).Equals(default_branch_type) then
              raise EWasmError.Create('br_table labels have inconsistent types');
            branch_frame.br_immediate_offsets :=
              branch_frame.br_immediate_offsets + [Length(code.instructions)];
            push_branch_immediates(
              branch_frame, Integer(operand_stack.Size), code.instructions);
          end;
          default_branch_frame.br_immediate_offsets :=
            default_branch_frame.br_immediate_offsets + [Length(code.instructions)];
          push_branch_immediates(
            default_branch_frame, Integer(operand_stack.Size), code.instructions);
          mark_frame_unreachable(frame, operand_stack);
          continue;
        end;
      TInstruction.return:
        begin
          // return is identical to br MAX
          Assert(not control_stack.empty);
          var label_idx := Uint32(control_stack.Size - 1);
          var branch_frame := control_stack[label_idx];
          update_branch_stack(frame, branch_frame, operand_stack);
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, get_branch_arity(branch_frame));
          branch_frame.br_immediate_offsets :=
            branch_frame.br_immediate_offsets + [Length(code.instructions)];
          push_branch_immediates(
            branch_frame, Integer(operand_stack.Size), code.instructions);
          mark_frame_unreachable(frame, operand_stack);
          continue;
        end;
      TInstruction.call:
        begin
          var callee_func_idx := buf.readUint32;
          if callee_func_idx >= Length(module.importedFunctionTypes) + Length(module.funcsec) then
            raise EWasmError.Create('invalid funcidx encountered with call');
          var callee_func_type := module.getFunctionType(callee_func_idx);
          updateOperandStack(
            frame, operand_stack, callee_func_type.inputs, callee_func_type.outputs);
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, callee_func_idx);
          continue;
        end;
      TInstruction.call_indirect:
        begin
          if not module.hasTable then
            raise EWasmError.Create('call_indirect without defined table');
          var callee_type_idx := buf.readUint32;
          if callee_type_idx >= Length(module.typesec) then
            raise EWasmError.Create('invalid type index with call_indirect');
          var callee_func_type := module.typesec[callee_type_idx];
          updateOperandStack(
            frame, operand_stack, callee_func_type.inputs, callee_func_type.outputs);
          var table_idx := buf.readByte;
          if table_idx <> 0 then
            raise EWasmError.Create('invalid tableidx encountered with call_indirect');
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, callee_type_idx);
          continue;
        end;
      TInstruction.local_get:
        begin
          var local_idx := buf.readUint32;
          push_operand(operand_stack, find_local_type(func_inputs, locals, local_idx));
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, local_idx);
          continue;
        end;
      TInstruction.local_set:
        begin
          var local_idx := buf.readUint32;
          drop_operand(frame, operand_stack, find_local_type(func_inputs, locals, local_idx));
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, local_idx);
          continue;
        end;
      TInstruction.local_tee:
        begin
          var local_idx := buf.readUint32;
          var local_type := find_local_type(func_inputs, locals, local_idx);
          drop_operand(frame, operand_stack, local_type);
          push_operand(operand_stack, local_type);
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, local_idx);
          continue;
        end;
      TInstruction.global_get:
        begin
          var global_idx := buf.readUint32;
          if global_idx >= module.getGlobalCount then
            raise EWasmError.Create('accessing global with invalid index');
          push_operand(operand_stack, module.getGlobalType(global_idx).valueType);
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, global_idx);
          continue;
        end;
      TInstruction.global_set:
        begin
          var global_idx := buf.readUint32;
          if global_idx >= module.getGlobalCount then
            raise EWasmError.Create('accessing global with invalid index');
          if not module.getGlobalType(global_idx).isMutable then
            raise EWasmError.Create('trying to mutate immutable global');
          drop_operand(frame, operand_stack, module.getGlobalType(global_idx).valueType);
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, global_idx);
          continue;
        end;
      TInstruction.i32_const:
        begin
          var value: Int32 := buf.readInt32;
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, Uint32(value));
          continue;
        end;
      TInstruction.i64_const:
        begin
          var value: Int64 := buf.readInt64;
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, Uint64(value));
          continue;
        end;
      TInstruction.f32_const:
        begin
          var value := buf.readValue<Uint32>;
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, value);
          continue;
        end;
      TInstruction.f64_const:
        begin
          var value := buf.readValue<Uint64>;
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, value);
          continue;
        end;
      TInstruction.i32_load, TInstruction.i64_load,
      TInstruction.f32_load, TInstruction.f32_store,
      TInstruction.i32_load8_s, TInstruction.i32_load8_u,
      TInstruction.i32_load16_s, TInstruction.i32_load16_u,
      TInstruction.i64_load8_s, TInstruction.i64_load8_u,
      TInstruction.i64_load16_s, TInstruction.i64_load16_u,
      TInstruction.i64_load32_s, TInstruction.i64_load32_u,
      TInstruction.i32_store, TInstruction.i64_store,
      TInstruction.f64_load, TInstruction.f64_store,
      TInstruction.i32_store8, TInstruction.i32_store16,
      TInstruction.i64_store8, TInstruction.i64_store16, TInstruction.i64_store32:
        begin
          var align := buf.readUint32;
          // NOTE: [0, 3] is the correct range (the hard limit is log2(64 / 8))
          // and checking it to avoid overflows
          if align > max_align then
            raise EWasmError.Create('alignment cannot exceed operand size');
          var offset := buf.readUint32;
          code.instructions := code.instructions + [opcode];
          TUtils.push(code.instructions, offset);
          if not module.hasMemory then
             raise EWasmError.Create('memory instructions require imported or defined memory');
          continue;
        end;
      TInstruction.memory_size, TInstruction.memory_grow:
        begin
          var memory_idx := buf.readByte;
          if memory_idx <> 0 then
            raise EWasmError.Create('invalid memory index encountered');
          if not module.hasMemory then
            raise EWasmError.Create('memory instructions require imported or defined memory');
        end
      else
        raise EWasmError.CreateFmt('invalid instruction %d', [(buf.current - 1)^]);
    end{case};
    code.instructions := code.instructions + [opcode];
  end;
  Assert(control_stack.empty);
  Result := code;
end;

end.

