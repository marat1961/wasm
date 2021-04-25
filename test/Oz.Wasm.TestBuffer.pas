(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.TestBuffer;

interface

uses
  System.SysUtils, System.Math, TestFramework, DUnitX.TestFramework,
  Oz.Wasm.Buffer;

{$Region 'TestLeb128'}

type
  TestLeb128 = class(TTestCase)
  published
    procedure Test_decode_u64;
  end;

{$EndRegion}

implementation

{$Region 'TestLeb128'}

procedure TestLeb128.Test_decode_u64;
type
  TestPair = record
    d: AnsiString;
    r: Uint64;
  end;
const
  tests: array [0..13] of TestPair = (
    (d: '00'; r: 0),                                    // 0
    (d: '808000'; r: 0),                                // 0 with leading zeroes
    (d: '01'; r: 1),                                    // 1
    (d: '81808000'; r: 1),                              // 1 with leading zeroes
    (d: '81808080808080808000'; r: 1),                  // 1 with max leading zeroes
    (d: 'e58e26'; r: 624485),                           // 624485
    (d: 'e58ea6808000'; r: 624485),                     // 624485 with leading zeroes
    (d: 'ffffffff07'; r: $7fffffff),                    //
    (d: '8080808008'; r: $80000000),                    //
    (d: 'ffffffffffffff00'; r: 562949953421311),        // bigger than int32
    (d: 'ffffffffffffff808000'; r: 562949953421311),    // bigger than int32 with zeroes
    (d: 'ffffffffffffffff7f'; r: $7fffffffffffffff),
    (d: '80808080808080808001'; r: $8000000000000000),
    (d: 'ffffffffffffffffff01'; r: 9223372036854775807));
begin

end;

{$EndRegion}

initialization
  RegisterTest(TestLeb128.Suite);
end.
