(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.TestNumeric;

interface

uses
  System.SysUtils, System.Math, TestFramework, DUnitX.TestFramework,
  Oz.Wasm.Operations, Oz.Wasm.Value, Oz.Wasm.Types, Oz.Wasm.Module,
  Oz.Wasm.Instruction, Oz.Wasm.Instantiate, Oz.Wasm.Interpreter;

type
  TestNumeric = class(TTestCase)
  private
    function createUnaryOperationExecutor(instr: TInstruction;
      const args: PValue): TExecutionResult;
    function createBinaryOperationExecutor(instr: TInstruction;
      const args: PValue): TExecutionResult;
  published
    procedure Test_i32_shl;
    procedure Test_i64_shl;

    procedure Test_i32_shr;
    procedure Test_i64_shr;

    procedure Test_i32_clz;
    procedure Test_i64_clz;

    procedure Test_i32_ctz;
    procedure Test_i64_ctz;

    procedure Test_i32_popcnt;
    procedure Test_i64_popcnt;
  end;

implementation

type
  TUint32Pair = record v, r: Uint32; end;
  TUint64Pair = record v, r: Uint64; end;
  TUint32Trio = record a, b, r: Uint32; end;
  TUint64Trio = record a, b, r: Uint64; end;
  TInt32Trio = record a, b, r: Int32; end;
  TInt64Trio = record a, b, r: Int64; end;

function TestNumeric.createUnaryOperationExecutor(
  instr: TInstruction; const args: PValue): TExecutionResult;
var
  ityp: TInstructionType;
  module: TModule;
  ftyp: TFuncType;
  code: TCode;
  instance: PInstance;
begin
  ityp := getInstructionTypeTable[instr];
  Check(ityp.inputsSize = 1);
  Check(ityp.outputsSize = 1);
  ftyp := TFuncType.From(ityp);
  module.typesec := [ftyp];
  module.funcsec := [TTypeIdx(0)];
  code.maxStackHeight := 1;
  code.localCount := 0;
  code.instructions := [Byte(TInstruction.local_get), 0, 0, 0, 0,
    Byte(instr), Byte(TInstruction.end)];
  module.codesec := [code];
  instance := Instantiate(module);
  Result := Execute(instance, {funcIdx=}0, args);
end;

function TestNumeric.createBinaryOperationExecutor(
  instr: TInstruction; const args: PValue): TExecutionResult;
var
  ityp: TInstructionType;
  module: TModule;
  ftyp: TFuncType;
  code: TCode;
  instance: PInstance;
begin
  ityp := getInstructionTypeTable[instr];
  Check(ityp.inputsSize = 2);
  Check(ityp.outputsSize = 1);
  ftyp := TFuncType.From(ityp);
  module.typesec := [ftyp];
  module.funcsec := [TTypeIdx(0)];
  code.maxStackHeight := 2;
  code.localCount := 0;
  code.instructions := [Byte(TInstruction.local_get), 0, 0, 0, 0,
    Byte(TInstruction.local_get), 1, 0, 0, 0, Byte(instr), Byte(TInstruction.end)];
  module.codesec := [code];
  instance := Instantiate(module);
  Result := Execute(instance, {funcIdx=}0, args);
end;

procedure TestNumeric.Test_i32_shl;
const
  Tests: array [0..6] of TInt32Trio = (
    (a: 21; b: 1; r: 42),
    (a: $ffffffff; b: 0; r: $ffffffff),
    (a: $ffffffff; b: 1; r: $fffffffe),
    (a: $ffffffff; b: 31; r: $80000000),
    (a: $ffffffff; b: 32; r: $ffffffff),
    (a: $ffffffff; b: 33; r: $fffffffe),
    (a: $ffffffff; b: 63; r: $80000000));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := test.a shl test.b;
    Check(r = test.r);
  end;
end;

procedure TestNumeric.Test_i64_shl;
begin

end;

procedure TestNumeric.Test_i32_shr;
const
  Tests: array [0..15] of TInt32Trio = (
    (a: Uint32(-84); b: 1; r: -42),
    (a: $ffffffff; b: 0; r: $ffffffff),
    (a: $ffffffff; b: 1; r: $ffffffff),
    (a: $ffffffff; b: 31; r: $ffffffff),
    (a: $ffffffff; b: 32; r: $ffffffff),
    (a: $ffffffff; b: 33; r: $ffffffff),
    (a: $ffffffff; b: 63; r: $ffffffff),
    (a: $7fffffff; b: 0; r: $7fffffff),
    (a: $7fffffff; b: 1; r: $3fffffff),
    (a: $7fffffff; b: 30; r: 1),
    (a: $7fffffff; b: 31; r: 0),
    (a: $7fffffff; b: 32; r: $7fffffff),
    (a: $7fffffff; b: 33; r: $3fffffff),
    (a: $7fffffff; b: 62; r: 1),
    (a: $7fffffff; b: 63; r: 0),
    (a: 1; b: Uint32(-1); r: 0));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := Ash32(test.a, test.b);
    Check(r = test.r);
  end;
end;

procedure TestNumeric.Test_i64_shr;
const
  Tests: array [0..15] of TInt64Trio = (
    (a: -84; b: 1; r: -42),
    (a: $ffffffffffffffff; b: 0; r: $ffffffffffffffff),
    (a: $ffffffffffffffff; b: 1; r: $ffffffffffffffff),
    (a: $ffffffffffffffff; b: 63; r: $ffffffffffffffff),
    (a: $ffffffffffffffff; b: 64; r: $ffffffffffffffff),
    (a: $ffffffffffffffff; b: 65; r: $ffffffffffffffff),
    (a: $ffffffffffffffff; b: 127; r: $ffffffffffffffff),
    (a: $7fffffffffffffff; b: 0; r: $7fffffffffffffff),
    (a: $7fffffffffffffff; b: 1; r: $3fffffffffffffff),
    (a: $7fffffffffffffff; b: 62; r: 1),
    (a: $7fffffffffffffff; b: 63; r: 0),
    (a: $7fffffffffffffff; b: 64; r: $7fffffffffffffff),
    (a: $7fffffffffffffff; b: 65; r: $3fffffffffffffff),
    (a: $7fffffffffffffff; b: 126; r: 1),
    (a: $7fffffffffffffff; b: 127; r: 0),
    (a: 1; b: -1; r: 0));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := Ash64(test.a, test.b);
    Check(r = test.r);
  end;
end;

procedure TestNumeric.Test_i32_clz;
const
  Tests: array [0..3] of TUint32Pair = (
    (v: 0; r: 32),
    (v: 1; r: 31),
    (v: 5; r: 29),
    (v: $7f; r: 25));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := clz32(test.v);
    Check(r = test.r);
  end;
end;

procedure TestNumeric.Test_i32_ctz;
const
  Tests: array [0..3] of TUint32Pair = (
    (v: 0; r: 32),
    (v: 1; r: 0),
    (v: 4; r: 2),
    (v: $80; r: 7));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := ctz32(test.v);
    Check(r = test.r);
  end;
end;

procedure TestNumeric.Test_i32_popcnt;
const
  Tests: array [0..11] of TUint32Pair = (
    (v: 0; r: 0),
    (v: 1; r: 1),
    (v: $7f; r: 7),
    (v: $80; r: 1),
    (v: $12345678; r: 13),
    (v: $ffffffff; r: 32),
    (v: $ffff0000; r: 16),
    (v: $0000ffff; r: 16),
    (v: $00ffff00; r: 16),
    (v: $00ff00ff; r: 16),
    (v: $007f8001; r: 9),
    (v: $0055ffaa; r: 16));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := popcount32(test.v);
    Check(r = test.r);
  end;
end;

procedure TestNumeric.Test_i64_clz;
const
  Tests: array [0..6] of TUint64Pair = (
    (v: 0; r: 64),
    (v: 1; r: 64 - 1),
    (v: 4; r: 64 - 3),
    (v: $7f; r: 64 - 7),
    (v: $0000ffff; r: 64 - 16),
    (v: $0f00000000000000; r: 64 - 60),
    (v: $f000000000000000; r: 64 - 64));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := clz64(test.v);
    Check(r = test.r);
  end;
end;

procedure TestNumeric.Test_i64_ctz;
const
  Tests: array [0..6] of TUint64Pair = (
    (v: 0; r: 64),
    (v: 1; r: 0),
    (v: 4; r: 2),
    (v: $80; r: 7),
    (v: $000f0000; r: 16),
    (v: $0800000000000000; r: 59),
    (v: $8000000000000000; r: 63));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := ctz64(test.v);
    Check(r = test.r);
  end;
end;

procedure TestNumeric.Test_i64_popcnt;
const
  Tests: array [0..11] of TUint64Pair = (
    (v: 0; r: 0),
    (v: 1; r: 1),
    (v: $7f; r: 7),
    (v: $80; r: 1),
    (v: $1234567890abcdef; r: 32),
    (v: $ffffffffffffffff; r: 64),
    (v: $ffffffff00000000; r: 32),
    (v: $00000000ffffffff; r: 32),
    (v: $0000ffffffff0000; r: 32),
    (v: $00ff00ff00ff00ff; r: 32),
    (v: $007f8001007f8001; r: 18),
    (v: $0055ffaa0055ffaa; r: 32));
begin
  for var i := 0 to High(Tests) do
  begin
    var test := Tests[i];
    var r := popcount64(test.v);
    Check(r = test.r);
  end;
end;

initialization
  RegisterTest(TestNumeric.Suite);
end.
