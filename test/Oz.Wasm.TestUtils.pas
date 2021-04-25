(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.TestUtils;

interface

uses
  System.SysUtils, System.Math, TestFramework, DUnitX.TestFramework,
  Oz.Wasm.Utils, Oz.Wasm.Value;

{$Region 'TestStack'}

type
  TestStack = class(TTestCase)
  published
    procedure Test_push_pop;
    procedure Test_emplace;
    procedure Test_shrink;
    procedure Test_struct_item;
  end;

  TStackItem = record
    a, b, c: char;
    constructor From(a, b, c: char);
  end;

{$EndRegion}

{$Region 'TestOperandStack'}

type
  TestOperandStack = class(TTestCase)
  published
    procedure Test_construct;
    procedure Test_top;
    procedure Test_small;
    procedure Test_small_with_locals;
    procedure Test_large;
    procedure Test_large_with_locals;
    procedure Test_rbegin_rend;
    procedure Test_rbegin_rend_locals;
    procedure Test_hidden_stack_item;
  end;

{$EndRegion}

implementation

{$Region 'TStackItem'}

constructor TStackItem.From(a, b, c: char);
begin
  Self.a := a;
  Self.b := b;
  Self.c := c;
end;

{$EndRegion}

{$Region 'TestStack'}

procedure TestStack.Test_push_pop;
var
  stack: TStack<char>;
begin
  Check(stack.size = 0);
  CheckTrue(stack.empty);

  stack.push('a');
  stack.push('b');
  stack.push('c');

  CheckFalse(stack.empty);
  Check(stack.size = 3);

  Check(stack.pop = 'c');
  Check(stack.pop = 'b');
  Check(stack.pop = 'a');

  Check(stack.size = 0);
  CheckTrue(stack.empty);
end;

procedure TestStack.Test_emplace;
var
  stack: TStack<char>;
begin
  Check(stack.size = 0);
  CheckTrue(stack.empty);

  stack.emplace('a');
  stack.emplace('b');
  stack.emplace('c');

  CheckFalse(stack.empty);
  Check(stack.size = 3);

  Check(stack.pop = 'c');
  Check(stack.pop = 'b');
  Check(stack.pop = 'a');

  Check(stack.size = 0);
  CheckTrue(stack.empty);
end;

procedure TestStack.Test_shrink;
var
  stack: TStack<char>;
begin
  stack.push('a');
  stack.push('b');
  stack.push('c');
  stack.push('d');
  Check(stack.top^ = 'd');
  Check(stack.size = 4);

  stack.shrink(4);
  Check(stack.top^ = 'd');
  Check(stack.size = 4);

  stack.shrink(2);
  Check(stack.top^ = 'b');
  Check(stack.size = 2);

  stack.shrink(0);
  CheckTrue(stack.empty);
  Check(stack.size = 0);
end;

procedure TestStack.Test_struct_item;
var
  stack: TStack<TStackItem>;
  item: TStackItem;
begin
  item := TStackItem.From('a', 'b', 'c');
  stack.emplace(item);
  item := TStackItem.From('d', 'e', 'f');
  stack.emplace(item);
  item := TStackItem.From('g', 'h', 'i');
  stack.emplace(item);

  Check(stack.size = 3);

  Check(stack.top.a = 'g');
  Check(stack.top.b = 'h');
  Check(stack.top.c = 'i');
  Check(stack[1].a = 'd');
  Check(stack[1].b = 'e');
  Check(stack[1].c = 'f');
  item := stack[2]^;
  Check(stack[2].a = 'a');
  Check(stack[2].b = 'b');
  Check(stack[2].c = 'c');

  Check(stack.pop.a = 'g');

  Check(stack.top.a = 'd');
  Check(stack.top.b = 'e');
  Check(stack.top.c = 'f');
  Check(stack[1].a = 'a');
  Check(stack[1].b = 'b');
  Check(stack[1].c = 'c');
end;

{$EndRegion}

{$Region 'TestOperandStack'}

procedure TestOperandStack.Test_construct;
var
  stack: TOperandStack;
begin
  stack := TOperandStack.From(nil, 0, 0, 0);
  Check(stack.size = 0);
end;

procedure TestOperandStack.Test_top;
var
  stack: TOperandStack;
begin
  stack := TOperandStack.From(nil, 0, 0, 1);
  Check(stack.size = 0);

  stack.push(1);
  Check(stack.size = 1);
  Check(stack.top.i32 = 1);
  Check(stack[0].i32 = 1);

  stack.top.i32 := 101;
  Check(stack.size = 1);
  Check(stack.top.i32 =  101);
  Check(stack[0].i32 = 101);

  stack.drop(0);
  Check(stack.size =  1);
  Check(stack.top.i32 = 101);
  Check(stack[0].i32 = 101);

  stack.drop(1);
  Check(stack.size = 0);

  stack.push(2);
  Check(stack.size = 1);
  Check(stack.top.i32 = 2);
  Check(stack[0].i32 = 2);
end;

procedure TestOperandStack.Test_small;
var
  stack: TOperandStack;
begin
  stack := TOperandStack.From(nil, 0, 0, 3);
  Check(Abs(Pbyte(@stack) - Pbyte(stack.rbegin)) < 100, 'not allocated on the system stack');

  Check(stack.size = 0);

  stack.push(1);
  stack.push(2);
  stack.push(3);
  Check(stack.size = 3);
  Check(stack.top.i32 = 3);
  Check(stack[0].i32 = 3);
  Check(stack[1].i32 = 2);
  Check(stack[2].i32 = 1);

  stack[0].i32 := 13;
  stack[1].i32 := 12;
  stack[2].i32 := 11;
  Check(stack.size = 3);
  Check(stack.top.i32 = 13);
  Check(stack[0].i32 = 13);
  Check(stack[1].i32 = 12);
  Check(stack[2].i32 = 11);

  Check(stack.pop.i32 = 13);
  Check(stack.size = 2);
  Check(stack.top.i32 = 12);
end;

procedure TestOperandStack.Test_small_with_locals;
var
  stack: TOperandStack;
  args: TArray<TValue>;
begin
  args := [TValue.From($a1), TValue.From($a2)];
  stack := TOperandStack.From(@args[0], Length(args), 3, 1);
  Check(Abs(Pbyte(@stack) - Pbyte(stack.rbegin)) < 100, 'not allocated on the system stack');

  Check(stack.size = 0);

  stack.push($ff);
  Check(stack.size = 1);
  Check(stack.top.i32 = $ff);
  Check(stack[0].i32 = $ff);

  Check(stack.local(0).i32 = $a1);
  Check(stack.local(1).i32 = $a2);
  Check(stack.local(2).i32 = 0);
  Check(stack.local(3).i32 = 0);
  Check(stack.local(4).i32 = 0);

  stack.local(0).i32 := $c0;
  stack.local(1).i32 := $c1;
  stack.local(2).i32 := $c2;
  stack.local(3).i32 := $c3;
  stack.local(4).i32 := $c4;

  Check(stack.local(0).i32 = $c0);
  Check(stack.local(1).i32 = $c1);
  Check(stack.local(2).i32 = $c2);
  Check(stack.local(3).i32 = $c3);
  Check(stack.local(4).i32 = $c4);

  Check(stack.pop.i32 = $ff);
  Check(stack.size = 0);
  Check(stack.local(0).i32 = $c0);
  Check(stack.local(1).i32 = $c1);
  Check(stack.local(2).i32 = $c2);
  Check(stack.local(3).i32 = $c3);
  Check(stack.local(4).i32 = $c4);
end;

procedure TestOperandStack.Test_large;
var
  stack: TOperandStack;
  i: Uint32;
begin
  var maxHeight := 33;
  stack := TOperandStack.From(nil, 0, 0, maxHeight);
  Check(Abs(Pbyte(@stack) - Pbyte(stack.rbegin)) > 100, 'not allocated on the heap"');
  Check(stack.size = 0);

  for i := 0 to maxHeight - 1 do
    stack.push(i);

  Check(stack.size = maxHeight);
  var expected := maxHeight - 1;
  while expected >= 0 do
  begin
    Check(stack.pop.i32 = expected);
    Dec(expected);
  end;
  Check(stack.size = 0);
end;

procedure TestOperandStack.Test_large_with_locals;
var
  stack: TOperandStack;
  args: TArray<TValue>;
  i: Uint32;
begin
  args := [TValue.From($a1), TValue.From($a2)];

  var maxHeight := 33;
  var numLocals := 5;
  var numArgs := Length(args);
  stack := TOperandStack.From(@args[0], numArgs, numLocals, maxHeight);
  Check(Abs(Pbyte(@stack) - Pbyte(stack.rbegin)) > 100, 'not allocated on the heap');

  for i := 0 to maxHeight - 1 do
    stack.push(i);

  Check(stack.size = maxHeight);
  for i := 0 to maxHeight - 1 do
    Check(stack[i].i32 = maxHeight - i - 1);

  Check(stack.local(0).i32 = $a1);
  Check(stack.local(1).i32 = $a2);

  for i := numArgs to numArgs + numLocals - 1 do
    Check(stack.local(i).i32 = 0);

  for i := 0 to numArgs + numLocals - 1 do
    stack.local(i)^ := TValue.From(i);
  for i := 0 to numArgs + numLocals - 1 do
    Check(stack.local(i).i32 = i);

  var expected := maxHeight - 1;
  while expected >= 0 do
  begin
    Check(stack.pop.i32 = expected);
    Dec(expected);
  end;
  Check(stack.size = 0);

  for i := 0 to numArgs + numLocals - 1 do
    Check(stack.local(i).i32 = i);
end;

procedure TestOperandStack.Test_rbegin_rend;
var
  stack: TOperandStack;
begin
  stack := TOperandStack.From(nil, 0, 0, 3);
  Check(stack.rbegin = stack.rend);

  stack.push(1);
  stack.push(2);
  stack.push(3);
  Check(PByte(stack.rbegin) < PByte(stack.rend));
  Check(stack.rbegin.i32 = 1);
  Check(PValue(PByte(stack.rend) - sizeof(TValue)).i32 = 3);
end;

procedure TestOperandStack.Test_rbegin_rend_locals;
var
  stack: TOperandStack;
  args: TArray<TValue>;
begin
  args := [TValue.From($a1)];

  stack := TOperandStack.From(@args[0], Length(args), 4, 2);
  Check(stack.rbegin = stack.rend);

  stack.push(1);
  Check(PByte(stack.rbegin) < PByte(stack.rend));
  Check(PByte(stack.rend) - PByte(stack.rbegin) = sizeof(TValue));
  Check(stack.rbegin.i32 = 1);
  Check(PValue(PByte(stack.rend) - sizeof(TValue)).i32 = 1);

  stack.push(2);
  Check(PByte(stack.rbegin) < PByte(stack.rend));
  Check(PByte(stack.rend) - PByte(stack.rbegin) = 2 * sizeof(TValue));
  Check(stack.rbegin.i32 = 1);
  Check(PValue(PByte(stack.rbegin) + sizeof(TValue)).i32 = 2);
  Check(PValue(PByte(stack.rend) - 1 * sizeof(TValue)).i32 = 2 );
  Check(PValue(PByte(stack.rend) - 2 * sizeof(TValue)).i32 = 1);
end;

procedure TestOperandStack.Test_hidden_stack_item;
var
  stack: TOperandStack;
begin
  var maxHeight := 33;
  stack := TOperandStack.From(nil, 0, 0, maxHeight);
  Check(Abs(Pbyte(@stack) - Pbyte(stack.rbegin)) > 100, 'not allocated on the heap');
  Check(stack.size = 0);
  Check(stack.rbegin = stack.rend);

  // Even when stack is empty, there exists a single hidden item slot.
  stack.rbegin.i64 := 1;
  Check(stack.rbegin.i64 = 1);
  Check(stack.rend.i64 = 1);
end;

{$EndRegion}

initialization
  RegisterTest(TestStack.Suite);
  RegisterTest(TestOperandStack.Suite);
end.
