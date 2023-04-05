unit Engine;

{
  Diese Quelldatei enthält Code zur Kommunikation mit der Engine in einem Konsolenfenster.
  Diese läuft dabei mittels zweier Pipes zwischen der Konsolenanwendung und dem Hauptprogramm ab.
}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Math, ExtCtrls, StdCtrls, Menus, ShellAPI, Board;

type
  TEngineData = class
  public
    // Lese- und Schreibkomponenten der Pipes
    in_read, in_write, out_read, out_write: THandle;

    // Prozessinformationen über die Engine
    info: PROCESS_INFORMATION;

    // Läuft die Engine (fehlerfrei)
    is_started: boolean;

    // Zum starten der Anwendung benötigte Eigenschaften
    securityAttr: SECURITY_ATTRIBUTES;

    constructor Create;
  end;

  // Eigener Nebenthread, in dem Kommunikation mit der Anwendung stattfindet.
  TEngineThread = class(TThread)
    public
      // asynchron geupdatetes Feld
      // enthält den finalen Zug der Engine als movestring
      engineMove: string;

      // Startet eine neue Instanz des Threads
      constructor Create(engine: TEngineData; move: string);

    protected
      // Informationen über die Engine und Zugriff auf die Pipe-Handles
      EngineData: TEngineData;

      // Die aktuelle Stellung der Figuren als absoluter movestring
      movestring: string;

      // Ablaufprozedur des Threads, die asynchron ausgeführt wird
      procedure Execute; override;
  end;

var
  f: TFileStream;

implementation

constructor TEngineThread.Create(engine: TEngineData; move: string);
begin
  // Erstellt eine neue Instanz der TThread-Klasse und startet den Thread
  // (das Argument 'false' führt den Thread sofort aus)
  inherited Create(false);
  EngineData := engine;
  movestring := move;
  engineMove := '';
end;

procedure TEngineThread.Execute;
var
  in_buffer, out_buffer: array[0..4095] of AnsiChar;
  in_msg, out_msg: string;
  bytesRead, bytesWritten: cardinal;
  WasOK: boolean;
  i: integer;

begin
  if EngineData.is_started
  then begin
    bytesWritten := 0;
    bytesRead := 0;

    // Setzen der ersten Nachricht, um der Engine die aktuelle Stellung mitzuteilen
    in_msg := 'position ' + movestring + #10;
    out_msg := '';

    // Leeren beider Buffer
    fillChar(in_buffer, sizeof(in_buffer), #0);
    fillChar(out_buffer, sizeof(out_buffer), #0);

    // Schreiben der aktuellen Nachricht in die Log-Datei
    f.Write(in_msg[1], length(in_msg) * sizeof(char));

    // Kopieren der ersten Nachricht in den Input-Buffer,
    // anschließendes Schreiben in die Pipe
    StrLCopy(in_buffer, PAnsiChar(in_msg), sizeof(in_buffer) - 1);
    WriteFile(EngineData.in_write, in_buffer, Length(in_msg), bytesWritten, nil);

    // Kurzes delay, um zu garantieren,
    // dass die Engine für die nächste Anweisung bereit ist
    Sleep(100);

    // Setzen der zweiten Nachricht, um der Engine zu sagen,
    // dass sie mit einer Suchtiefe von 19 Zügen und in
    // maximal 3 Sekunden die Stellung analysieren soll
    in_msg := 'go depth 19 movetime 3000' + #10;

    fillChar(in_buffer, sizeof(in_buffer), #0);
    
    f.Write(in_msg[1], length(in_msg) * sizeof(char));

    StrLCopy(in_buffer, PAnsiChar(in_msg), sizeof(in_buffer) - 1);
    WriteFile(EngineData.in_write, in_buffer, Length(in_msg), bytesWritten, nil);

    while true do
    begin
      fillChar(out_buffer, sizeof(out_buffer), #0);
      out_msg := '';

      ReadFile(EngineData.out_read, out_buffer, sizeof(out_buffer), bytesRead, nil);

      out_msg := out_buffer;
      f.Write(out_msg[1], length(out_msg) * sizeof(AnsiChar));

      if out_msg[1] = 'b'
      then break;
    end;

    in_msg := #10;
    f.Write(in_msg[1], length(in_msg) * sizeof(char));

    for i := 10 to 14 do
      engineMove := engineMove + out_msg[i];
  end;
end;


{ Initialisiert das Interface mit der Engine }
constructor TEngineData.Create;
var
  startup: STARTUPINFOA;
  buffer: array[0..255] of AnsiChar;
  log_msg: string;
  read: cardinal;
begin
  f := TFileStream.Create('log.txt', fmOpenReadWrite or fmCreate);

  // Überschreiben des Zielbereichs,
  // um Speichersicherheit zu garantieren
  FillChar(securityAttr, SizeOf(SECURITY_ATTRIBUTES), #0);
  FillChar(startup, SizeOf(STARTUPINFOA), #0);

  with securityAttr do
  begin
    nLength := SizeOf(securityAttr);
    bInheritHandle := True;
    lpSecurityDescriptor := nil;
  end;

  // Erzeugung von Pipes für Kommunikation mit der Engine
  if not (
    createPipe(in_read, in_write, @securityAttr, 0)
    and createPipe(out_read, out_write, @securityAttr, 0)
  )
  then raise Exception.Create('Pipes wurden nicht initialisiert.');

  // Setzen der Pipes als Standardinput bzw. -output des Konsolenfensters
  with startup do
  begin
    cb := SizeOf(startup);
    dwFlags := STARTF_USESTDHANDLES;
    wShowWindow := SW_HIDE;
    hStdInput := in_read;
    hStdOutput := out_write;
    hStdError := out_write;
  end;

  // Starten der Engine als normaler Prozess ohne eigenes Fenster
  is_started := CreateProcess(nil, 'stockfish-windows-2022-x86-64.exe',
      nil, nil, True, NORMAL_PRIORITY_CLASS or CREATE_NO_WINDOW,
      nil, nil, startup, info);

  // Wenn die Engine gestartet ist,
  // entnehme die erste Zeile (Informationen über die Engine)
  // aus dem Lesebuffer und schreibe sie in den Log
  if not is_started
  then ShowMessage('Schach-Engine konnte nicht gestartet werden.' + #13#10 + 'Der Computer-Modus ist nicht verfügbar.')
  else begin
    log_msg := '';
    fillChar(buffer, sizeof(buffer), #0);
    ReadFile(out_read, buffer, sizeof(buffer), read, nil);
    log_msg := buffer;
    log_msg := log_msg + #10;
    f.Write(log_msg[1], length(log_msg) * sizeof(AnsiChar));
  end;
end;

end.