program WasmTests;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  Oz.Tests in 'Oz.Tests.pas',
  Oz.Wasm.Instruction in '..\src\Oz.Wasm.Instruction.pas',
  Oz.Wasm.Interpreter in '..\src\Oz.Wasm.Interpreter.pas',
  Oz.Wasm.Limits in '..\src\Oz.Wasm.Limits.pas',
  Oz.Wasm.Module in '..\src\Oz.Wasm.Module.pas',
  Oz.Wasm.Types in '..\src\Oz.Wasm.Types.pas',
  Oz.Wasm.Utils in '..\src\Oz.Wasm.Utils.pas',
  Oz.Wasm.Value in '..\src\Oz.Wasm.Value.pas',
  Oz.Wasm.TestNumeric in 'Oz.Wasm.TestNumeric.pas';

{$R *.RES}

begin
  DUnitTestRunner.RunRegisteredTests;
end.

