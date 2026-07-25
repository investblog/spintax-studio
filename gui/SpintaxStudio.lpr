{**
 * Spintax Studio -- the application entry point.
 *
 * Two lines here are load-bearing and both are host duties the libraries below cannot
 * perform for their caller: the UTF-8 codepage (or Cyrillic is '?' before the engine sees
 * it, spec §7) and RequireDerivedFormResource := False, because this project's forms are
 * built in code and have no .lfm resource to load.
 *}
program SpintaxStudio;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, SpxStudio, SpxMainForm;

begin
  SpxInitHost;
  RequireDerivedFormResource := False;
  Application.Title := 'Spintax Studio';
  Application.Scaled := True;
  Application.Initialize;
  MainForm := TSpxMainForm.Create(Application);
  MainForm.Show;
  Application.Run;
end.
