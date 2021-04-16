(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Tests;

interface

uses
  System.SysUtils, System.Math, TestFramework, DUnitX.TestFramework,
  Oz.Wasm.Instruction;

type

  Tst = class(TObject)
  const
    F32AbsMask = Uint32($7fffffff);
    F32SignMask = Uint32(not $7fffffff);
    F64AbsMask = Uint64($fffffffffffffff);
    F64SignMask = Uint64(not $fffffffffffffff);
  public
    function MinSingle(a, b: Single): Single;
  end;

  TestTst = class(TTestCase)
  strict private
    FMyTestObject: Tst;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestMinSingle;
  end;

implementation

{ Tst }

function Tst.MinSingle(a, b: Single): Single;
type
  V32 = record
    case Integer of
      1: (i32: Uint32);
      2: (f32: Single);
  end;
begin
  if a.IsNan or b.IsNan then
    Result := Single.NaN
  else if (a = 0) and (b = 0) and
    ((V32(a).i32 and F32SignMask <> 0) or
     (V32(b).i32 and F32SignMask <> 0)) then
    Result := Single(-0)
  else if b < a then
    Result := b
  else
    Result := a;
end;

procedure TestTst.SetUp;
begin
  FMyTestObject := Tst.Create;
end;

procedure TestTst.TearDown;
begin
  FMyTestObject.Free;
  FMyTestObject := nil;
end;

procedure TestTst.TestMinSingle;
var
  a, b, ReturnValue: Single;
begin
  a := -0.0;
  b := 1.0;
  ReturnValue := FMyTestObject.MinSingle(a, b);
  CheckTrue(ReturnValue = -Single(0.0))
end;

initialization
  RegisterTest(TestTst.Suite);
end.

