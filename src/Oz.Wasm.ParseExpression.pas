(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.ParseExpression;

interface

uses
  System.SysUtils,
//  System.Math, System.Generics.Collections,
  Oz.Wasm.Utils, Oz.Wasm.Buffer,
// Oz.Wasm.Value, Oz.Wasm.Limits,
  Oz.Wasm.Instruction, Oz.Wasm.Types, Oz.Wasm.Module;

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

  TOperandStackType = TValType;

  TUtils = record
    procedure store<T>(dst: PByte; const value: T); inline;
    procedure push<T>(var b: TBytes; const value: T); inline;
  end;

constructor TControlFrame.From(instr: TInstruction; typ: TOptional<TValType>;
  parentStackHeight, codeOffset: Integer);
begin
  Self.instruction := instr;
  Self.typ := typ;
  Self.code_offset := code_offset;
  Self.parent_stack_height := parentStackHeight;
end;

procedure TUtils.store<T>(dst: PByte; const value: T);
begin
  Move(value, dst^, sizeof(value));
end;

procedure TUtils.push<T>(var b: TBytes; const value: T);
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

function parseExpr(var buf: TInputBuffer; funcIidx: TFuncIdx;
  const locals: TArray<TLocals>; const module: TModule): TCode;
begin

end;

end.

