(* Oz.Wasm: A fast Delphi WebAssembly interpreter
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 * SPDX-License-Identifier: (GPL-3.0-or-later OR Apache-2.0)
 *)
program Wasm;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Oz.SGL.Span in 'src\Oz.SGL.Span.pas',
  Oz.Wasm.Instruction in 'src\Oz.Wasm.Instruction.pas',
  Oz.Wasm.Types in 'src\Oz.Wasm.Types.pas',
  Oz.Wasm.Value in 'src\Oz.Wasm.Value.pas',
  Oz.Wasm.Module in 'src\Oz.Wasm.Module.pas',
  Oz.Wasm.Limits in 'src\Oz.Wasm.Limits.pas',
  Oz.Wasm.Interpreter in 'src\Oz.Wasm.Interpreter.pas',
  Oz.Wasm.Utils in 'src\Oz.Wasm.Utils.pas';

begin
  try

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
