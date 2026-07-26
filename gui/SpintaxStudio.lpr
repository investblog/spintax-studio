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
