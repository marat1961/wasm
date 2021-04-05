(* Oz.Wasm
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Utils;

interface

uses
  Oz.Wasm.Value;

type

{$Region 'TStack<T>'}

  TStack<T> = record
  strict private
    FItems: TArray<T>;
    function GetItem(Index: Integer): T; inline;
    function GetCount: Integer; inline;
  public
    procedure Push(Item: T);
    procedure Emplace(const Args: TArray<T>);
    function Pop: T;
    function Top: T;
    function Empty: Boolean;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: T read GetItem;
  end;

{$EndRegion}

{$Region 'TOperandStack: '}

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
    constructor From(size: Cardinal);
  end;

{$EndRegion}

implementation

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

function TStack<T>.GetCount: Integer;
begin
  Result := Length(FItems);
end;

{$EndRegion}

{$Region 'TOperandStack<T>'}

constructor TOperandStack.From(size: Cardinal);
begin
end;

{$EndRegion}

end.

