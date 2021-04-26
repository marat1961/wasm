(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.TestBuffer;

interface

uses
  System.SysUtils, System.Math, TestFramework, DUnitX.TestFramework,
  Oz.Wasm.Value, Oz.Wasm.Buffer;

{$Region 'TestLeb128'}

type
  TestLeb128 = class(TTestCase)
  published
    procedure Test_decode_s32;
    procedure Test_decode_s32_inv1;
    procedure Test_decode_s32_inv2;
    procedure Test_decode_s32_inv3;
    procedure Test_decode_s32_inv4;

    procedure Test_decode_u32;
    procedure Test_decode_u32_inv1;
    procedure Test_decode_u32_inv2;
    procedure Test_decode_u32_inv3;
    procedure Test_decode_u32_inv4;
    procedure Test_decode_u32_inv5;
    procedure Test_decode_u32_inv6;

    procedure Test_decode_s64;
    procedure Test_decode_s64_inv1;
    procedure Test_decode_s64_inv2;
    procedure Test_decode_s64_inv3;
    procedure Test_decode_s64_inv4;

    procedure Test_decode_u64;
    procedure Test_decode_u64_inv1;
    procedure Test_decode_u64_inv2;
    procedure Test_decode_u64_inv3;
    procedure Test_decode_u64_inv4;
    procedure Test_decode_u64_inv5;
  end;

{$EndRegion}

implementation

{$Region 'TestLeb128'}

procedure TestLeb128.Test_decode_s32;
type
  TestPair = record
    d: AnsiString;
    r: Int32;
  end;
const
  tests: array [0..15] of TestPair = (
    (d: '00'; r: 0),               // 0
    (d: '808000'; r: 0),           // 0 with leading zeroes
    (d: '01'; r: 1),               //
    (d: '81808000'; r: 1),         // 1 with leading zeroes
    (d: '8180808000'; r: 1),       // 1 with max leading zeroes
    (d: '7f'; r: -1),              //
    (d: 'ffffffff7f'; r: -1),      // -1 with leading 1s
    (d: '7e'; r: -2),              //
    (d: 'fe7f'; r: -2),            // -2 with leading 1s
    (d: 'feff7f'; r: -2),          // -2 with leading 1s
    (d: 'e58e26'; r: 624485),      //
    (d: 'e58ea68000'; r: 624485),  // 624485 with leading zeroes
    (d: 'c0bb78'; r: -123456),
    (d: '9bf159'; r: -624485),
    (d: '8180808078'; r: -2147483647),
    (d: '8080808078'; r: Int32.MinValue));
begin
  for var i := 0 to High(tests) do
  begin
    var hex := tests[i].d;
    var bytes := FromHex(hex);
    var buf := TInputBuffer.From(bytes);
    var v := buf.readInt32;
    var expected := tests[i].r;
    Check(v = expected);
    Check(buf.current = buf.begins + buf.bufferSize);
  end;
end;

procedure TestLeb128.Test_decode_u32;
type
  TestPair = record
    d: AnsiString;
    r: Uint32;
  end;
const
  tests: array [0..10] of TestPair = (
    (d: '00'; r: 0),                        // 0
    (d: '808000'; r: 0),                    // 0 with leading zeroes
    (d: '01'; r: 1),                        // 1
    (d: '81808000'; r: 1),                  // 1 with leading zeroes
    (d: '8180808000'; r: 1),                // 1 with max leading zeroes
    (d: '8200'; r: 2),                      // 2 with leading zeroes
    (d: 'e58e26'; r: 624485),               // 624485
    (d: 'e58ea68000'; r: 624485),           // 624485 with leading zeroes
    (d: 'ffffffff07'; r: $7fffffff),
    (d: '8080808008'; r: $80000000),
    (d: 'ffffffff0f'; r: Uint32.MaxValue)); // max
begin
  for var i := 0 to High(tests) do
  begin
    var hex := tests[i].d;
    var bytes := FromHex(hex);
    var buf := TInputBuffer.From(bytes);
    var v := buf.readUint32;
    var expected := tests[i].r;
    Check(v = expected);
    Check(buf.current = buf.begins + buf.bufferSize);
  end;
end;

procedure TestLeb128.Test_decode_s64;
type
  TestPair = record
    d: AnsiString;
    r: Int64;
  end;
const
  tests: array [0..15] of TestPair = (
    (d: '00'; r: 0),                                  // 0
    (d: '808000'; r: 0),                              // 0 with leading zeroes
    (d: '01'; r: 1),                                  //
    (d: '81808000'; r: 1),                            // 1 with leading zeroes
    (d: '81808080808080808000'; r: 1),                // 1 with max leading zeroes
    (d: '7f'; r: -1),                                 //
    (d: 'ffffffffffffffffff7f'; r: -1),               // -1 with leading 1s
    (d: '7e'; r: -2),                                 //
    (d: 'fe7f'; r: -2),                               // -2 with leading 1s
    (d: 'feff7f'; r: -2),                             // -2 with leading 1s
    (d: 'e58e26'; r: 624485),                         //
    (d: 'e58ea6808000'; r: 624485),                   // 624485 with leading zeroes
    (d: 'c0bb78'; r: -123456),                        //
    (d: '9bf159'; r: -624485),                        //
    (d: 'ffffffffffffff00'; r: 562949953421311),      // bigger than int32
    (d: 'ffffffffffffff808000'; r: 562949953421311)); // bigger than int32 with zeroes
begin
  for var i := 0 to High(tests) do
  begin
    var hex := tests[i].d;
    var bytes := FromHex(hex);
    var buf := TInputBuffer.From(bytes);
    var v := buf.readInt64;
    var expected := tests[i].r;
    Check(v = expected);
    Check(buf.current = buf.begins + buf.bufferSize);
  end;
end;

procedure TestLeb128.Test_decode_u64;
type
  TestPair = record
    d: AnsiString;
    r: Uint64;
  end;
const
  tests: array [0..13] of TestPair = (
    (d: '00'; r: 0),                                   // 0
    (d: '808000'; r: 0),                               // 0 with leading zeroes
    (d: '01'; r: 1),                                   // 1
    (d: '81808000'; r: 1),                             // 1 with leading zeroes
    (d: '81808080808080808000'; r: 1),                 // 1 with max leading zeroes
    (d: 'e58e26'; r: 624485),                          // 624485
    (d: 'e58ea6808000'; r: 624485),                    // 624485 with leading zeroes
    (d: 'ffffffff07'; r: $7fffffff),                   //
    (d: '8080808008'; r: $80000000),                   //
    (d: 'ffffffffffffff00'; r: 562949953421311),       // bigger than int32
    (d: 'ffffffffffffff808000'; r: 562949953421311),   // bigger than int32 with zeroes
    (d: 'ffffffffffffffff7f'; r: $7fffffffffffffff),
    (d: '80808080808080808001'; r: $8000000000000000),
    (d: 'ffffffffffffffffff01'; r: Uint64.MaxValue));
begin
  for var i := 0 to High(tests) do
  begin
    var hex := tests[i].d;
    var bytes := FromHex(hex);
    var buf := TInputBuffer.From(bytes);
    var v := buf.readUint64;
    var expected := tests[i].r;
    Check(v = expected);
    Check(buf.current = buf.begins + buf.bufferSize);
  end;
end;

procedure TestLeb128.Test_decode_s32_inv1;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$80, $80, $80, $80, $70];
  buf := TInputBuffer.From(bytes);
  buf.readInt32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_s32_inv2;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$80, $80, $80, $80, $10];
  buf := TInputBuffer.From(bytes);
  buf.readInt32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_s32_inv3;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $0f];
  buf := TInputBuffer.From(bytes);
  buf.readInt32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_s32_inv4;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $4f];
  buf := TInputBuffer.From(bytes);
  buf.readInt32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u32_inv1;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$e5, $8e, $a6];
  buf := TInputBuffer.From(bytes);
  buf.readUint32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u32_inv2;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$81, $80, $80, $80, $80, $00];
  buf := TInputBuffer.From(bytes);
  buf.readUint32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u32_inv3;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $ff, $00];
  buf := TInputBuffer.From(bytes);
  buf.readUint32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u32_inv4;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $7f];
  buf := TInputBuffer.From(bytes);
  buf.readUint32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u32_inv5;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$82, $80, $80, $80, $70];
  buf := TInputBuffer.From(bytes);
  buf.readUint32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u32_inv6;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$80, $80, $80, $80, $1f];
  buf := TInputBuffer.From(bytes);
  buf.readUint32;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_s64_inv1;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$81, $80, $80, $80, $80, $80, $80, $80, $80, $80];
  buf := TInputBuffer.From(bytes);
  buf.readInt64;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_s64_inv2;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $01];
  buf := TInputBuffer.From(bytes);
  buf.readInt64;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_s64_inv3;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $01];
  buf := TInputBuffer.From(bytes);
  buf.readInt64;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_s64_inv4;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $79];
  buf := TInputBuffer.From(bytes);
  buf.readInt64;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u64_inv1;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$e5, $8e, $a6];
  buf := TInputBuffer.From(bytes);
  buf.readUint64;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u64_inv2;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$81, $80, $80, $80, $80, $80, $80, $80, $80, $80];
  buf := TInputBuffer.From(bytes);
  buf.readUint64;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u64_inv3;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $81, $00];
  buf := TInputBuffer.From(bytes);
  buf.readUint64;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u64_inv4;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $7f];
  buf := TInputBuffer.From(bytes);
  buf.readUint64;
  StopExpectingException();
end;

procedure TestLeb128.Test_decode_u64_inv5;
var
  bytes: TBytes;
  buf: TInputBuffer;
begin
  StartExpectingException(EWasmError);
  bytes := [$ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $19];
  buf := TInputBuffer.From(bytes);
  buf.readUint64;
  StopExpectingException();
end;

{$EndRegion}

initialization
  RegisterTest(TestLeb128.Suite);
end.
