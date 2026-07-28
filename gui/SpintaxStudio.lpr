{**
 * Spintax Studio -- the application entry point.
 *
 * Two lines here are load-bearing, and both are host duties the libraries below cannot
 * perform for their caller: the UTF-8 codepage (or Cyrillic is '?' before the engine sees
 * it, spec §7) and Application.CreateForm -- see below.
 *
 * This project's forms are built in code and have no .lfm to load, which needs no setting
 * to say so: LCL declares RequireDerivedFormResource False (forms.pp) and reads it only in
 * TCustomForm.ProcessResource, a path CreateNew never takes. It was stated here until a
 * review pointed out that it does nothing.
 *}
program SpintaxStudio;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, SpxStudio, SpxMainForm;

{ The project's resource, and it was missing. Lazarus generates SpintaxStudio.res on every
  build -- the Windows manifest lives in it, and the application icon will -- but nothing
  links it into the executable without this line. Measured rather than assumed: the .res
  carried `dpiAware` and the .exe carried no manifest at all, so Windows treated a
  "DPI-aware" application as legacy and would have stretched it as a bitmap on any display
  above 100%. }
{$R *.res}

begin
  SpxInitHost;
  Application.Title := 'Spintax Studio';
  Application.Scaled := True;
  Application.Initialize;
  { CreateForm, not Create: only CreateForm sets Application.MainForm, and LCL ends the
    program solely for the form that IS Application.MainForm -- closing anything else gives
    caHide (customform.inc:2148-2175). Built by hand, this window merely HID itself on close
    while the message loop ran on: a windowless process that still held the .exe locked, so
    the next build could not link. Run then shows the form and calls AppSetupMainForm. }
  Application.CreateForm(TSpxMainForm, MainForm);
  Application.Run;
end.
