(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Instruction;

interface

uses
  Oz.Wasm.Value;

{$T+}
{$SCOPEDENUMS ON}

type

  // control Instructions
  TInstruction = (
    unreachable = $00,         // 'unreachable'
    nop = $01,                 // 'nop'
    block = $02,               // 'block'
    loop = $03,                // 'loop'
    if_ = $04,                 // 'if'
    else_ = $05,               // 'else'
    res06 = $06, res07 = $07, res08 = $08, res09 = $09, res0a = $0a,
    end_ = $0B,                // 'end'
    br = $0C,                  // 'br'
    br_if = $0D,               // 'br_if'
    br_table = $0E,            // 'br_table'
    return_ = $0F,             // 'return'
    call = $10,                // 'call'
    call_indirect = $11,       // 'call_indirect'
    res13 = $13, res14 = $14, res15 = $15, res16 = $16, res17 = $17, res18 = $18,

    // parametric Instructions
    drop = $1A,                // 'drop'
    select = $1B,              // 'select'
    res1D = $1D, res1E = $1E, res1F = $1F,

    // variable instructions
    get_local = $20,           // 'local.get'
    set_local = $21,           // 'local.set'
    tee_local = $22,           // 'local.tee'
    get_global = $23,          // 'global.get'
    set_global = $24,          // 'global.set'
    table_get = $25,           // 'table.get;
    table_set = $26,           // 'table.set'
    res27 = $27,

    // memory instructions
    i32_load = $28,            // 'i32.load'
    i64_load = $29,            // 'i64.load'
    f32_load = $2A,            // 'f32.load'
    f64_load = $2B,            // 'f64.load'
    i32_load8_s = $2C,         // 'i32.load8_s'
    i32_load8_u = $2D,         // 'i32.load8_u'
    i32_load16_s = $2E,        // 'i32.load16_s'
    i32_load16_u = $2F,        // 'i32.load16_u'
    i64_load8_s = $30,         // 'i64.load8_s'
    i64_load8_u = $31,         // 'i64.load8_u'
    i64_load16_s = $32,        // 'i64.load16_s'
    i64_load16_u = $33,        // 'i64.load16_u'
    i64_load32_s = $34,        // 'i64.load32_s'
    i64_load32_u = $35,        // 'i64.load32_u'
    i32_store = $36,           // 'i32.store'
    i64_store = $37,           // 'i64.store'
    f32_store = $38,           // 'f32.store'
    f64_store = $39,           // 'f64.store'
    i32_store8 = $3A,          // 'i32.store8'
    i32_store16 = $3B,         // 'i32.store16'
    i64_store8 = $3C,          // 'i64.store8'
    i64_store16 = $3D,         // 'i64.store16'
    i64_store32 = $3E,         // 'i64.store32'
    current_memory = $3F,      // 'memory.size'
    grow_memory = $40,         // 'memory.grow'

    // numeric instructions
    i32_const = $41,           // 'i32.const'
    i64_const = $42,           // 'i64.const'
    f32_const = $43,           // 'f32.const'
    f64_const = $44,           // 'f64.const'
    i32_eqz = $45,             // 'i32.eqz'
    i32_eq = $46,              // 'i32.eq'
    i32_ne = $47,              // 'i32.ne'
    i32_lts = $48,             // 'i32.lt_s'
    i32_ltu = $49,             // 'i32.lt_u'
    i32_gts = $4A,             // 'i32.gt_s'
    i32_gtu = $4B,             // 'i32.le_s'
    i32_leu = $4D,             // 'i32.le_u'
    i32_ges = $4E,             // 'i32.ge_s'
    i32_geu = $4F,             // 'i32.ge_u'
    i64_eqz = $50,             // 'i64.eqz'
    i64_eq = $51,              // 'i64.eq'
    i64_ne = $52,              // 'i64.ne'
    i64_lts = $53,             // 'i64.lt_s'
    i64_ltu = $54,             // 'i64.lt_u'
    i64_gts = $55,             // 'i64.gt_s'
    i64_gtu = $56,             // 'i64.gt_u'
    i64_les = $57,             // 'i64.le_s'
    i64_leu = $58,             // 'i64.le_u'
    i64_ges = $59,             // 'i64.ge_s'
    i64_geu = $5A,             // 'i64.ge_u'
    f32_eq = $5B,              // 'f32.eq'
    f32_ne = $5C,              // 'f32.ne'
    f32_lt = $5D,              // 'f32.lt'
    f32_gt = $5E,              // 'f32.gt'
    f32_le = $5F,              // 'f32.le'
    f32_ge = $60,              // 'f32.ge'
    f64_eq = $61,              // 'f64.eq'
    f64_ne = $62,              // 'f64.ne'
    f64_lt = $63,              // 'f64.lt'
    f64_gt = $64,              // 'f64.gt'
    f64_le = $65,              // 'f64.le'
    f64_ge = $66,              // 'f64.ge'
    i32_clz = $67,             // 'i32.clz'
    i32_ctz = $68,             // 'i32.ctz'
    i32_popcnt = $69,          // 'i32.popcnt'
    i32_add = $6A,             // 'i32.add'
    i32_sub = $6B,             // 'i32.sub'
    i32_mul = $6C,             // 'i32.mul'
    i32_divs = $6D,            // 'i32.div_s'
    i32_divu = $6E,            // 'i32.div_u'
    i32_rems = $6F,            // 'i32.rem_s'
    i32_remu = $70,            // 'i32.rem_u'
    i32_and = $71,             // 'i32.and'
    i32_or = $72,              // 'i32.or'
    i32_xor = $73,             // 'i32.xor'
    i32_shl = $74,             // 'i32.shl'
    i32_shrs = $75,            // 'i32.shr_s'
    i32_shru = $76,            // 'i32.shr_u'
    i32_rotl = $77,            // 'i32.rotl'
    i32_rotr = $78,            // 'i32.rotr'
    i64_clz = $79,             // 'i64.clz'
    i64_ctz = $7A,             // 'i64.ctz'
    i64_popcnt = $7B,          // 'i64.popcnt'
    i64_add = $7C,             // 'i64.add'
    i64_sub = $7D,             // 'i64.sub'
    i64_mul = $7E,             // 'i64.mul'
    i64_divs = $7F,            // 'i64.div_s'
    i64_divu = $80,            // 'i64.div_u'
    i64_rems = $81,            // 'i64.rem_s'
    i64_remu = $82,            // 'i64.rem_u'
    i64_and = $83,             // 'i64.and'
    i64_or = $84,              // 'i64.or'
    i64_xor = $85,             // 'i64.xor'
    i64_shl = $86,             // 'i64.shl'
    i64_shrs = $87,            // 'i64.shr_s'
    i64_shru = $88,            // 'i64.shr_u'
    i64_rotl = $89,            // 'i64.rotl'
    i64_rotr = $8A,            // 'i64.rotr'
    f32_abs = $8B,             // 'f32.abs'
    f32_neg = $8C,             // 'f32.neg'
    f32_ceil = $8D,            // 'f32.ceil'
    f32_floor = $8E,           // 'f32.floor'
    f32_trunc = $8F,           // 'f32.trunc'
    f32_nearest = $90,         // 'f32.nearest'
    f32_sqrt = $91,            // 'f32.sqrt'
    f32_add = $92,             // 'f32.add'
    f32_sub = $93,             // 'f32.sub'
    f32_mul = $94,             // 'f32.mul'
    f32_div = $95,             // 'f32.div'
    f32_min = $96,             // 'f32.min'
    f32_max = $97,             // 'f32.max'
    f32_copysign = $98,        // 'f32.copysign'
    f64_abs = $99,             // 'f64.abs'
    f64_neg = $9A,             // 'f64.neg'
    f64_ceil = $9B,            // 'f64.ceil'
    f64_floor = $9C,           // 'f64.floor'
    f64_trunc = $9D,           // 'f64.trunc'
    f64_nearest = $9E,         // 'f64.nearest'
    f64_sqrt = $9F,            // 'f64.sqrt'
    f64_add = $A0,             // 'f64.add'
    f64_sub = $A1,             // 'f64.sub'
    f64_mul = $A2,             // 'f64.mul'
    f64_div = $A3,             // 'f64.div'
    f64_min = $A4,             // 'f64.min'
    f64_max = $A5,             // 'f64.max'
    f64_copysign = $A6,        // 'f64.copysign'
    i32_wrap_i64 = $A7,        // 'i32.wrap_i64'
    i32_trunc_sf32 = $A8,      // 'i32.trunc_f32_s'
    i32_trunc_uf32 = $A9,      // 'i32.trunc_f32_u'
    i32_trunc_sf64 = $AA,      // 'i32.trunc_f64_s'
    i32_trunc_uf64 = $AB,      // 'i32.trunc_f64_u'
    i64_extend_si32 = $AC,     // 'i64.extend_i32_s'
    i64_extend_ui32 = $AD,     // 'i64.extend_i32_u'
    i64_trunc_sf32 = $AE,      // 'i64.trunc_f32_s'
    i64_trunc_uf32 = $AF,      // 'i64.trunc_f32_u'
    i64_trunc_sf64 = $B0,      // 'i64.trunc_f64_s'
    i64_trunc_uf64 = $B1,      // 'i64.trunc_f64_u'
    f32_convert_si32 = $B2,    // 'f32.convert_i32_s'
    f32_convert_ui32 = $B3,    // 'f32.convert_i32_u'
    f32_convert_si64 = $B4,    // 'f32.convert_i64_s'
    f32_convert_ui64 = $B5,    // 'f32.convert_i64_u'
    f32_demote_f64 = $B6,      // 'f32.demote_f64'
    f64_convert_si32 = $B7,    // 'f64.convert_i32_s'
    f64_convert_ui32 = $B8,    // 'f64.convert_i32_u'
    f64_convert_si64 = $B9,    // 'f64.convert_i64_s'
    f64_convert_ui64 = $BA,    // 'f64.convert_i64_u'
    f64_promote_f32 = $BB,     // 'f64.promote_f32'
    i32_reinterpret_f32 = $BC, // 'i32.reinterpret_f32'
    i64_reinterpret_f64 = $BD, // 'i64.reinterpret_f64'
    f32_reinterpret_i32 = $BE, // 'f32.reinterpret_i32'
    f64_reinterpret_i64 = $BF, // 'f64.reinterpret_i64'
    i32_extend8_s = $C0,       // i32.extend8_s
    i32_extend16_s = $C1,      // i32.extend16_s
    i64_extend8_s = $C2,       // i64.extend8_s
    i64_extend16_s = $C3,      // i64.extend16_s
    i64_extend32_s = $C4);     // i64.extend32_s

  TOp = record
    code: TInstruction;
    name: string;
    function From(code: TInstruction; const name: string): TInstruction;
  end;

implementation

{ TOp }

function TOp.From(code: TInstruction; const name: string): TInstruction;
begin
  Self.code := code;
  Self.name := name;
  Result := code;
end;

end.
