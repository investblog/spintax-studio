{**
 * SpxStudio -- editor-core (spec §5, layer 2): a GUI- and network-free orchestration
 * seam over `unit Spintax`, the layer both the GUI and the LLM loop hang off.
 *
 * It carries one thing so far: the host duty the engine cannot perform for its caller.
 * `RenderSample` / `RenderFragment` / `RenderBatch` / `ExtractModel` / `HealthReport`
 * arrive with M0 -- this unit exists ahead of them so the build, the tests, the hooks and
 * CI are real gates before there is anything to gate.
 *}
unit SpxStudio;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}

interface

{ Call once at start-up, before any engine call.

  Under FPC a `string` holds UTF-8 BYTES, and the RTL decodes literals, files and OS
  strings through DefaultSystemCodePage. Leave it at the machine's ANSI codepage and
  Cyrillic turns into '?' BEFORE the engine ever sees it -- the engine cannot fix that
  for its host, because the setting is a global of the host process. It cost the engine a
  whole debugging session (spec §7), which is why it is the first line of this layer
  rather than a note in a README.

  A UTF-16 compiler needs nothing here: there `string` is code units and no codepage is
  consulted. }
procedure SpxInitHost;

implementation

procedure SpxInitHost;
begin
  {$IFDEF FPC}
  DefaultSystemCodePage := CP_UTF8;
  {$ENDIF}
end;

end.
