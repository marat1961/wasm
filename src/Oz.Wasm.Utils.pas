(* Oz.Wasm
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Utils;

interface

uses
  Oz.Wasm.Value;

type

{$Region 'TStd'}

  TStd = record
    // Copies exactly count values from the range beginning
    // at first to the range beginning at result.
    class function CopyN<T>(First: Pointer; Count: Cardinal; var R): Pointer; static;
    // Assigns the given value to the first count elements
    // in the range beginning at first if count > 0.
    class procedure FillN<T>(First: Pointer; Count: Cardinal; const Value: T); static;
  end;

{$EndRegion}

{$Region 'TSpan: a contiguous sequence of objects'}

  // The span describes an object that can refer to a contiguous sequence
  // of objects with the first element of the sequence at position zero.
  TSpan<T> = record
  type
    PItem = ^T;
  var
    FStart: PItem;
    FSize: Cardinal;
    function GetItem(Index: Integer): T; inline;
  public
    constructor From(start: PItem; size: Cardinal);
    function Empty: Boolean;
    property Size: Cardinal read FSize;
    property Items[Index: Integer]: T read GetItem;
  end;

{$EndRegion}

{$Region 'TStack<T>'}

  TStack<T> = record
  strict private
    FItems: TArray<T>;
    function GetItem(Index: Integer): T; inline;
    function GetSize: Cardinal; inline;
  public
    procedure Push(Item: T);
    procedure Emplace(const Args: TArray<T>);
    function Pop: T;
    function Top: T;
    function Empty: Boolean;
    property Size: Cardinal read GetSize;
    property Items[Index: Integer]: T read GetItem;
  end;

{$EndRegion}

{$Region 'TOperandStack'}

  TOperandStack = record
  const
    SmallStorageSize = 128 div sizeof(TValue);
  private
    FTop: PValue;
    FLocals: PValue;
    FBottom: PValue;
    FSmallStorage: array [0..SmallStorageSize] of TValue;
    FLargeStorage: TArray<TValue>;
    function GetItem(Index: Integer): PValue;
  public
    constructor From(const args: PValue;
      num_args, num_local_variables, max_stack_height: Cardinal);
    // The current number of items on the stack (aka stack height).
    function Size: Integer;
    // Pushes an item on the stack.
    // The stack max height limit is not checked.
    procedure Push(Item: TValue);
    // Returns the reference to the top item.
    // Requires non-empty stack.
    function Top: PValue;
    // Returns an item popped from the top of the stack.
    // Requires non-empty stack.
    function Pop: TValue;
    // Returns iterator to the bottom of the stack.
    function rbegin: PValue;
    // Returns end iterator counting from the bottom of the stack.
    function rend: PValue;
    function local(index: Integer): PValue;
    // Drop num items from the top of the stack.
    procedure Drop(num: Cardinal);
    // Returns the reference to the stack item on given position from the stack top.
    // Requires index < size().
    property Items[Index: Integer]: PValue read GetItem;
  end;

{$EndRegion}

implementation

{$Region 'TStd'}

class function TStd.CopyN<T>(First: Pointer; Count: Cardinal; var R): Pointer;
type
  Pt = ^T;
var
  src, dest: Pt;
begin
  src := First;
  dest := @R;
  while Count > 0 do
  begin
    dest^ := src^;
    Inc(PByte(src), sizeof(T));
    Inc(PByte(dest), sizeof(T));
    Dec(Count);
  end;
  Result := @R;
end;

class procedure TStd.FillN<T>(First: Pointer; Count: Cardinal; const Value: T);
type
  Pt = ^T;
var
  p: Pt;
begin
  p := First;
  while Count > 0 do
  begin
    p^ := Value;
    Inc(PByte(p), sizeof(T));
    Dec(Count);
  end;
end;

{$EndRegion}

{$Region 'TSpan<T>'}

constructor TSpan<T>.From(start: PItem; size: Cardinal);
begin
  FStart := start;
  FSize := size;
end;

function TSpan<T>.Empty: Boolean;
begin
  Result := FSize = 0;
end;

function TSpan<T>.GetItem(Index: Integer): T;
begin
  Result := PItem(PByte(FStart) + sizeof(T) * Index)^;
end;

{$EndRegion}

{$Region 'TStack<T>'}

procedure TStack<T>.Push(Item: T);
begin
  FItems := FItems + [Item];
end;

procedure TStack<T>.Emplace(const Args: TArray<T>);
begin
  FItems := FItems + Args;
end;

function TStack<T>.Pop: T;
var
  Len: Integer;
begin
  Len := High(FItems);
  Result := FItems[Len];
  SetLength(FItems, Len);
end;

function TStack<T>.Top: T;
begin
  Result := FItems[High(FItems)];
end;

function TStack<T>.Empty: Boolean;
begin
  Result := FItems = nil;
end;

function TStack<T>.GetItem(Index: Integer): T;
begin
  Result := FItems[Index];
end;

function TStack<T>.GetSize: Cardinal;
begin
  Result := Cardinal(Length(FItems));
end;

{$EndRegion}

{$Region 'TOperandStack<T>'}

procedure TOperandStack.Drop(num: Cardinal);
begin
  Assert(num <= Cardinal(Size));
  Dec(FTop, num);
end;

constructor TOperandStack.From(const args: PValue;
  num_args, num_local_variables, max_stack_height: Cardinal);
var
  num_locals, num_locals_adjusted, storage_size_required: Cardinal;
  local_variables: Pointer;
begin
  num_locals := num_args + num_local_variables;
  // To avoid potential UB when there are no locals and the stack pointer
  // is set to m_bottom - 1 (i.e. before storage array),
  // we allocate one additional unused stack item.
  num_locals_adjusted := num_locals + Cardinal(Ord(num_locals = 0)); // Bump to 1 if 0.
  storage_size_required := num_locals_adjusted + max_stack_height;

  if storage_size_required <= SmallStorageSize then
    FLocals := @FSmallStorage[0]
  else
  begin
    SetLength(FLargeStorage, storage_size_required);
    FLocals := @FLargeStorage[0];
  end;

  FBottom := PValue(PByte(FLocals) + num_locals_adjusted);
  FTop := PValue(PByte(FBottom) - 1);

  local_variables := TStd.CopyN<PValue>(args, num_args, FLocals^);
  TStd.FillN<TValue>(local_variables, num_local_variables, TValue.From(0));
end;

function TOperandStack.GetItem(Index: Integer): PValue;
begin
  Assert(index < size);
  Result := PValue(PByte(FTop) - Index * sizeof(TValue));
end;

function TOperandStack.local(index: Integer): PValue;
begin
  Result := PValue(PByte(FLocals) + index);
  Assert(NativeUInt(Result) < NativeUInt(FBottom));
end;

function TOperandStack.Size: Integer;
begin
  Result := PByte(FTop) + 1 - PByte(FBottom);
end;

procedure TOperandStack.Push(Item: TValue);
begin
  Inc(FTop, sizeof(TValue));
  FTop^ := Item;
end;

function TOperandStack.rbegin: PValue;
begin
  Result := FBottom;
end;

function TOperandStack.rend: PValue;
begin
  Result := PValue(PByte(FTop) + 1);
end;

function TOperandStack.Top: PValue;
begin
  Assert(size <> 0);
  Result := FTop;
end;

function TOperandStack.Pop: TValue;
begin
  Assert(size <> 0);
  Result := FTop^;
  Dec(FTop, sizeof(TValue));
end;

{$EndRegion}

end.

