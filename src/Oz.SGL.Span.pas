(* Oz.SGL
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: Apache-2.0
 *)
unit Oz.SGL.Span;

interface

{$Region 'TSpan: a contiguous sequence of objects'}

type
  // The span describes an object that can refer to a contiguous sequence
  // of objects with the first element of the sequence at position zero.
  TSpan<T> = record
  type
    Pt = ^T;
  var
    FStart: Pt;
    FSize: Cardinal;
  public
    constructor From(start: Pt; size: Cardinal);
  end;

{$EndRegion}

implementation

{$Region 'TSpan<T>'}

constructor TSpan<T>.From(start: Pt; size: Cardinal);
begin
  FStart := start;
  FSize := size;
end;

{$EndRegion}

end.

