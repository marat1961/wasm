(* Oz.Wasm
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Utils;

interface

uses
  Oz.Wasm.Value;

type

  TStd = record
    class function CopyN<T>(First: Pointer; Count: Cardinal; var R): Pointer; static;
    class procedure FillN<T>(first: Pointer; count: Cardinal; const value: T); static;
  end;

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
  public
    constructor From(const args: PValue;
      num_args, num_local_variables, max_stack_height: Cardinal);
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

class procedure TStd.FillN<T>(first: Pointer; count: Cardinal; const value: T);
begin

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
  num_locals_adjusted := num_locals + Ord(num_locals = 0);  // Bump to 1 if 0.
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

{$EndRegion}

end.

