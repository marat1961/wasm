(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Instruction;

interface

uses
  Oz.Wasm.Value, Oz.Wasm.Types;

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
    return = $0F,              // 'return'
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

{$Region 'Instruction types and aligns'}

  PInstructionTypeTable = ^TInstructionTypeTable;
  TInstructionTypeTable = array [TInstruction] of TInstructionType;

  PInstructionMaxAlignTable = ^TInstructionMaxAlignTable;
  TInstructionMaxAlignTable = array [TInstruction] of Byte;

// Returns the table of type info for each instruction
function getInstructionTypeTable: PInstructionTypeTable;

// Returns the table of max alignment values for each instruction - the largest
// acceptable alignment value satisfying '2 ** max_align < memory_width'
// where memory_width is the number of bytes the instruction operates on.
// It may contain invalid value for instructions not needing it.
function getInstructionMaxAlignTable: PInstructionMaxAlignTable;

{$EndRegion}

implementation

{$Region 'InstructionTypes'}

const
  // Order of input parameters is the order they are popped from stack,
  // which is consistent with the order in FuncType::inputs.
  InstructionTypes: TInstructionTypeTable = (

    // 5.4.1 Control instructions
    (* unreachable         = $00 *) (),
    (* nop                 = $01 *) (),
    (* block               = $02 *) (),
    (* loop                = $03 *) (),
    (* if                  = $04 *) (inputs: (TValType.i32, TValType.none)),
    (* else                = $05 *) (),
    (*                       $06 *) (),
    (*                       $07 *) (),
    (*                       $08 *) (),
    (*                       $09 *) (),
    (*                       $0a *) (),
    (* end                 = $0b *) (),
    (* br                  = $0c *) (),
    (* br_if               = $0d *) (inputs: (TValType.i32, TValType.none)),
    (* br_table            = $0e *) (inputs: (TValType.i32, TValType.none)),
    (* return              = $0f *) (),

    (* call                = $10 *) (),
    (* call_indirect       = $11 *) (inputs: (TValType.i32, TValType.none)),

    (*                       $12 *) (),
    (*                       $13 *) (),
    (*                       $14 *) (),
    (*                       $15 *) (),
    (*                       $16 *) (),
    (*                       $17 *) (),
    (*                       $18 *) (),
    (*                       $19 *) (),

    // 5.4.2 Parametric instructions
    // Stack polymorphic instructions - validated at instruction handler in expression parser.
    (* drop                = $1a *) (),
    (* select              = $1b *) (inputs: (TValType.i32, TValType.none)),

    (*                       $1c *) (),
    (*                       $1d *) (),
    (*                       $1e *) (),
    (*                       $1f *) (),

    // 5.4.3 Variable instructions
    // Stack polymorphic instructions - validated at instruction handler in expression parser.
    (* local_get           = $20 *) (),
    (* local_set           = $21 *) (),
    (* local_tee           = $22 *) (),
    (* global_get          = $23 *) (),
    (* global_set          = $24 *) (),

    (*                       $25 *) (),
    (*                       $26 *) (),
    (*                       $27 *) (),

    // 5.4.4 Memory instructions
    (* i32_load            = $28 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i64_load            = $29 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* f32_load            = $2a *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.f32)),
    (* f64_load            = $2b *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.f64)),
    (* i32_load8_s         = $2c *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i32_load8_u         = $2d *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i32_load16_s        = $2e *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i32_load16_u        = $2f *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i64_load8_s         = $30 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* i64_load8_u         = $31 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* i64_load16_s        = $32 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* i64_load16_u        = $33 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* i64_load32_s        = $34 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* i64_load32_u        = $35 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* i32_store           = $36 *) (inputs: (TValType.i32, TValType.i32)),
    (* i64_store           = $37 *) (inputs: (TValType.i32, TValType.i64)),
    (* f32_store           = $38 *) (inputs: (TValType.i32, TValType.f32)),
    (* f64_store           = $39 *) (inputs: (TValType.i32, TValType.f64)),
    (* i32_store8          = $3a *) (inputs: (TValType.i32, TValType.i32)),
    (* i32_store16         = $3b *) (inputs: (TValType.i32, TValType.i32)),
    (* i64_store8          = $3c *) (inputs: (TValType.i32, TValType.i64)),
    (* i64_store16         = $3d *) (inputs: (TValType.i32, TValType.i64)),
    (* i64_store32         = $3e *) (inputs: (TValType.i32, TValType.i64)),
    (* memory_size         = $3f *) (outputs: (TValType.i32)),
    (* memory_grow         = $40 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),

    // 5.4.5 Numeric instructions
    (* i32_const           = $41 *) (outputs: (TValType.i32)),
    (* i64_const           = $42 *) (outputs: (TValType.i64)),
    (* f32_const           = $43 *) (outputs: (TValType.f32)),
    (* f64_const           = $44 *) (outputs: (TValType.f64)),

    (* i32_eqz             = $45 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i32_eq              = $46 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_ne              = $47 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_lt_s            = $48 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_lt_u            = $49 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_gt_s            = $4a *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_gt_u            = $4b *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_le_s            = $4c *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_le_u            = $4d *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_ge_s            = $4e *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_ge_u            = $4f *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),

    (* i64_eqz             = $50 *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.i32)),
    (* i64_eq              = $51 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_ne              = $52 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_lt_s            = $53 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_lt_u            = $54 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_gt_s            = $55 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_gt_u            = $56 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_le_s            = $57 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_le_u            = $58 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_ge_s            = $59 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),
    (* i64_ge_u            = $5a *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i32)),

    (* f32_eq              = $5b *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_ne              = $5c *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_lt              = $5d *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_gt              = $5e *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_le              = $5f *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),
    (* f32_ge              = $60 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.i32)),

    (* f64_eq              = $61 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_ne              = $62 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_lt              = $63 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_gt              = $64 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_le              = $65 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),
    (* f64_ge              = $66 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.i32)),

    (* i32_clz             = $67 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i32_ctz             = $68 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i32_popcnt          = $69 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i32)),
    (* i32_add             = $6a *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_sub             = $6b *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_mul             = $6c *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_div_s           = $6d *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_div_u           = $6e *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_rem_s           = $6f *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_rem_u           = $70 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_and             = $71 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_or              = $72 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_xor             = $73 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_shl             = $74 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_shr_s           = $75 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_shr_u           = $76 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_rotl            = $77 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),
    (* i32_rotr            = $78 *) (inputs: (TValType.i32, TValType.i32); outputs: (TValType.i32)),

    (* i64_clz             = $79 *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.i64)),
    (* i64_ctz             = $7a *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.i64)),
    (* i64_popcnt          = $7b *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.i64)),
    (* i64_add             = $7c *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_sub             = $7d *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_mul             = $7e *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_div_s           = $7f *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_div_u           = $80 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_rem_s           = $81 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_rem_u           = $82 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_and             = $83 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_or              = $84 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_xor             = $85 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_shl             = $86 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_shr_s           = $87 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_shr_u           = $88 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_rotl            = $89 *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),
    (* i64_rotr            = $8a *) (inputs: (TValType.i64, TValType.i64); outputs: (TValType.i64)),

    (* f32_abs             = $8b *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.f32)),
    (* f32_neg             = $8c *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.f32)),
    (* f32_ceil            = $8d *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.f32)),
    (* f32_floor           = $8e *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.f32)),
    (* f32_trunc           = $8f *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.f32)),
    (* f32_nearest         = $90 *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.f32)),
    (* f32_sqrt            = $91 *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.f32)),
    (* f32_add             = $92 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_sub             = $93 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_mul             = $94 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_div             = $95 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_min             = $96 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_max             = $97 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),
    (* f32_copysign        = $98 *) (inputs: (TValType.f32, TValType.f32); outputs: (TValType.f32)),

    (* f64_abs             = $99 *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.f64)),
    (* f64_neg             = $9a *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.f64)),
    (* f64_ceil            = $9b *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.f64)),
    (* f64_floor           = $9c *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.f64)),
    (* f64_trunc           = $9d *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.f64)),
    (* f64_nearest         = $9e *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.f64)),
    (* f64_sqrt            = $9f *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.f64)),
    (* f64_add             = $a0 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_sub             = $a1 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_mul             = $a2 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_div             = $a3 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_min             = $a4 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_max             = $a5 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),
    (* f64_copysign        = $a6 *) (inputs: (TValType.f64, TValType.f64); outputs: (TValType.f64)),

    (* i32_wrap_i64        = $a7 *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.i32)),
    (* i32_trunc_f32_s     = $a8 *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.i32)),
    (* i32_trunc_f32_u     = $a9 *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.i32)),
    (* i32_trunc_f64_s     = $aa *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.i32)),
    (* i32_trunc_f64_u     = $ab *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.i32)),
    (* i64_extend_i32_s    = $ac *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* i64_extend_i32_u    = $ad *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.i64)),
    (* i64_trunc_f32_s     = $ae *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.i64)),
    (* i64_trunc_f32_u     = $af *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.i64)),
    (* i64_trunc_f64_s     = $b0 *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.i64)),
    (* i64_trunc_f64_u     = $b1 *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.i64)),
    (* f32_convert_i32_s   = $b2 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.f32)),
    (* f32_convert_i32_u   = $b3 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.f32)),
    (* f32_convert_i64_s   = $b4 *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.f32)),
    (* f32_convert_i64_u   = $b5 *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.f32)),
    (* f32_demote_f64      = $b6 *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.f32)),
    (* f64_convert_i32_s   = $b7 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.f64)),
    (* f64_convert_i32_u   = $b8 *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.f64)),
    (* f64_convert_i64_s   = $b9 *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.f64)),
    (* f64_convert_i64_u   = $ba *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.f64)),
    (* f64_promote_f32     = $bb *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.f64)),
    (* i32_reinterpret_f32 = $bc *) (inputs: (TValType.f32, TValType.none); outputs: (TValType.i32)),
    (* i64_reinterpret_f64 = $bd *) (inputs: (TValType.f64, TValType.none); outputs: (TValType.i64)),
    (* f32_reinterpret_i32 = $be *) (inputs: (TValType.i32, TValType.none); outputs: (TValType.f32)),
    (* f64_reinterpret_i64 = $bf *) (inputs: (TValType.i64, TValType.none); outputs: (TValType.f64)),
    (), (), (), (), ());

{$EndRegion}

{$Region 'InstructionMaxAlign'}

  InstructionMaxAlign: array [TInstruction] of Byte = (
    // 5.4.1 Control instructions
    (* unreachable         = $00 *) 0,
    (* nop                 = $01 *) 0,
    (* block               = $02 *) 0,
    (* loop                = $03 *) 0,
    (* if                  = $04 *) 0,
    (* else                = $05 *) 0,
    (*                       $06 *) 0,
    (*                       $07 *) 0,
    (*                       $08 *) 0,
    (*                       $09 *) 0,
    (*                       $0a *) 0,
    (* end                 = $0b *) 0,
    (* br                  = $0c *) 0,
    (* br_if               = $0d *) 0,
    (* br_table            = $0e *) 0,
    (* return              = $0f *) 0,
    (* call                = $10 *) 0,
    (* call_indirect       = $11 *) 0,

    (*                       $12 *) 0,
    (*                       $13 *) 0,
    (*                       $14 *) 0,
    (*                       $15 *) 0,
    (*                       $16 *) 0,
    (*                       $17 *) 0,
    (*                       $18 *) 0,
    (*                       $19 *) 0,

    // 5.4.2 Parametric instructions
    (* drop                = $1a *) 0,
    (* select              = $1b *) 0,

    (*                       $1c *) 0,
    (*                       $1d *) 0,
    (*                       $1e *) 0,
    (*                       $1f *) 0,

    // 5.4.3 Variable instructions
    (* local_get           = $20 *) 0,
    (* local_set           = $21 *) 0,
    (* local_tee           = $22 *) 0,
    (* global_get          = $23 *) 0,
    (* global_set          = $24 *) 0,

    (*                       $25 *) 0,
    (*                       $26 *) 0,
    (*                       $27 *) 0,

    // 5.4.4 Memory instructions
    (* i32_load            = $28 *) 2,
    (* i64_load            = $29 *) 3,
    (* f32_load            = $2a *) 2,
    (* f64_load            = $2b *) 3,
    (* i32_load8_s         = $2c *) 0,
    (* i32_load8_u         = $2d *) 0,
    (* i32_load16_s        = $2e *) 1,
    (* i32_load16_u        = $2f *) 1,
    (* i64_load8_s         = $30 *) 0,
    (* i64_load8_u         = $31 *) 0,
    (* i64_load16_s        = $32 *) 1,
    (* i64_load16_u        = $33 *) 1,
    (* i64_load32_s        = $34 *) 2,
    (* i64_load32_u        = $35 *) 2,
    (* i32_store           = $36 *) 2,
    (* i64_store           = $37 *) 3,
    (* f32_store           = $38 *) 2,
    (* f64_store           = $39 *) 3,
    (* i32_store8          = $3a *) 0,
    (* i32_store16         = $3b *) 1,
    (* i64_store8          = $3c *) 0,
    (* i64_store16         = $3d *) 1,
    (* i64_store32         = $3e *) 2,
    (* memory_size         = $3f *) 0,
    (* memory_grow         = $40 *) 0,

    // 5.4.5 Numeric instructions
    (* i32_const           = $41 *) 0,
    (* i64_const           = $42 *) 0,
    (* f32_const           = $43 *) 0,
    (* f64_const           = $44 *) 0,

    (* i32_eqz             = $45 *) 0,
    (* i32_eq              = $46 *) 0,
    (* i32_ne              = $47 *) 0,
    (* i32_lt_s            = $48 *) 0,
    (* i32_lt_u            = $49 *) 0,
    (* i32_gt_s            = $4a *) 0,
    (* i32_gt_u            = $4b *) 0,
    (* i32_le_s            = $4c *) 0,
    (* i32_le_u            = $4d *) 0,
    (* i32_ge_s            = $4e *) 0,
    (* i32_ge_u            = $4f *) 0,

    (* i64_eqz             = $50 *) 0,
    (* i64_eq              = $51 *) 0,
    (* i64_ne              = $52 *) 0,
    (* i64_lt_s            = $53 *) 0,
    (* i64_lt_u            = $54 *) 0,
    (* i64_gt_s            = $55 *) 0,
    (* i64_gt_u            = $56 *) 0,
    (* i64_le_s            = $57 *) 0,
    (* i64_le_u            = $58 *) 0,
    (* i64_ge_s            = $59 *) 0,
    (* i64_ge_u            = $5a *) 0,

    (* f32_eq              = $5b *) 0,
    (* f32_ne              = $5c *) 0,
    (* f32_lt              = $5d *) 0,
    (* f32_gt              = $5e *) 0,
    (* f32_le              = $5f *) 0,
    (* f32_ge              = $60 *) 0,

    (* f64_eq              = $61 *) 0,
    (* f64_ne              = $62 *) 0,
    (* f64_lt              = $63 *) 0,
    (* f64_gt              = $64 *) 0,
    (* f64_le              = $65 *) 0,
    (* f64_ge              = $66 *) 0,

    (* i32_clz             = $67 *) 0,
    (* i32_ctz             = $68 *) 0,
    (* i32_popcnt          = $69 *) 0,
    (* i32_add             = $6a *) 0,
    (* i32_sub             = $6b *) 0,
    (* i32_mul             = $6c *) 0,
    (* i32_div_s           = $6d *) 0,
    (* i32_div_u           = $6e *) 0,
    (* i32_rem_s           = $6f *) 0,
    (* i32_rem_u           = $70 *) 0,
    (* i32_and             = $71 *) 0,
    (* i32_or              = $72 *) 0,
    (* i32_xor             = $73 *) 0,
    (* i32_shl             = $74 *) 0,
    (* i32_shr_s           = $75 *) 0,
    (* i32_shr_u           = $76 *) 0,
    (* i32_rotl            = $77 *) 0,
    (* i32_rotr            = $78 *) 0,

    (* i64_clz             = $79 *) 0,
    (* i64_ctz             = $7a *) 0,
    (* i64_popcnt          = $7b *) 0,
    (* i64_add             = $7c *) 0,
    (* i64_sub             = $7d *) 0,
    (* i64_mul             = $7e *) 0,
    (* i64_div_s           = $7f *) 0,
    (* i64_div_u           = $80 *) 0,
    (* i64_rem_s           = $81 *) 0,
    (* i64_rem_u           = $82 *) 0,
    (* i64_and             = $83 *) 0,
    (* i64_or              = $84 *) 0,
    (* i64_xor             = $85 *) 0,
    (* i64_shl             = $86 *) 0,
    (* i64_shr_s           = $87 *) 0,
    (* i64_shr_u           = $88 *) 0,
    (* i64_rotl            = $89 *) 0,
    (* i64_rotr            = $8a *) 0,

    (* f32_abs             = $8b *) 0,
    (* f32_neg             = $8c *) 0,
    (* f32_ceil            = $8d *) 0,
    (* f32_floor           = $8e *) 0,
    (* f32_trunc           = $8f *) 0,
    (* f32_nearest         = $90 *) 0,
    (* f32_sqrt            = $91 *) 0,
    (* f32_add             = $92 *) 0,
    (* f32_sub             = $93 *) 0,
    (* f32_mul             = $94 *) 0,
    (* f32_div             = $95 *) 0,
    (* f32_min             = $96 *) 0,
    (* f32_max             = $97 *) 0,
    (* f32_copysign        = $98 *) 0,

    (* f64_abs             = $99 *) 0,
    (* f64_neg             = $9a *) 0,
    (* f64_ceil            = $9b *) 0,
    (* f64_floor           = $9c *) 0,
    (* f64_trunc           = $9d *) 0,
    (* f64_nearest         = $9e *) 0,
    (* f64_sqrt            = $9f *) 0,
    (* f64_add             = $a0 *) 0,
    (* f64_sub             = $a1 *) 0,
    (* f64_mul             = $a2 *) 0,
    (* f64_div             = $a3 *) 0,
    (* f64_min             = $a4 *) 0,
    (* f64_max             = $a5 *) 0,
    (* f64_copysign        = $a6 *) 0,

    (* i32_wrap_i64        = $a7 *) 0,
    (* i32_trunc_f32_s     = $a8 *) 0,
    (* i32_trunc_f32_u     = $a9 *) 0,
    (* i32_trunc_f64_s     = $aa *) 0,
    (* i32_trunc_f64_u     = $ab *) 0,
    (* i64_extend_i32_s    = $ac *) 0,
    (* i64_extend_i32_u    = $ad *) 0,
    (* i64_trunc_f32_s     = $ae *) 0,
    (* i64_trunc_f32_u     = $af *) 0,
    (* i64_trunc_f64_s     = $b0 *) 0,
    (* i64_trunc_f64_u     = $b1 *) 0,
    (* f32_convert_i32_s   = $b2 *) 0,
    (* f32_convert_i32_u   = $b3 *) 0,
    (* f32_convert_i64_s   = $b4 *) 0,
    (* f32_convert_i64_u   = $b5 *) 0,
    (* f32_demote_f64      = $b6 *) 0,
    (* f64_convert_i32_s   = $b7 *) 0,
    (* f64_convert_i32_u   = $b8 *) 0,
    (* f64_convert_i64_s   = $b9 *) 0,
    (* f64_convert_i64_u   = $ba *) 0,
    (* f64_promote_f32     = $bb *) 0,
    (* i32_reinterpret_f32 = $bc *) 0,
    (* i64_reinterpret_f64 = $bd *) 0,
    (* f32_reinterpret_i32 = $be *) 0,
    (* f64_reinterpret_i64 = $bf *) 0,
    0, 0, 0, 0, 0);

{$EndRegion}

{$Region 'Table getters'}

function getInstructionTypeTable: PInstructionTypeTable;
begin
  Result := @InstructionTypes;
end;

function getInstructionMaxAlignTable: PInstructionMaxAlignTable;
begin
  Result := @InstructionMaxAlign;
end;

{$EndRegion}

end.

