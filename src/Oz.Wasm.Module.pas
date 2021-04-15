(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
unit Oz.Wasm.Module;

interface

uses
  Oz.Wasm.Types;

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
    importedFunctionTypes: TArray<TFuncType> ;
    // Types of tables defined in import section
    importedTableTypes: TArray<TTable>;
    // Types of memories defined in import section
    importedMemoryTypes: TArray<TMemory>;
    // Types of globals defined in import section
    importedGlobalTypes: TArray<TGlobalType>;
  public
    function getFunctionCount: NativeInt;
    function getFunctionType(idx: TFuncIdx): TFuncType;
    function getGlobalCount: NativeInt;
    function getGlobalType(idx: TGlobalIdx): TGlobalType;
    function getCode(func_idx: TFuncIdx): TCode;
    function hasTable: Boolean;
    function hasMemory: Boolean;
  end;

implementation

function TModule.getFunctionCount: NativeInt;
begin
  Result := Length(importedFunctionTypes) + Length(funcsec);
end;

function TModule.getFunctionType(idx: TFuncIdx): TFuncType;
var
  type_idx: Integer;
begin
  assert(idx < getFunctionCount);
  if idx < Length(importedFunctionTypes) then
    exit(importedFunctionTypes[idx]);
  type_idx := funcsec[idx - Length(importedFunctionTypes)];
  assert(type_idx < Length(typesec));
  Result := typesec[type_idx];
end;

function TModule.getGlobalCount: NativeInt;
begin
  Result := Length(importedGlobalTypes) + Length(globalsec);
end;

function TModule.getGlobalType(idx: TGlobalIdx): TGlobalType;
begin
  assert(idx < getGlobalCount);
  if idx < Length(importedGlobalTypes) then
    Result := importedGlobalTypes[idx]
  else
    Result := globalsec[idx - Length(importedGlobalTypes)].typ;
end;

function TModule.getCode(func_idx: TFuncIdx): TCode;
var
  code_idx: Integer;
begin
  assert(func_idx >= Length(importedFunctionTypes) {function can't be imported});
  code_idx := func_idx - Length(importedFunctionTypes);
  assert(code_idx < Length(codesec));
  Result := codesec[code_idx];
end;

function TModule.hasTable: Boolean;
begin
  Result := (tablesec <> nil) or (importedTableTypes <> nil);
end;

function TModule.hasMemory: Boolean;
begin
  Result := (memorysec <> nil) or (importedMemoryTypes <> nil);
end;

end.

