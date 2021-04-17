unit Oz.Wasm.TestNumeric;

interface

uses
  System.SysUtils, System.Math, TestFramework, DUnitX.TestFramework,
  Oz.Wasm.Instruction;

type
  TestNumeric = class(TTestCase)
  published
    procedure Test_i32_clz;
    procedure Test_i32_ctz;
    procedure Test_i32_popcnt;
    procedure Test_i64_clz;
    procedure Test_i64_ctz;
    procedure Test_i64_popcnt;
  end;

implementation

type
  TUint32Pair = record v, r: Uint32; end;
  TUint64Pair = record v, r: Uint64; end;

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
  Tests: array [0..3] of TUint64Pair = (
    (v: 0; r: 64),
    (v: 1; r: 0),
    (v: 4; r: 64 - 2),
    (v: $7f; r: 64 - 7));
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
