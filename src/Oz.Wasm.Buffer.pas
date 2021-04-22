(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Buffer;

interface

uses
  System.SysUtils, Oz.Wasm.Value, Oz.Wasm.Utils;

{$T+}
{$SCOPEDENUMS ON}

type

{$Region 'TInputBuffer: Input buffer'}

  PInputBuffer = ^TInputBuffer;
  TInputBuffer = record
  type
    TParseFunc<T> = function(const buf: TInputBuffer): T;
  private
    FBuf: PByte;
    FLast: PByte;
    FCurrent: PByte;
    FOwnsData: Boolean;
    function GetBufferSize: Integer; inline;
    function GetUnreadSize: Integer; inline;
  public
    class function From(const input: TBytesView): TInputBuffer; overload; static;
    class function From(const Buf: TBytes): TInputBuffer; overload; static;
    procedure Init(Buf: PByte; BufSize: Integer; OwnsData: Boolean);
    procedure Free;
    // No more data
    function Eof: Boolean;
    // Read one byte
    function readByte: Byte;
    // Read bytes
    function readBytes: TBytes;
    // read value
    function readValue<T>: T;
    // read array of value
    function readArray<T>(parse: TParseFunc<T>): TArray<T>;
    // Read an Uint32 value
    function readUint32: Uint32; inline;
    // Read a string value
    function readString: string;
    // Read a string value
    function readUTF8String: System.UTF8String;
    // Decode unsigned integer. Little Endian Base 128 code compression.
    function readLeb128: Uint32;
    // Returns whether bytes start at the current position with the given bytes.
    function startsWith(const bytes: TBytesView): Boolean;
    // Skip size bytes
    procedure skip(size: Integer); inline;
    // Check if the unread part of the buffer is big enough
    procedure checkUnread(size: Integer);
    // Buffer current position
    property current: PByte read FCurrent;
    // Buffer begin position
    property begins: PByte read FBuf;
    // Buffer end position
    property ends: PByte read FLast;
    // Buffer size
    property bufferSize: Integer read GetBufferSize;
    // The size of the unread part of the buffer
    property unreadSize: Integer read GetUnreadSize;
  end;

{$EndRegion}

implementation

{$Region 'TInputBuffer'}

class function TInputBuffer.From(const input: TBytesView): TInputBuffer;
begin
  Result.Init(input.data, input.size, False);
end;

class function TInputBuffer.From(const Buf: TBytes): TInputBuffer;
begin
  Result.Init(@Buf[0], Length(Buf), False);
end;

procedure TInputBuffer.Init(Buf: PByte; BufSize: Integer; OwnsData: Boolean);
begin
  FOwnsData := OwnsData;
  if not OwnsData then
    FBuf := Buf
  else
  begin
    // allocate a buffer and copy the data
    GetMem(FBuf, BufSize);
    Move(Buf^, FBuf^, BufSize);
  end;
  FCurrent := FBuf;
  FLast := FBuf + BufSize;
end;

procedure TInputBuffer.Free;
begin
  if FOwnsData then
    FreeMem(FBuf);
  Self := Default(TInputBuffer);
end;

function TInputBuffer.GetBufferSize: Integer;
begin
  Result := FLast - FBuf;
end;

function TInputBuffer.GetUnreadSize: Integer;
begin
  Result := FLast - FCurrent;
end;

procedure TInputBuffer.checkUnread(size: Integer);
begin
  if UnreadSize < size then
    EWasmError.Create(EWasmError.EofEncounterd);
end;

function TInputBuffer.Eof: Boolean;
begin
  Result := FCurrent >= FLast;
end;

function TInputBuffer.readByte: Byte;
begin
  if FCurrent > FLast then
    EWasmError.Create(EWasmError.EofEncounterd);
  Result := ShortInt(FCurrent^);
  Inc(FCurrent);
end;

function TInputBuffer.readBytes: TBytes;
var
  size: UInt32;
begin
  size := readLeb128;
  if size <= 0 then
     EWasmError.Create(EWasmError.InvalidSize);
  if FCurrent > FLast then
    EWasmError.Create(EWasmError.EofEncounterd);
  SetLength(Result, size);
  Move(FCurrent^, Pointer(Result)^, size);
  Inc(FCurrent, size);
end;

function TInputBuffer.readValue<T>: T;
begin
  Move(FCurrent^, Result, sizeof(T));
  Inc(FCurrent, sizeof(T));
end;

function TInputBuffer.readArray<T>(parse: TParseFunc<T>): TArray<T>;
var
  size: UInt32;
begin
  size := readUint32;
  // Reserve memory for vec elements if 'size' value is reasonable.
  Assert(size < 128);
  SetLength(result, size);
  for var i := 0 to size - 1 do
    Result[i] := parse(Self);
end;

function TInputBuffer.readLeb128: Uint32;
const
  size = sizeof(Uint32);
var
  shift: Integer;
  r: Uint32;
  b: Byte;
begin
  r := 0;
  shift := 0;
  while shift < size * 8 do
  begin
    b := readByte;
    r := r or Uint32((b and $7F) shl shift);
    if b and $80 = 0 then
    begin
      if b <> (r shr shift) then
        raise EWasmError.Create('invalid LEB128 encoding: unused bits set');
      exit(r);
    end;
    shift := shift + 7;
  end;
  raise EWasmError.Create('invalid LEB128 encoding: too many bytes');
end;

function TInputBuffer.readUint32: Uint32;
begin
  Result := readLeb128;
end;

function TInputBuffer.readString: string;
var
  buf, text: TBytes;
begin
  // Decode utf8 to string
  buf := readBytes;
  text := TEncoding.UTF8.Convert(TEncoding.UTF8, TEncoding.Unicode, buf);
  Result := TEncoding.Unicode.GetString(text);
end;

function TInputBuffer.readUTF8String: System.UTF8String;
var
  buf: TBytes;
begin
  buf := readBytes;
  Result := TEncoding.UTF8.GetString(buf);
end;

function TInputBuffer.startsWith(const bytes: TBytesView): Boolean;
begin
  if bytes.size = 0 then
    Result := True
  else if unreadSize >= bytes.size then
    Result := CompareMem(FCurrent, bytes.data, bytes.size)
  else
    Result := False;
end;

procedure TInputBuffer.skip(size: Integer);
begin
  Inc(FCurrent, size);
end;

{$EndRegion}

end.

