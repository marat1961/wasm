program Wasm;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Wasm.Instruction in 'src\Wasm.Instruction.pas',
  Wasm.Interpreter in 'src\Wasm.Interpreter.pas',
  Wasm.Types in 'src\Wasm.Types.pas',
  Wasm.Value in 'src\Wasm.Value.pas';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
