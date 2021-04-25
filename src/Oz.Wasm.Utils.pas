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
    class function CopyN<T>(First: Pointer; Count: Uint32; var R): Pointer; static;
    // Copies all elements in the range, defined by [First, Last)
    // starting from First to Last - 1 to another range beginning at DestFirst.
    class function Copy<T>(const First, Last; var DestFirst): PByte; static;
    // Assigns the given value to the first count elements
    // in the range beginning at first if count > 0.
    class procedure FillN<T>(First: Pointer; Count: Uint32; const Value: T); static;
  end;

{$EndRegion}

{$Region 'TOptional<T>: optional value'}

  TOptional<T> = record
  var
    value: T;
    hasValue: Boolean;
  public
    constructor From(value: T);
    procedure Reset;
    function Equals(const other: TOptional<T>): Boolean;
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
    FSize: Uint32;
    function GetItem(Index: Integer): T; inline;
  public
    constructor From(start: PItem; size: Uint32);
    function Empty: Boolean;
    property Size: Uint32 read FSize;
    property Items[Index: Integer]: T read GetItem;
  end;

{$EndRegion}

{$Region 'TBytesView'}

  // The bytes view describes an object that can refer to a constant contiguous
  // sequence of bytes with the first element of the sequence at position zero.
  TBytesView = record
  private
    FBytes: PByte;
    FSize: Uint32;
    function GetByte(index: Uint32): Byte; inline;
  public
    class function From(bytes: PByte; size: Uint32): TBytesView; static;
    property size: Uint32 read FSize;
    property data: PByte read FBytes;
    property bytes[index: Uint32]: Byte read GetByte; default;
  end;

{$EndRegion}

{$Region 'TStack<T>'}

  TStack<T> = record
  type
    Pt = ^T;
  strict private
    FItems: TArray<T>;
    function GetItem(Index: Integer): Pt; inline;
    function GetSize: Uint32; inline;
  public
    procedure Push(Item: T);
    procedure Emplace(const Value: T); overload;
    procedure Emplace(const Args: TArray<T>); overload;
    function Pop: T;
    function Top: Pt;
    function Empty: Boolean;
    procedure Shrink(newSize: Uint32);
    property Size: Uint32 read GetSize;
    property Items[Index: Integer]: Pt read GetItem; default;
  end;

{$EndRegion}

{$Region 'TOperandStack'}

  POperandStack = ^TOperandStack;
  TOperandStack = record
  const
    SmallStorageSize = 128 div sizeof(TValue);
  private
    FTop: PValue;
    FLocals: PValue;
    FBottom: PValue;
    FSmallStorage: array [0 .. SmallStorageSize] of TValue;
    FLargeStorage: TArray<TValue>;
    function GetItem(Index: Integer): PValue;
  public
    constructor From(const args: PValue; numArgs, numLocalVariables, maxStackHeight: Uint32);
    // The current number of items on the stack (aka stack height).
    function Size: Uint32;
    // Pushes an item on the stack.
    // The stack max height limit is not checked.
    procedure Push(Item: TValue); overload;
    procedure Push(value: Uint64); overload;
    procedure Push(value: Uint32); overload;
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
    procedure Drop(num: Uint32);
    // Returns the reference to the stack item on given position from the stack top.
    // Requires index < Size.
    property Items[Index: Integer]: PValue read GetItem; default;
  end;

{$EndRegion}

implementation

{$Region 'TStd'}

class function TStd.CopyN<T>(First: Pointer; Count: Uint32; var R): Pointer;
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
  Result := dest;
end;

class function TStd.Copy<T>(const First, Last; var DestFirst): PByte;
var
  size: NativeInt;
begin
  size := PByte(@Last) - PByte(@First) - sizeof(T);
  System.Move(First, DestFirst, size);
  Result := PByte(@DestFirst) + size;
end;

class procedure TStd.FillN<T>(First: Pointer; Count: Uint32; const Value: T);
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

{$Region 'TOptional<T>'}

constructor TOptional<T>.From(value: T);
begin
  Self.value := value;
  hasValue := True;
end;

procedure TOptional<T>.Reset;
begin
  Self := Default(TOptional<T>);
end;

function TOptional<T>.Equals(const other: TOptional<T>): Boolean;
begin
  Result := hasValue = other.hasValue;
  if Result then
    Result := Self.Equals(other);
end;

{$EndRegion}

{$Region 'TSpan<T>'}

constructor TSpan<T>.From(start: PItem; size: Uint32);
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

{$Region 'TBytesView'}

class function TBytesView.From(bytes: PByte; size: Uint32): TBytesView;
begin
  Result.FBytes := bytes;
  Result.FSize := size;
end;

function TBytesView.GetByte(index: Uint32): Byte;
begin
  Result := PByte(FBytes + index)^;
end;

{$EndRegion}

{$Region 'TStack<T>'}

procedure TStack<T>.Push(Item: T);
begin
  FItems := FItems + [Item];
end;

procedure TStack<T>.Emplace(const Value: T);
begin
  FItems := FItems + [Value];
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

function TStack<T>.Top: Pt;
begin
  Result := @FItems[High(FItems)];
end;

function TStack<T>.Empty: Boolean;
begin
  Result := FItems = nil;
end;

function TStack<T>.GetItem(Index: Integer): Pt;
begin
  Result := @FItems[Integer(Size) - Index - 1];
end;

function TStack<T>.GetSize: Uint32;
begin
  Result := Uint32(Length(FItems));
end;

procedure TStack<T>.Shrink(newSize: Uint32);
begin
  Assert(newSize <= Size);
  SetLength(FItems, newSize);
end;

{$EndRegion}

{$Region 'TOperandStack<T>'}

constructor TOperandStack.From(const args: PValue;
  numArgs, numLocalVariables, maxStackHeight: Uint32);
begin
  var numLocals := numArgs + numLocalVariables;
  // To avoid potential UB when there are no locals and the stack pointer
  // is set to FBottom - 1 (i.e. before storage array),
  // we allocate one additional unused stack item.
  var numLocalsAdjusted := numLocals + Uint32(Ord(numLocals = 0)); // Bump to 1 if 0.
  var storageSizeRequired := numLocalsAdjusted + maxStackHeight;

  if storageSizeRequired <= SmallStorageSize then
    FLocals := @FSmallStorage[0]
  else
  begin
    SetLength(FLargeStorage, storageSizeRequired);
    FLocals := @FLargeStorage[0];
  end;

  FBottom := FLocals;
  Inc(FBottom, numLocalsAdjusted);
  FTop := FBottom;
  Dec(FTop);

  var localVariables := TStd.CopyN<PValue>(args, numArgs, FLocals^);
  TStd.FillN<TValue>(localVariables, numLocalVariables, TValue.From(0));
end;

function TOperandStack.Size: Uint32;
begin
  Result := (PByte(FTop) - PByte(FBottom)) div sizeof(TValue) + 1;
end;

function TOperandStack.GetItem(index: Integer): PValue;
begin
  Assert(Uint32(index) < Size);
  Result := FTop;
  Dec(Result, index);
end;

function TOperandStack.local(index: Integer): PValue;
begin
  Result := FLocals;
  Inc(Result, index);
  Assert(NativeUInt(Result) < NativeUInt(FBottom));
end;

procedure TOperandStack.Push(Item: TValue);
begin
  Inc(FTop, 1);
  FTop^ := Item;
end;

procedure TOperandStack.Push(value: Uint32);
begin
  Inc(FTop, 1);
  FTop.i32 := value;
end;

procedure TOperandStack.Push(value: Uint64);
begin
  Inc(FTop, 1);
  FTop.i64 := value;
end;

function TOperandStack.rbegin: PValue;
begin
  Result := FBottom;
end;

function TOperandStack.rend: PValue;
begin
  Result := FTop;
  Inc(Result, 1);
end;

function TOperandStack.Top: PValue;
begin
  Assert(Size <> 0);
  Result := FTop;
end;

function TOperandStack.Pop: TValue;
begin
  Assert(Size <> 0);
  Result := FTop^;
  Dec(FTop, 1);
end;

procedure TOperandStack.Drop(num: Uint32);
begin
  Assert(num <= Uint32(Size));
  Dec(FTop, num);
end;

{$EndRegion}

end.

