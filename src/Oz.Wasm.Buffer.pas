(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Buffer;

interface

uses
  System.SysUtils, System.Math, Oz.Wasm.Operations, Oz.Wasm.Value, Oz.Wasm.Utils;

{$T+}
{$SCOPEDENUMS ON}

type

{$Region 'TInputBuffer: Input buffer'}

  PInputBuffer = ^TInputBuffer;
  TInputBuffer = record
  type
    TParseFunc<T> = function(var buf: TInputBuffer): T;
  private
    FBuf: PByte;
    FEnds: PByte;
    FCurrent: PByte;
    FOwnsData: Boolean;
    function GetSize: Integer; inline;
    function GetUnreadSize: Integer; inline;
  public
    class function From(const input: TBytesView): TInputBuffer; overload; static;
    class function From(const Buf: TBytes): TInputBuffer; overload; static;
    procedure Init(Buf: PByte; Size: Integer; OwnsData: Boolean);
    procedure Free;

    class function FromHex(const hex: AnsiString): TBytes; static;
    class function ToHex(const bytes: TBytes): AnsiString; static;

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
    // Decode signed/unsigned integer. Little Endian Base 128 code compression.
    function readLeb32s: Int32;
    function readLeb32u: Uint32;
    function readLeb64s: Int64;
    function readLeb64u: Uint64;
    // Read an Int32/Uint32/Int64/Uint64 value
    function readInt32: Int32; inline;
    function readUint32: Uint32; inline;
    function readUint64: Uint64; inline;
    function readInt64: Int64; inline;
    // Read a string value
    function readString: string;
    // Read a string value
    function readUTF8String: System.UTF8String;
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
    property ends: PByte read FEnds;
    // Buffer size
    property size: Integer read GetSize;
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

procedure TInputBuffer.Init(Buf: PByte; Size: Integer; OwnsData: Boolean);
begin
  FOwnsData := OwnsData;
  if not OwnsData then
    FBuf := Buf
  else
  begin
    // allocate a buffer and copy the data
    GetMem(FBuf, Size);
    Move(Buf^, FBuf^, Size);
  end;
  FCurrent := FBuf;
  FEnds := FBuf + Size;
end;

procedure TInputBuffer.Free;
begin
  if FOwnsData then
    FreeMem(FBuf);
  Self := Default(TInputBuffer);
end;

class function TInputBuffer.FromHex(const hex: AnsiString): TBytes;

  function GetHex(var p: PAnsiChar): Integer;
  begin
    case p^ of
      '0'..'9': Result := Ord(p^) - Ord('0');
      'a'..'f': Result := Ord(p^) - Ord('a') + 10;
      'A'..'F': Result := Ord(p^) - Ord('A') + 10;
      else raise EWasmError.Create('not a hex digit');
    end;
    Inc(p);
  end;

begin
  var n := Length(hex);
  if Odd(n) then raise EWasmError.Create('the length of the input is odd');
  n := n div 2;
  SetLength(Result, n);
  var p := PAnsiChar(hex);
  for var i := 0 to n - 1 do
    Result[i] := GetHex(p) * 16 + GetHex(p);
end;

class function TInputBuffer.ToHex(const bytes: TBytes): AnsiString;
const
  HEX: AnsiString = '0123456789abcdef';
begin
  SetLength(Result, Length(bytes) * 2);
  var j := 0;
  for var i := 0 to High(bytes) do
  begin
    var b := bytes[i];
    Result[j] := HEX[b and $F];
    Inc(j);
    Result[j] := HEX[b and $F0 shr 4];
    Inc(j);
  end;
end;

function TInputBuffer.GetSize: Integer;
begin
  Result := FEnds - FBuf;
end;

function TInputBuffer.GetUnreadSize: Integer;
begin
  Result := FEnds - FCurrent;
end;

procedure TInputBuffer.checkUnread(size: Integer);
begin
  if UnreadSize < size then
    raise EWasmError.Create(EWasmError.EofEncounterd);
end;

function TInputBuffer.Eof: Boolean;
begin
  Result := FCurrent >= FEnds;
end;

function TInputBuffer.readByte: Byte;
begin
  if FCurrent >= FEnds then
    raise EWasmError.Create(EWasmError.EofEncounterd);
  Result := ShortInt(FCurrent^);
  Inc(FCurrent);
end;

function TInputBuffer.readBytes: TBytes;
var
  size: Int32;
begin
  size := readLeb32u;
  if size < 0 then
    raise EWasmError.Create(EWasmError.InvalidSize)
  else if size = 0 then
    exit(nil);
  if FCurrent >= FEnds then
    raise EWasmError.Create(EWasmError.EofEncounterd);
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

function TInputBuffer.readLeb32s: Int32;
var
  shift: Integer;
  b, expected: Byte;
  r: Uint32;
begin
  shift := 0;
  r := 0;
  while shift < 32 do
  begin
    b := readByte;
    r := r or (Uint32(b and $7f) shl shift);
    if b and $80 = 0 then
    begin
      if shift + 7 < 32 then
      begin
        if b and $40 <> 0 then
          // sign extend
          r := r or (UInt32.MaxValue shl (shift + 7));
      end
      else
      begin
        expected := Ash32(r, shift);
        if expected and $7F <> b then
          raise EWasmError.Create(EWasmError.MalformedVarint);
      end;
      exit(r);
    end;
    Inc(shift, 7);
  end;
  raise EWasmError.Create(EWasmError.TooManyBytes);
end;

function TInputBuffer.readLeb32u: Uint32;
var
  shift: Integer;
  r: Uint32;
  b: Byte;
begin
  r := 0;
  shift := 0;
  while shift < 32 do
  begin
    b := readByte;
    r := r or (Uint32(b and $7F) shl shift);
    if b and $80 = 0 then
    begin
      if r shr shift <> b then
        raise EWasmError.Create(EWasmError.MalformedVarint);
      exit(r);
    end;
    Inc(shift, 7);
  end;
  raise EWasmError.Create(EWasmError.TooManyBytes);
end;

function TInputBuffer.readLeb64s: Int64;
var
  shift: Integer;
  b, expected: Byte;
  r: Uint64;
begin
  shift := 0;
  r := 0;
  while shift < 64 do
  begin
    b := readByte;
    r := r or (Uint64(b and $7f) shl shift);
    if b and $80 = 0 then
    begin
      if shift + 7 < 64 then
      begin
        if b and $40 <> 0 then
          // sign extend
          r := r or (UInt64.MaxValue shl (shift + 7));
      end
      else
      begin
        expected := Ash64(r, shift);
        if expected and $7F <> b then
          raise EWasmError.Create(EWasmError.MalformedVarint);
      end;
      exit(r);
    end;
    Inc(shift, 7);
  end;
  raise EWasmError.Create(EWasmError.TooManyBytes);
end;

function TInputBuffer.readLeb64u: Uint64;
var
  shift: Integer;
  r: Uint64;
  b: Byte;
begin
  r := 0;
  shift := 0;
  while shift < 64 do
  begin
    b := readByte;
    r := r or (Uint64(b and $7F) shl shift);
    if b and $80 = 0 then
    begin
      if r shr shift <> b then
        raise EWasmError.Create(EWasmError.MalformedVarint);
      exit(r);
    end;
    Inc(shift, 7);
  end;
  raise EWasmError.Create(EWasmError.TooManyBytes);
end;

function TInputBuffer.readInt32: Int32;
begin
  Result := readLeb32s;
end;

function TInputBuffer.readUint32: Uint32;
begin
  Result := readLeb32u;
end;

function TInputBuffer.readInt64: Int64;
begin
  Result := readLeb64s;
end;

function TInputBuffer.readUint64: Uint64;
begin
  Result := readLeb64u;
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
  else if unreadSize >= Integer(bytes.size) then
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

