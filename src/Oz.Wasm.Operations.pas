(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Operations;

interface

{$IF Defined(ASSEMBLER)}
  {$DEFINE X86ASM}
{$ELSE}
  {$DEFINE PUREPASCAL}
{$ENDIF}

uses
  System.SysUtils, System.Math;

{$Region 'Operations'}

// Bitwise rotate left
function rotl(lhs, rhs: Uint32): Uint32; inline;
// Bitwise rotate right
function rotr(lhs, rhs: Uint32): Uint32; inline;
// Count leading zeros
function clz32(value: Uint32): Uint32;
function clz64(value: Uint64): Uint64;
// Count trailing zeros
function ctz32(value: Uint32): Uint32;
function ctz64(value: Uint64): Uint64;
// The population count of a specific value is the number of set bits in that value
function popcount32(value: Uint32): Uint32;
function popcount64(value: Uint64): Uint64;
// Arithmetic shift right
function Ash32(value, shift: Uint32): Int32;
function Ash64(value: Int64; shift: Uint32): Int64;

{$EndRegion}

implementation

{$Region 'Operations'}

type
  U64 = record
    case Integer of
      1: (i64: Uint64);
      2: (lo, hi: Uint32);
  end;

function rotl(lhs, rhs: Uint32): Uint32;
const
  Bits = sizeof(Uint32);
begin
  var k := rhs and (Bits - 1);
  if k = 0 then exit(lhs);
  Result := (lhs shl k) or (lhs shr (Bits - k));
end;

function rotr(lhs, rhs: Uint32): Uint32;
const
  Bits = sizeof(Uint32);
begin
  var k := rhs and (Bits - 1);
  if k = 0 then exit(lhs);
  Result := (lhs shr k) or (lhs shl (Bits - k));
end;

function __builtin_clz(x: Uint32): Uint32;
asm
{$IF Defined(CPUX64)}
    BSR   ECX,ECX
    NEG   ECX
    ADD   ECX,31
    MOV   EAX,ECX
{$ENDIF}
{$IF Defined(CPUX86)}
    BSR   EAX,EAX
    NEG   EAX
    ADD   EAX,31
{$ENDIF}
end;

function __builtin_ctz(x: Uint32): Uint32;
asm
{$IF Defined(CPUX64)}
    BSF   ECX,ECX
    MOV   EAX,ECX
{$ENDIF}
{$IF Defined(CPUX86)}
    BSF   EAX,EAX
{$ENDIF}
end;

function __builtin_clzll(x: Uint64): Uint64;
asm
{$IF Defined(CPUX64)}
    BSR   RCX,RCX
    NEG   RCX
    ADD   RCX,63
    MOV   RAX,RCX
{$ENDIF}
{$IF Defined(CPUX86)}
    BSR   EAX,EAX
    NEG   EAX
    ADD   EAX,63
{$ENDIF}
end;

function __builtin_ctzll(x: Uint64): Uint64;
asm
{$IF Defined(CPUX64)}
  BSF     RCX,RCX
  MOV     RAX,RCX
{$ENDIF}
{$IF Defined(CPUX86)}
  BSF     EAX,EAX
{$ENDIF}
end;

function clz32(value: Uint32): Uint32;
begin
  if value = 0 then
    Result := 32
  else
    Result := __builtin_clz(value);
end;

function ctz32(value: Uint32): Uint32;
begin
  if value = 0 then
    Result := 32
  else
    Result := __builtin_ctz(value);
end;

function popcount32(value: Uint32): Uint32;
asm
  POPCNT EAX,EAX
end;

function clz64(value: Uint64): Uint64;
begin
  if value = 0 then
    Result := 64
  else if U64(value).hi <> 0 then
    Result := clz32(U64(value).hi)
  else
    Result := clz32(U64(value).lo) + 32
end;

function ctz64(value: Uint64): Uint64;
begin
  if value = 0 then
    Result := 64
  else if U64(value).lo <> 0 then
    Result := ctz32(U64(value).lo)
  else
    Result := ctz32(U64(value).hi) + 32
end;

{$IF Defined(CPUX64)}

function popcount64(value: Uint64): Uint64;
asm
  POPCNT  RCX,RCX
  MOV     RAX,RCX
end;

{$ENDIF}

{$IF Defined(CPUX86) or Defined(PUREPASCAL)}

function popcount64(value: Uint64): Uint64;
begin
  Result := popcount32(U64(value).hi) + popcount32(U64(value).lo);
end;

{$ENDIF}

{$IF Defined(CPUX86)}

function Ash32(value, shift: Uint32): Int32;
asm
    MOV   EAX,value
    MOV   ECX,shift
    SAR   EAX,CL
    MOV   Result,EAX
end;

// target (EDX:EAX) count (ECX)
function Ash64(value: Int64; shift: Uint32): Int64;
asm
    MOV   ECX,shift
    MOV   EAX,[EBP+$08]
    MOV   EDX,[EBP+$0c]
    AND   CL,$3F
    CMP   CL,32
    JL    @ash64@below32
    MOV   EAX,EDX
    CDQ
    SAR   EAX,CL
    JMP   @ash64@ret
@ash64@below32:
    SHRD  EAX,EDX,CL
    SAR   EDX,CL
@ash64@ret:
    MOV   [EBP-$10],EAX
    MOV   [EBP-$0c],EDX
end;

{$ENDIF}

{$IF Defined(CPUX64)}

function Ash32(value, shift: Uint32): Int32;
asm
    MOV   EAX,value
    MOV   ECX,shift
    AND   CL,$3F
    SAR   EAX,CL
    MOV   Result,EAX
end;

function Ash64(value: Int64; shift: Uint32): Int64;
asm
    MOV   RAX,value
    MOV   ECX,shift
    SAR   RAX,CL
    MOV   Result,RAX
end;

{$ENDIF}

{$IF Defined(PUREPASCAL)}

function Ash32(value, shift: Uint32): Int32;
begin
  result := (value and Int32.MaxValue) shr shift;
  Dec(result, (value and (not Int32.MaxValue)) shr shift);
end;

function Ash64(value: Int64; shift: Uint32): Int64;
begin
  result := (value and Int64.MaxValue) shr shift -
            (value and (not Int64.MaxValue)) shr shift;
end;

{$ENDIF}

{$EndRegion}

end.

