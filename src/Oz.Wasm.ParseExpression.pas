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
    if frame.unreachable and
       (Integer(operand_stack.size) = frame.parent_stack_height) then
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

procedure mark_frame_unreachable(frame: TControlFrame;
  operand_stack: TStack<TOperandStackType>); inline;
begin
  frame.unreachable := True;
  operand_stack.shrink(Integer(frame.parent_stack_height));
end;

procedure push_operand(operand_stack: TStack<TOperandStackType>; typ: TValType); overload; inline;
begin
  operand_stack.push(from_valtype(typ));
end;

procedure push_operand(operand_stack: TStack<TOperandStackType>; typ: TOperandStackType); overload; inline;
begin
  operand_stack.push(typ);
end;

(*
TValType find_local_type(
    const TArray<TValType>& params, const TArray<Locals>& locals, LocalIdx idx)
begin
    if (idx < params.Size)
        Result := params[idx];

    // TODO: Consider more efficient algorithm with calculating cumulative sums only once and then
    // using binary search for each local instruction.
    var local_idx = idx - params.Size;
    uint64_t local_count = 0;
    for (var& l : locals)
    begin
        if (local_idx >= local_count and local_idx < local_count + l.count)
            Result := l.type;
        local_count += l.count;
    end

    raise EWasmError.Create('invalid local index');
end;

parser_result<Code> parse_expr(const PByte pos, const PByte end, FuncIdx func_idx,
    const TArray<Locals>& locals, const Module& module)
begin
  Code code;

  // The stack of control frames allowing to distinguish between block/if/else and label
  // instructions as defined in Wasm Validation Algorithm.
  Stack<TControlFrame> control_stack;

  Stack<TOperandStackType> operand_stack;

  var func_type_idx = module.funcsec[func_idx];
  Assert(func_type_idx < module.typesec.Size);
  var& func_type = module.typesec[func_type_idx];

  var& func_inputs = func_type.inputs;
  var& func_outputs = func_type.outputs;
  // The function's implicit block.
  control_stack.emplace(Instr::block,
      func_outputs.empty() ? std::nullopt : TOptional<TValType>beginfunc_outputs[0]end, 0);

  var type_table = get_instruction_type_table();
  var max_align_table = get_instruction_max_align_table();

  Boolean continue_parsing = True;
  while (continue_parsing)
  begin
      Byte opcode;
      std::tie(opcode := buf.readByte;

      var& frame = control_stack.top();
      var& type = type_table[opcode];
      var max_align = max_align_table[opcode];

      // Update code's max_stack_height using frame.stack_height of the previous instruction.
      // At this point frame.stack_height includes additional changes to the stack height
      // if the previous instruction is a call/call_indirect.
      // This way the update is skipped for end/else instructions (because their frame is
      // already popped/reset), but it does not matter, as these instructions do not modify
      // stack height anyway.
      if (not frame.unreachable)
          code.max_stack_height =
              std::max(code.max_stack_height, static_cast<Integer>(operand_stack.Size));

      update_operand_stack(frame, operand_stack, type.inputs, type.outputs);

      var instr = static_cast<Instr>(opcode);
      switch (instr)
      begin
      default:
          throw parser_errorbegin"invalid instruction " + std::to_string( *(pos - 1))end;

      TInstruction.unreachable:
          mark_frame_unreachable(frame, operand_stack);
          break;

      TInstruction.drop:
          drop_operand(frame, operand_stack, TOperandStackType.none);
          break;

      TInstruction.select:
      begin
          var frame_stack_height = static_cast<Integer>(operand_stack.Size);

          // Two operands are expected, because the selector operand was already popped
          // according to instruction type table
          if (not frame.unreachable and frame_stack_height < frame.parent_stack_height + 2)
              raise EWasmError.Create('stack underflow');


          var operand_type = frame_stack_height > frame.parent_stack_height ?
                                        operand_stack[0] :
                                        TOperandStackType.none;

          drop_operand(frame, operand_stack, operand_type);
          drop_operand(frame, operand_stack, operand_type);
          push_operand(operand_stack, operand_type);
          break;
      end

      TInstruction.nop:
      TInstruction.i32_eqz:
      TInstruction.i32_eq:
      TInstruction.i32_ne:
      TInstruction.i32_lt_s:
      TInstruction.i32_lt_u:
      TInstruction.i32_gt_s:
      TInstruction.i32_gt_u:
      TInstruction.i32_le_s:
      TInstruction.i32_le_u:
      TInstruction.i32_ge_s:
      TInstruction.i32_ge_u:
      TInstruction.i64_eqz:
      TInstruction.i64_eq:
      TInstruction.i64_ne:
      TInstruction.i64_lt_s:
      TInstruction.i64_lt_u:
      TInstruction.i64_gt_s:
      TInstruction.i64_gt_u:
      TInstruction.i64_le_s:
      TInstruction.i64_le_u:
      TInstruction.i64_ge_s:
      TInstruction.i64_ge_u:
      TInstruction.f32_eq:
      TInstruction.f32_ne:
      TInstruction.f32_lt:
      TInstruction.f32_gt:
      TInstruction.f32_le:
      TInstruction.f32_ge:
      TInstruction.f64_eq:
      TInstruction.f64_ne:
      TInstruction.f64_lt:
      TInstruction.f64_gt:
      TInstruction.f64_le:
      TInstruction.f64_ge:
      TInstruction.i32_clz:
      TInstruction.i32_ctz:
      TInstruction.i32_popcnt:
      TInstruction.i32_add:
      TInstruction.i32_sub:
      TInstruction.i32_mul:
      TInstruction.i32_div_s:
      TInstruction.i32_div_u:
      TInstruction.i32_rem_s:
      TInstruction.i32_rem_u:
      TInstruction.i32_and:
      TInstruction.i32_or:
      TInstruction.i32_xor:
      TInstruction.i32_shl:
      TInstruction.i32_shr_s:
      TInstruction.i32_shr_u:
      TInstruction.i32_rotl:
      TInstruction.i32_rotr:
      TInstruction.i64_clz:
      TInstruction.i64_ctz:
      TInstruction.i64_popcnt:
      TInstruction.i64_add:
      TInstruction.i64_sub:
      TInstruction.i64_mul:
      TInstruction.i64_div_s:
      TInstruction.i64_div_u:
      TInstruction.i64_rem_s:
      TInstruction.i64_rem_u:
      TInstruction.i64_and:
      TInstruction.i64_or:
      TInstruction.i64_xor:
      TInstruction.i64_shl:
      TInstruction.i64_shr_s:
      TInstruction.i64_shr_u:
      TInstruction.i64_rotl:
      TInstruction.i64_rotr:
      TInstruction.f32_abs:
      TInstruction.f32_neg:
      TInstruction.f32_ceil:
      TInstruction.f32_floor:
      TInstruction.f32_trunc:
      TInstruction.f32_nearest:
      TInstruction.f32_sqrt:
      TInstruction.f32_add:
      TInstruction.f32_sub:
      TInstruction.f32_mul:
      TInstruction.f32_div:
      TInstruction.f32_min:
      TInstruction.f32_max:
      TInstruction.f32_copysign:
      TInstruction.f64_abs:
      TInstruction.f64_neg:
      TInstruction.f64_ceil:
      TInstruction.f64_floor:
      TInstruction.f64_trunc:
      TInstruction.f64_nearest:
      TInstruction.f64_sqrt:
      TInstruction.f64_add:
      TInstruction.f64_sub:
      TInstruction.f64_mul:
      TInstruction.f64_div:
      TInstruction.f64_min:
      TInstruction.f64_max:
      TInstruction.f64_copysign:
      TInstruction.i32_wrap_i64:
      TInstruction.i32_trunc_f32_s:
      TInstruction.i32_trunc_f32_u:
      TInstruction.i32_trunc_f64_s:
      TInstruction.i32_trunc_f64_u:
      TInstruction.i64_extend_i32_s:
      TInstruction.i64_extend_i32_u:
      TInstruction.i64_trunc_f32_s:
      TInstruction.i64_trunc_f32_u:
      TInstruction.i64_trunc_f64_s:
      TInstruction.i64_trunc_f64_u:
      TInstruction.f32_convert_i32_s:
      TInstruction.f32_convert_i32_u:
      TInstruction.f32_convert_i64_s:
      TInstruction.f32_convert_i64_u:
      TInstruction.f32_demote_f64:
      TInstruction.f64_convert_i32_s:
      TInstruction.f64_convert_i32_u:
      TInstruction.f64_convert_i64_s:
      TInstruction.f64_convert_i64_u:
      TInstruction.f64_promote_f32:
      TInstruction.i32_reinterpret_f32:
      TInstruction.i64_reinterpret_f64:
      TInstruction.f32_reinterpret_i32:
      TInstruction.f64_reinterpret_i64:
          break;

      TInstruction.block:
      begin
          TOptional<TValType> block_type;
          std::tie(block_type := parse_blocktype(pos, end);

          // Push label with immediates offset after arity.
          control_stack.emplace(Instr::block, block_type, static_cast<Integer>(operand_stack.Size),
              code.instructions.Size);
          break;
      end

      TInstruction.loop:
      begin
          TOptional<TValType> loop_type;
          std::tie(loop_type := parse_blocktype(pos, end);

          control_stack.emplace(Instr::loop, loop_type, static_cast<Integer>(operand_stack.Size),
              code.instructions.Size);
          break;
      end

      TInstruction.if_:
      begin
          TOptional<TValType> if_type;
          std::tie(if_type := parse_blocktype(pos, end);

          control_stack.emplace(Instr::if_, if_type, static_cast<Integer>(operand_stack.Size),
              code.instructions.Size);

          // Placeholders for immediate values, filled at the matching end or else instructions.
          code.instructions.push_back(opcode);
          push(code.instructions, uint32_tbegin0end);  // Diff to the else instruction
          continue;
      end

      TInstruction.else_:
      begin
          if (frame.instruction <> Instr::if_)
              throw parser_errorbegin"unexpected else instruction (if instruction missing)');

          update_result_stack(frame, operand_stack);  // else is the end of if.

          var if_imm_offset = frame.code_offset + 1;
          var frame_type = frame.type;
          var frame_br_immediate_offsets = std::move(frame.br_immediate_offsets);

          control_stack.pop();
          control_stack.emplace(Instr::else_, frame_type, static_cast<Integer>(operand_stack.Size),
              code.instructions.Size);
          // br immediates from `then` branch will need to be filled at the end of `else`
          control_stack.top().br_immediate_offsets = std::move(frame_br_immediate_offsets);

          code.instructions.push_back(opcode);

          // Placeholder for the immediate value, filled at the matching end instructions.
          push(code.instructions, uint32_tbegin0end);  // Diff to the end instruction.

          // Fill in if's immediate with the offset of first instruction in else block.
          var target_pc = static_cast<Uint32>(code.instructions.Size);

          // Set the imm values for if instruction.
          var* if_imm = code.instructions.data() + if_imm_offset;
          store(if_imm, target_pc);
          continue;
      end

      TInstruction.end:
      begin
          update_result_stack(frame, operand_stack);

          if (frame.type.hasValue and frame.instruction = Instr::if_)
              raise EWasmError.Create('missing result in else branch');

          if (frame.instruction <> Instr::loop)  // If end of block/if/else instruction.
          begin
              // In case it's an outermost implicit function block,
              // we want br to jump to the final end of the function.
              // Otherwise jump to the next instruction after block's end.
              var target_pc = control_stack.Size = 1 ?
                                         static_cast<Uint32>(code.instructions.Size) :
                                         static_cast<Uint32>(code.instructions.Size + 1);

              if (frame.instruction = Instr::if_ or frame.instruction = Instr::else_)
              begin
                  // We're at the end instruction of the if block without else or at the end of
                  // else block. Fill in if/else's immediate with the offset of first instruction
                  // after if/else block.
                  var* if_imm = code.instructions.data() + frame.code_offset + 1;
                  store(if_imm, target_pc);
              end

              // Fill in immediates all br/br_table instructions jumping out of this block.
              for (var br_imm_offset : frame.br_immediate_offsets)
              begin
                  var* br_imm = code.instructions.data() + br_imm_offset;
                  store(br_imm, static_cast<Uint32>(target_pc));
                  // stack drop and arity were already stored in br handler
              end
          end
          var frame_type = frame.type;
          operand_stack.shrink(static_cast<Integer>(frame.parent_stack_height));
          control_stack.pop();  // Pop the current frame.

          if (control_stack.empty())
              continue_parsing = false;
          else if (frame_type.hasValue)
              push_operand(operand_stack, *frame_type);
          break;
      end

      TInstruction.br:
      TInstruction.br_if:
      begin
          Uint32 label_idx;
          std::tie(label_idx := leb128u_decode<Uint32>(pos, end);

          if (label_idx >= control_stack.Size)
              raise EWasmError.Create('invalid label index');

          var& branch_frame = control_stack[label_idx];

          update_branch_stack(frame, branch_frame, operand_stack);

          code.instructions.push_back(opcode);
          push(code.instructions, get_branch_arity(branch_frame));

          // Remember this br immediates offset to fill it at end instruction.
          branch_frame.br_immediate_offsets.push_back(code.instructions.Size);

          push_branch_immediates(
              branch_frame, static_cast<Integer>(operand_stack.Size), code.instructions);

          if (instr = Instr::br)
              mark_frame_unreachable(frame, operand_stack);
          else
          begin
              // For the case when branch is not taken for br_if,
              // we push back the block result value, that was popped in update_branch_stack.
              var branch_frame_type = get_branch_frame_type(branch_frame);
              if (branch_frame_type.hasValue)
                  push_operand(operand_stack, *branch_frame.type);
          end

          continue;
      end

      TInstruction.br_table:
      begin
          TArray<Uint32> label_indices;
          std::tie(label_indices := parse_vec_i32(pos, end);
          Uint32 default_label_idx;
          std::tie(default_label_idx := leb128u_decode<Uint32>(pos, end);

          for (var label_idx : label_indices)
          begin
              if (label_idx >= control_stack.Size)
                  raise EWasmError.Create('invalid label index');
          end

          if (default_label_idx >= control_stack.Size)
              raise EWasmError.Create('invalid label index');

          code.instructions.push_back(opcode);
          push(code.instructions, static_cast<Uint32>(label_indices.Size));

          var& default_branch_frame = control_stack[default_label_idx];
          var default_branch_type = get_branch_frame_type(default_branch_frame);

          update_branch_stack(frame, default_branch_frame, operand_stack);

          // arity is the same for all indices, so we push it once
          push(code.instructions, get_branch_arity(default_branch_frame));

          // Remember immediates offset for all br items to fill them at end instruction.
          for (var idx : label_indices)
          begin
              var& branch_frame = control_stack[idx];

              if (get_branch_frame_type(branch_frame) <> default_branch_type)
                  raise EWasmError.Create('br_table labels have inconsistent types');

              branch_frame.br_immediate_offsets.push_back(code.instructions.Size);
              push_branch_immediates(
                  branch_frame, static_cast<Integer>(operand_stack.Size), code.instructions);
          end
          default_branch_frame.br_immediate_offsets.push_back(code.instructions.Size);
          push_branch_immediates(
              default_branch_frame, static_cast<Integer>(operand_stack.Size), code.instructions);

          mark_frame_unreachable(frame, operand_stack);

          continue;
      end

      TInstruction.return_:
      begin
          // return is identical to br MAX
          Assert(not control_stack.empty());
          const Uint32 label_idx = static_cast<Uint32>(control_stack.Size - 1);

          var& branch_frame = control_stack[label_idx];

          update_branch_stack(frame, branch_frame, operand_stack);

          code.instructions.push_back(opcode);
          push(code.instructions, get_branch_arity(branch_frame));

          branch_frame.br_immediate_offsets.push_back(code.instructions.Size);

          push_branch_immediates(
              branch_frame, static_cast<Integer>(operand_stack.Size), code.instructions);

          mark_frame_unreachable(frame, operand_stack);
          continue;
      end

      TInstruction.call:
      begin
          FuncIdx callee_func_idx;
          std::tie(callee_func_idx := leb128u_decode<Uint32>(pos, end);

          if (callee_func_idx >= module.imported_function_types.Size + module.funcsec.Size)
              raise EWasmError.Create('invalid funcidx encountered with call');

          var& callee_func_type = module.get_function_type(callee_func_idx);
          update_operand_stack(
              frame, operand_stack, callee_func_type.inputs, callee_func_type.outputs);

          code.instructions.push_back(opcode);
          push(code.instructions, callee_func_idx);
          continue;
      end

      TInstruction.call_indirect:
      begin
          if (not module.has_table())
              raise EWasmError.Create('call_indirect without defined table');

          TypeIdx callee_type_idx;
          std::tie(callee_type_idx := leb128u_decode<Uint32>(pos, end);

          if (callee_type_idx >= module.typesec.Size)
              raise EWasmError.Create('invalid type index with call_indirect');

          var& callee_func_type = module.typesec[callee_type_idx];
          update_operand_stack(
              frame, operand_stack, callee_func_type.inputs, callee_func_type.outputs);

          Byte table_idx;
          std::tie(table_idx := buf.readByte;
          if (table_idx <> 0)
              throw parser_errorbegin"invalid tableidx encountered with call_indirect');

          code.instructions.push_back(opcode);
          push(code.instructions, callee_type_idx);
          continue;
      end

      TInstruction.local_get:
      begin
          LocalIdx local_idx;
          std::tie(local_idx := leb128u_decode<Uint32>(pos, end);

          push_operand(operand_stack, find_local_type(func_inputs, locals, local_idx));

          code.instructions.push_back(opcode);
          push(code.instructions, local_idx);
          continue;
      end

      TInstruction.local_set:
      begin
          LocalIdx local_idx;
          std::tie(local_idx := leb128u_decode<Uint32>(pos, end);

          drop_operand(frame, operand_stack, find_local_type(func_inputs, locals, local_idx));

          code.instructions.push_back(opcode);
          push(code.instructions, local_idx);
          continue;
      end

      TInstruction.local_tee:
      begin
          LocalIdx local_idx;
          std::tie(local_idx := leb128u_decode<Uint32>(pos, end);

          var local_type = find_local_type(func_inputs, locals, local_idx);
          drop_operand(frame, operand_stack, local_type);
          push_operand(operand_stack, local_type);

          code.instructions.push_back(opcode);
          push(code.instructions, local_idx);
          continue;
      end

      TInstruction.global_get:
      begin
          GlobalIdx global_idx;
          std::tie(global_idx := leb128u_decode<Uint32>(pos, end);

          if (global_idx >= module.get_global_count())
              raise EWasmError.Create('accessing global with invalid index');

          push_operand(operand_stack, module.get_global_type(global_idx).value_type);

          code.instructions.push_back(opcode);
          push(code.instructions, global_idx);
          continue;
      end

      TInstruction.global_set:
      begin
          GlobalIdx global_idx;
          std::tie(global_idx := leb128u_decode<Uint32>(pos, end);

          if (global_idx >= module.get_global_count())
              raise EWasmError.Create('accessing global with invalid index');

          if (not module.get_global_type(global_idx).is_mutable)
              raise EWasmError.Create('trying to mutate immutable global');

          drop_operand(frame, operand_stack, module.get_global_type(global_idx).value_type);

          code.instructions.push_back(opcode);
          push(code.instructions, global_idx);
          continue;
      end

      TInstruction.i32_const:
      begin
          int32_t value;
          std::tie(value := leb128s_decode<int32_t>(pos, end);
          code.instructions.push_back(opcode);
          push(code.instructions, static_cast<Uint32>(value));
          continue;
      end

      TInstruction.i64_const:
      begin
          int64_t value;
          std::tie(value := leb128s_decode<int64_t>(pos, end);
          code.instructions.push_back(opcode);
          push(code.instructions, static_cast<uint64_t>(value));
          continue;
      end

      TInstruction.f32_const:
      begin
          Uint32 value;
          std::tie(value := parse_value<Uint32>(pos, end);
          code.instructions.push_back(opcode);
          push(code.instructions, value);
          continue;
      end

      TInstruction.f64_const:
      begin
          uint64_t value;
          std::tie(value := parse_value<uint64_t>(pos, end);
          code.instructions.push_back(opcode);
          push(code.instructions, value);
          continue;
      end

      TInstruction.i32_load:
      TInstruction.i64_load:
      TInstruction.f32_load:
      TInstruction.f32_store:
      TInstruction.i32_load8_s:
      TInstruction.i32_load8_u:
      TInstruction.i32_load16_s:
      TInstruction.i32_load16_u:
      TInstruction.i64_load8_s:
      TInstruction.i64_load8_u:
      TInstruction.i64_load16_s:
      TInstruction.i64_load16_u:
      TInstruction.i64_load32_s:
      TInstruction.i64_load32_u:
      TInstruction.i32_store:
      TInstruction.i64_store:
      TInstruction.f64_load:
      TInstruction.f64_store:
      TInstruction.i32_store8:
      TInstruction.i32_store16:
      TInstruction.i64_store8:
      TInstruction.i64_store16:
      TInstruction.i64_store32:
      begin
          Uint32 align;
          std::tie(align := leb128u_decode<Uint32>(pos, end);
          // NOTE: [0, 3] is the correct range (the hard limit is log2(64 / 8)) and checking it to
          // avoid overflows
          if (align > max_align)
              raise EWasmError.Create('alignment cannot exceed operand size');

          Uint32 offset;
          std::tie(offset := leb128u_decode<Uint32>(pos, end);
          code.instructions.push_back(opcode);
          push(code.instructions, offset);

          if (not module.has_memory())
              raise EWasmError.Create('memory instructions require imported or defined memory');
          continue;
      end

      TInstruction.memory_size:
      TInstruction.memory_grow:
      begin
          Byte memory_idx;
          std::tie(memory_idx := buf.readByte;
          if (memory_idx <> 0)
              throw parser_errorbegin"invalid memory index encountered');

          if (not module.has_memory())
              raise EWasmError.Create('memory instructions require imported or defined memory');
          break;
      end
      end
      code.instructions.emplace_back(opcode);
  end;
  Assert(control_stack.empty());
  Result := begincode, posend;
end;
*)

function parseExpr(var buf: TInputBuffer; funcIidx: TFuncIdx;
  const locals: TArray<TLocals>; const module: TModule): TCode;
begin

end;

end.

