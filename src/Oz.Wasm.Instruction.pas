(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Instruction;

interface

uses
  Oz.Wasm.Value;

{$Region 'TInstruction'}

type
  TInstruction = (
    // control instructions
    unreachable = $00,         // 'unreachable'
    nop = $01,                 // 'nop'
    block = $02,               // 'block'
    loop = $03,                // 'loop'
    &if = $04,                 // 'if'
    &else = $05,               // 'else'
    res06 = $06, res07 = $07, res08 = $08, res09 = $09, res0a = $0a,
    &end = $0B,                // 'end'
    br = $0C,                  // 'br'
    br_if = $0D,               // 'br_if'
    br_table = $0E,            // 'br_table'
    return_ = $0F,             // 'return'
    call = $10,                // 'call'
    call_indirect = $11,       // 'call_indirect'
    res13 = $13, res14 = $14, res15 = $15, res16 = $16, res17 = $17, res18 = $18,

    // parametric instructions
    drop = $1A,                // 'drop'
    select = $1B,              // 'select'
    res1D = $1D, res1E = $1E, res1F = $1F,

    // variable instructions
    local_get = $20,           // 'local.get'
    local_set = $21,           // 'local.set'
    local_tee = $22,           // 'local.tee'
    global_get = $23,          // 'global.get'
    global_set = $24,          // 'global.set'
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
    memory_size = $3F,         // 'memory.size'
    memory_grow = $40,         // 'memory.grow'

    // numeric instructions
    i32_const = $41,           // 'i32.const'
    i64_const = $42,           // 'i64.const'
    f32_const = $43,           // 'f32.const'
    f64_const = $44,           // 'f64.const'
    i32_eqz = $45,             // 'i32.eqz'
    i32_eq = $46,              // 'i32.eq'
    i32_ne = $47,              // 'i32.ne'
    i32_lt_s = $48,            // 'i32.lt_s'
    i32_lt_u = $49,            // 'i32.lt_u'
    i32_gt_s = $4A,            // 'i32.gt_s'
    i32_gt_u = $4B,            // 'i32.gt_u'
    i32_le_s = $4C,            // 'i32.le_s'
    i32_le_u = $4D,            // 'i32.le_u'
    i32_ge_s = $4E,            // 'i32.ge_s'
    i32_ge_u = $4F,            // 'i32.ge_u'
    i64_eqz = $50,             // 'i64.eqz'
    i64_eq = $51,              // 'i64.eq'
    i64_ne = $52,              // 'i64.ne'
    i64_lt_s = $53,            // 'i64.lt_s'
    i64_lt_u = $54,            // 'i64.lt_u'
    i64_gt_s = $55,            // 'i64.gt_s'
    i64_gt_u = $56,            // 'i64.gt_u'
    i64_le_s = $57,            // 'i64.le_s'
    i64_le_u = $58,            // 'i64.le_u'
    i64_ge_s = $59,            // 'i64.ge_s'
    i64_ge_u = $5A,            // 'i64.ge_u'
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
    i32_div_s = $6D,           // 'i32.div_s'
    i32_div_u = $6E,           // 'i32.div_u'
    i32_rem_s = $6F,           // 'i32.rem_s'
    i32_rem_u = $70,           // 'i32.rem_u'
    i32_and = $71,             // 'i32.and'
    i32_or = $72,              // 'i32.or'
    i32_xor = $73,             // 'i32.xor'
    i32_shl = $74,             // 'i32.shl'
    i32_shr_s = $75,           // 'i32.shr_s'
    i32_shr_u = $76,           // 'i32.shr_u'
    i32_rotl = $77,            // 'i32.rotl'
    i32_rotr = $78,            // 'i32.rotr'
    i64_clz = $79,             // 'i64.clz'
    i64_ctz = $7A,             // 'i64.ctz'
    i64_popcnt = $7B,          // 'i64.popcnt'
    i64_add = $7C,             // 'i64.add'
    i64_sub = $7D,             // 'i64.sub'
    i64_mul = $7E,             // 'i64.mul'
    i64_div_s = $7F,           // 'i64.div_s'
    i64_div_u = $80,           // 'i64.div_u'
    i64_rem_s = $81,           // 'i64.rem_s'
    i64_rem_u = $82,           // 'i64.rem_u'
    i64_and = $83,             // 'i64.and'
    i64_or = $84,              // 'i64.or'
    i64_xor = $85,             // 'i64.xor'
    i64_shl = $86,             // 'i64.shl'
    i64_shr_s = $87,           // 'i64.shr_s'
    i64_shr_u = $88,           // 'i64.shr_u'
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
    i32_trunc_f32_s = $A8,     // 'i32.trunc_f32_s'
    i32_trunc_f32_u = $A9,     // 'i32.trunc_f32_u'
    i32_trunc_f64_s = $AA,     // 'i32.trunc_f64_s'
    i32_trunc_f64_u = $AB,     // 'i32.trunc_f64_u'
    i64_extend_i32_s = $AC,    // 'i64.extend_i32_s'
    i64_extend_i32_u = $AD,    // 'i64.extend_i32_u'
    i64_trunc_f32_s = $AE,     // 'i64.trunc_f32_s'
    i64_trunc_f32_u = $AF,     // 'i64.trunc_f32_u'
    i64_trunc_f64_s = $B0,     // 'i64.trunc_f64_s'
    i64_trunc_f64_u = $B1,     // 'i64.trunc_f64_u'
    f32_convert_i32_s = $B2,   // 'f32.convert_i32_s'
    f32_convert_i32_u = $B3,   // 'f32.convert_i32_u'
    f32_convert_i64_s = $B4,   // 'f32.convert_i64_s'
    f32_convert_i64_u = $B5,   // 'f32.convert_i64_u'
    f32_demote_f64 = $B6,      // 'f32.demote_f64'
    f64_convert_i32_s = $B7,   // 'f64.convert_i32_s'
    f64_convert_i32_u = $B8,   // 'f64.convert_i32_u'
    f64_convert_i64_s = $B9,   // 'f64.convert_i64_s'
    f64_convert_i64_u = $BA,   // 'f64.convert_i64_u'
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

{$EndRegion}

  // Wasm 1.0 spec only has instructions which take at most 2 items
  // and return at most 1 item.
  TValType = (
    none = 0,
    i32 = $7f,
    i64 = $7e,
    f32 = $7d,
    f64 = $7c);

  PInstructionType = ^TInstructionType;
  TInstructionType = record
    inputs: array [0..1] of TValType;
    outputs: TValType;
  end;

function get_instruction_type_table: PInstructionType;

// Returns the table of max alignment values for each instruction - the largest acceptable
// alignment value satisfying `2 ** max_align < memory_width` where memory_width is the number of
// bytes the instruction operates on.
// It may contain invalid value for instructions not needing it.
function get_instruction_max_align_table: Byte;

{$Region 'Operations'}

function rotl(lhs, rhs: Uint32): Uint32; inline;
function rotr(lhs, rhs: Uint32): Uint32; inline;
function clz32(value: Uint32): Uint32;
function ctz32(value: Uint32): Uint32;
function popcount32(value: Uint32): Uint32;
function clz64(value: Uint64): Uint64;
function ctz64(value: Uint64): Uint64;
function popcount64(value: Uint64): Uint64;

{$EndRegion}

implementation

const
  // Order of input parameters is the order they are popped from stack,
  // which is consistent with the order in FuncType::inputs.
  InstructionTypes: array [TInstruction] of TInstructionType = (

    // 5.4.1 Control instructions
    (* unreachable         = 0x00 *) (),
    (* nop                 = 0x01 *) (),
    (* block               = 0x02 *) (),
    (* loop                = 0x03 *) (),
    (* if_                 = 0x04 *) (inputs: (TValType.i32, none)),
    (* else_               = 0x05 *) (),
    (*                       0x06 *) (),
    (*                       0x07 *) (),
    (*                       0x08 *) (),
    (*                       0x09 *) (),
    (*                       0x0a *) (),
    (* end                 = 0x0b *) (),
    (* br                  = 0x0c *) (),
    (* br_if               = 0x0d *) (inputs: (TValType.i32, none)),
    (* br_table            = 0x0e *) (inputs: (TValType.i32, none)),
    (* return_             = 0x0f *) (),

    (* call                = 0x10 *) (),
    (* call_indirect       = 0x11 *) (inputs: (TValType.i32, none)),

    (*                       0x12 *) (),
    (*                       0x13 *) (),
    (*                       0x14 *) (),
    (*                       0x15 *) (),
    (*                       0x16 *) (),
    (*                       0x17 *) (),
    (*                       0x18 *) (),
    (*                       0x19 *) (),

    // 5.4.2 Parametric instructions
    // Stack polymorphic instructions - validated at instruction handler in expression parser.
    (* drop                = 0x1a *) (),
    (* select              = 0x1b *) (inputs: (TValType.i32, none)),

    (*                       0x1c *) (),
    (*                       0x1d *) (),
    (*                       0x1e *) (),
    (*                       0x1f *) (),

    // 5.4.3 Variable instructions
    // Stack polymorphic instructions - validated at instruction handler in expression parser.
    (* local_get           = 0x20 *) (),
    (* local_set           = 0x21 *) (),
    (* local_tee           = 0x22 *) (),
    (* global_get          = 0x23 *) (),
    (* global_set          = 0x24 *) (),

    (*                       0x25 *) (),
    (*                       0x26 *) (),
    (*                       0x27 *) (),

    // 5.4.4 Memory instructions
    (* i32_load            = 0x28 *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i64_load            = 0x29 *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* f32_load            = 0x2a *) (inputs: (TValType.i32, none); outputs: (TValType.f32)),
    (* f64_load            = 0x2b *) (inputs: (TValType.i32, none); outputs: (TValType.f64)),
    (* i32_load8_s         = 0x2c *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i32_load8_u         = 0x2d *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i32_load16_s        = 0x2e *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i32_load16_u        = 0x2f *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i64_load8_s         = 0x30 *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* i64_load8_u         = 0x31 *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* i64_load16_s        = 0x32 *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* i64_load16_u        = 0x33 *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* i64_load32_s        = 0x34 *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* i64_load32_u        = 0x35 *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* i32_store           = 0x36 *) (inputs: (TValType.i32, TValType.i32)),
    (* i64_store           = 0x37 *) (inputs: (TValType.i32, TValType.i64)),
    (* f32_store           = 0x38 *) (inputs: (TValType.i32, TValType.f32)),
    (* f64_store           = 0x39 *) (inputs: (TValType.i32, TValType.f64)),
    (* i32_store8          = 0x3a *) (inputs: (TValType.i32, TValType.i32)),
    (* i32_store16         = 0x3b *) (inputs: (TValType.i32, TValType.i32)),
    (* i64_store8          = 0x3c *) (inputs: (TValType.i32, TValType.i64)),
    (* i64_store16         = 0x3d *) (inputs: (TValType.i32, TValType.i64)),
    (* i64_store32         = 0x3e *) (inputs: (TValType.i32, TValType.i64)),
    (* memory_size         = 0x3f *) (outputs: (TValType.i32)),
    (* memory_grow         = 0x40 *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),

    // 5.4.5 Numeric instructions
    (* i32_const           = 0x41 *) (outputs: (TValType.i32)),
    (* i64_const           = 0x42 *) (outputs: (TValType.i64)),
    (* f32_const           = 0x43 *) (outputs: (TValType.f32)),
    (* f64_const           = 0x44 *) (outputs: (TValType.f64)),

    (* i32_eqz             = 0x45 *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i32_eq              = 0x46 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_ne              = 0x47 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_lt_s            = 0x48 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_lt_u            = 0x49 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_gt_s            = 0x4a *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_gt_u            = 0x4b *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_le_s            = 0x4c *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_le_u            = 0x4d *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_ge_s            = 0x4e *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_ge_u            = 0x4f *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),

    (* i64_eqz             = 0x50 *) (inputs: (TValType.i64, none); outputs: (TValType.i32)),
    (* i64_eq              = 0x51 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_ne              = 0x52 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_lt_s            = 0x53 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_lt_u            = 0x54 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_gt_s            = 0x55 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_gt_u            = 0x56 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_le_s            = 0x57 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_le_u            = 0x58 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_ge_s            = 0x59 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_ge_u            = 0x5a *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),

    (* f32_eq              = 0x5b *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_ne              = 0x5c *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_lt              = 0x5d *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_gt              = 0x5e *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_le              = 0x5f *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_ge              = 0x60 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),

    (* f64_eq              = 0x61 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_ne              = 0x62 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_lt              = 0x63 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_gt              = 0x64 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_le              = 0x65 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_ge              = 0x66 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),

    (* i32_clz             = 0x67 *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i32_ctz             = 0x68 *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i32_popcnt          = 0x69 *) (inputs: (TValType.i32, none); outputs: (TValType.i32)),
    (* i32_add             = 0x6a *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_sub             = 0x6b *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_mul             = 0x6c *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_div_s           = 0x6d *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_div_u           = 0x6e *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_rem_s           = 0x6f *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_rem_u           = 0x70 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_and             = 0x71 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_or              = 0x72 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_xor             = 0x73 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_shl             = 0x74 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_shr_s           = 0x75 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_shr_u           = 0x76 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_rotl            = 0x77 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_rotr            = 0x78 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),

    (* i64_clz             = 0x79 *) (inputs: (TValType.i64, none); outputs: (TValType.i64)),
    (* i64_ctz             = 0x7a *) (inputs: (TValType.i64, none); outputs: (TValType.i64)),
    (* i64_popcnt          = 0x7b *) (inputs: (TValType.i64, none); outputs: (TValType.i64)),
    (* i64_add             = 0x7c *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_sub             = 0x7d *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_mul             = 0x7e *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_div_s           = 0x7f *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_div_u           = 0x80 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_rem_s           = 0x81 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_rem_u           = 0x82 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_and             = 0x83 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_or              = 0x84 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_xor             = 0x85 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_shl             = 0x86 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_shr_s           = 0x87 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_shr_u           = 0x88 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_rotl            = 0x89 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_rotr            = 0x8a *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),

    (* f32_abs             = 0x8b *) (inputs: (TValType.f32, none); outputs: (TValType.f32)),
    (* f32_neg             = 0x8c *) (inputs: (TValType.f32, none); outputs: (TValType.f32)),
    (* f32_ceil            = 0x8d *) (inputs: (TValType.f32, none); outputs: (TValType.f32)),
    (* f32_floor           = 0x8e *) (inputs: (TValType.f32, none); outputs: (TValType.f32)),
    (* f32_trunc           = 0x8f *) (inputs: (TValType.f32, none); outputs: (TValType.f32)),
    (* f32_nearest         = 0x90 *) (inputs: (TValType.f32, none); outputs: (TValType.f32)),
    (* f32_sqrt            = 0x91 *) (inputs: (TValType.f32, none); outputs: (TValType.f32)),
    (* f32_add             = 0x92 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_sub             = 0x93 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_mul             = 0x94 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_div             = 0x95 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_min             = 0x96 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_max             = 0x97 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_copysign        = 0x98 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),

    (* f64_abs             = 0x99 *) (inputs: (TValType.f64, none); outputs: (TValType.f64)),
    (* f64_neg             = 0x9a *) (inputs: (TValType.f64, none); outputs: (TValType.f64)),
    (* f64_ceil            = 0x9b *) (inputs: (TValType.f64, none); outputs: (TValType.f64)),
    (* f64_floor           = 0x9c *) (inputs: (TValType.f64, none); outputs: (TValType.f64)),
    (* f64_trunc           = 0x9d *) (inputs: (TValType.f64, none); outputs: (TValType.f64)),
    (* f64_nearest         = 0x9e *) (inputs: (TValType.f64, none); outputs: (TValType.f64)),
    (* f64_sqrt            = 0x9f *) (inputs: (TValType.f64, none); outputs: (TValType.f64)),
    (* f64_add             = 0xa0 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_sub             = 0xa1 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_mul             = 0xa2 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_div             = 0xa3 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_min             = 0xa4 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_max             = 0xa5 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_copysign        = 0xa6 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),

    (* i32_wrap_i64        = 0xa7 *) (inputs: (TValType.i64, none); outputs: (TValType.i32)),
    (* i32_trunc_f32_s     = 0xa8 *) (inputs: (TValType.f32, none); outputs: (TValType.i32)),
    (* i32_trunc_f32_u     = 0xa9 *) (inputs: (TValType.f32, none); outputs: (TValType.i32)),
    (* i32_trunc_f64_s     = 0xaa *) (inputs: (TValType.f64, none); outputs: (TValType.i32)),
    (* i32_trunc_f64_u     = 0xab *) (inputs: (TValType.f64, none); outputs: (TValType.i32)),
    (* i64_extend_i32_s    = 0xac *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* i64_extend_i32_u    = 0xad *) (inputs: (TValType.i32, none); outputs: (TValType.i64)),
    (* i64_trunc_f32_s     = 0xae *) (inputs: (TValType.f32, none); outputs: (TValType.i64)),
    (* i64_trunc_f32_u     = 0xaf *) (inputs: (TValType.f32, none); outputs: (TValType.i64)),
    (* i64_trunc_f64_s     = 0xb0 *) (inputs: (TValType.f64, none); outputs: (TValType.i64)),
    (* i64_trunc_f64_u     = 0xb1 *) (inputs: (TValType.f64, none); outputs: (TValType.i64)),
    (* f32_convert_i32_s   = 0xb2 *) (inputs: (TValType.i32, none); outputs: (TValType.f32)),
    (* f32_convert_i32_u   = 0xb3 *) (inputs: (TValType.i32, none); outputs: (TValType.f32)),
    (* f32_convert_i64_s   = 0xb4 *) (inputs: (TValType.i64, none); outputs: (TValType.f32)),
    (* f32_convert_i64_u   = 0xb5 *) (inputs: (TValType.i64, none); outputs: (TValType.f32)),
    (* f32_demote_f64      = 0xb6 *) (inputs: (TValType.f64, none); outputs: (TValType.f32)),
    (* f64_convert_i32_s   = 0xb7 *) (inputs: (TValType.i32, none); outputs: (TValType.f64)),
    (* f64_convert_i32_u   = 0xb8 *) (inputs: (TValType.i32, none); outputs: (TValType.f64)),
    (* f64_convert_i64_s   = 0xb9 *) (inputs: (TValType.i64, none); outputs: (TValType.f64)),
    (* f64_convert_i64_u   = 0xba *) (inputs: (TValType.i64, none); outputs: (TValType.f64)),
    (* f64_promote_f32     = 0xbb *) (inputs: (TValType.f32, none); outputs: (TValType.f64)),
    (* i32_reinterpret_f32 = 0xbc *) (inputs: (TValType.f32, none); outputs: (TValType.i32)),
    (* i64_reinterpret_f64 = 0xbd *) (inputs: (TValType.f64, none); outputs: (TValType.i64)),
    (* f32_reinterpret_i32 = 0xbe *) (inputs: (TValType.i32, none); outputs: (TValType.f32)),
    (* f64_reinterpret_i64 = 0xbf *) (inputs: (TValType.i64, none); outputs: (TValType.f64)),
    (), (), (), (), ()
    );

type
  U64 = record
    case Integer of
      1: (i64: Uint64);
      2: (lo, hi: Uint32);
  end;

function get_instruction_type_table: PInstructionType;
begin
  Result := @InstructionTypes;
end;

function get_instruction_max_align_table: Byte;
begin
  Result := 0;
end;

{$Region 'Operations'}

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
  BSR     ECX,ECX
  NEG     ECX
  ADD     ECX,31
  MOV     EAX,ECX
{$ENDIF}
{$IF Defined(CPUX86)}
  BSR     EAX,EAX
  NEG     EAX
  ADD     EAX,31
{$ENDIF}
end;

function __builtin_ctz(x: Uint32): Uint32;
asm
{$IF Defined(CPUX64)}
  BSF     ECX,ECX
  MOV     EAX,ECX
{$ENDIF}
{$IF Defined(CPUX86)}
  BSF     EAX,EAX
{$ENDIF}
end;

function __builtin_clzll(x: Uint64): Uint64;
asm
{$IF Defined(CPUX64)}
  BSR     RCX,RCX
  NEG     RCX
  ADD     RCX,63
  MOV     RAX,RCX
{$ENDIF}
{$IF Defined(CPUX86)}
  BSR     EAX,EAX
  NEG     EAX
  ADD     EAX,63
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

{$IF Defined(CPUX86)}
function popcount64(value: Uint64): Uint64;
begin
  Result := popcount32(U64(value).hi) + popcount32(U64(value).lo);
end;
{$ENDIF}

{$EndRegion}

end.

