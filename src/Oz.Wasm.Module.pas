(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: Apache-2.0
 *)
unit Oz.Wasm.Module;

interface

uses
  System.Classes, System.SysUtils, Oz.Wasm.Types;

{$T+}
{$SCOPEDENUMS ON}

type

  TOptional<T> = record
    value: T;
    define: Boolean;
  end;

  TModule = record
  var
    // Sections
    typesec: TArray<TFuncType>;
    importsec: TArray<TImport>;
    funcsec: TArray<TTypeIdx>;
    tablesec: TArray<TTable>;
    memorysec: TArray<TMemory>;
    globalsec: TArray<TGlobal>;
    exportsec: TArray<TExport>;
    startfunc: TOptional<TFuncIdx>;
    elementsec: TArray<TElement>;
    codesec: TArray<TCode>;
    datasec: TArray<TData>;
    // Types of functions defined in import section
    imported_function_types: TArray<TFuncType> ;
    // Types of tables defined in import section
    imported_table_types: TArray<TTable>;
    // Types of memories defined in import section
    imported_memory_types: TArray<TMemory>;
    // Types of globals defined in import section
    imported_global_types: TArray<TGlobalType>;
  public
    function get_function_count: NativeInt;
    function get_function_type(idx: TFuncIdx): TFuncType;
    function get_global_count: NativeInt;
    function get_global_type(idx: TGlobalIdx): TGlobalType;
    function get_code(func_idx: TFuncIdx): TCode;
    function has_table: Boolean;
    function has_memory: Boolean;
  end;

implementation

function TModule.get_function_count: NativeInt;
begin
  Result := Length(imported_function_types) + Length(funcsec);
end;

function TModule.get_function_type(idx: TFuncIdx): TFuncType;
var
  type_idx: Integer;
begin
  assert(idx < get_function_count);
  if idx < Length(imported_function_types) then
    exit(imported_function_types[idx]);
  type_idx := funcsec[idx - Length(imported_function_types)];
  assert(type_idx < Length(typesec));
  Result := typesec[type_idx];
end;

function TModule.get_global_count: NativeInt;
begin
  Result := Length(imported_global_types) + Length(globalsec);
end;

function TModule.get_global_type(idx: TGlobalIdx): TGlobalType;
begin
  assert(idx < get_global_count());
  if idx < Length(imported_global_types) then
    Result := imported_global_types[idx]
  else
    Result := globalsec[idx - Length(imported_global_types)].typ;
end;

function TModule.get_code(func_idx: TFuncIdx): TCode;
var
  code_idx: Integer;
begin
  assert(func_idx >= Length(imported_function_types) {function can't be imported});
  code_idx := func_idx - Length(imported_function_types);
  assert(code_idx < Length(codesec));
  Result := codesec[code_idx];
end;

function TModule.has_table: Boolean;
begin
  Result := (tablesec <> nil) or (imported_table_types <> nil);
end;

function TModule.has_memory: Boolean;
begin
  Result := (memorysec <> nil) or (imported_memory_types <> nil);
end;

end.

