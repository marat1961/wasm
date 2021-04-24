(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.TestUtils;

interface

uses
  System.SysUtils, System.Math, TestFramework, DUnitX.TestFramework,
  Oz.Wasm.Utils;

{$Region 'TestStack'}

type
  TestStack = class(TTestCase)
  public
    procedure SetUp; override;
    procedure TearDown; override;
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

procedure TestStack.SetUp;
begin
end;

procedure TestStack.TearDown;
begin
end;

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
  Check(stack.top = 'd');
  Check(stack.size = 4);

  stack.shrink(4);
  Check(stack.top = 'd');
  Check(stack.size = 4);

  stack.shrink(2);
  Check(stack.top = 'b');
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
  item := stack[2];
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

initialization
  RegisterTest(TestStack.Suite);
end.
