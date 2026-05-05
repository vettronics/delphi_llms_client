unit MarkdownRenderer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.ComCtrls,
  Vcl.Graphics;

type
  TMarkdownRenderer = class
  private
    class procedure AppendPlain(ARichEdit: TRichEdit; const AText: string); static;
    class procedure AppendStyled(ARichEdit: TRichEdit; const AText: string; AStyles: TFontStyles); static;
    class procedure AppendInlineMarkdown(ARichEdit: TRichEdit; const AText: string); static;
    class function StripPrefix(const ALine, APrefix: string): string; static;
    class function IsTableRow(const ALine: string): Boolean; static;
    class function IsTableSeparator(const ALine: string): Boolean; static;
    class function SplitTableRow(const ALine: string): TArray<string>; static;
    class function PadRightSafe(const AText: string; AWidth: Integer): string; static;
    class procedure RenderTable(ARichEdit: TRichEdit; const ALines: TStringList; var AIndex: Integer); static;
  public
    class procedure RenderToRichEdit(ARichEdit: TRichEdit; const AMarkdown: string); static;
  end;

implementation

class procedure TMarkdownRenderer.AppendPlain(ARichEdit: TRichEdit; const AText: string);
begin
  ARichEdit.SelAttributes.Style := [];
  ARichEdit.SelAttributes.Size := 10;
  ARichEdit.SelAttributes.Name := 'Segoe UI';
  ARichEdit.SelText := AText;
end;

class procedure TMarkdownRenderer.AppendStyled(ARichEdit: TRichEdit; const AText: string; AStyles: TFontStyles);
begin
  ARichEdit.SelAttributes.Name := 'Segoe UI';
  ARichEdit.SelAttributes.Size := 10;
  ARichEdit.SelAttributes.Style := AStyles;
  ARichEdit.SelText := AText;
  ARichEdit.SelAttributes.Style := [];
end;

class procedure TMarkdownRenderer.AppendInlineMarkdown(ARichEdit: TRichEdit; const AText: string);
var
  I: Integer;
  Start: Integer;
  Token: string;
  ClosePos: Integer;
  Fragment: string;
begin
  I := 1;
  Start := 1;

  while I <= Length(AText) do
  begin
    if Copy(AText, I, 2) = '**' then
    begin
      if I > Start then
        AppendPlain(ARichEdit, Copy(AText, Start, I - Start));
      ClosePos := Pos('**', Copy(AText, I + 2, MaxInt));
      if ClosePos > 0 then
      begin
        Fragment := Copy(AText, I + 2, ClosePos - 1);
        AppendStyled(ARichEdit, Fragment, [fsBold]);
        I := I + 2 + ClosePos + 1;
        Start := I;
        Continue;
      end;
    end;

    if AText[I] = '`' then
    begin
      if I > Start then
        AppendPlain(ARichEdit, Copy(AText, Start, I - Start));
      Token := Copy(AText, I + 1, MaxInt);
      ClosePos := Pos('`', Token);
      if ClosePos > 0 then
      begin
        Fragment := Copy(Token, 1, ClosePos - 1);
        ARichEdit.SelAttributes.Name := 'Consolas';
        ARichEdit.SelAttributes.Size := 10;
        ARichEdit.SelAttributes.Style := [];
        ARichEdit.SelText := Fragment;
        ARichEdit.SelAttributes.Name := 'Segoe UI';
        I := I + ClosePos + 1;
        Start := I;
        Continue;
      end;
    end;

    Inc(I);
  end;

  if Start <= Length(AText) then
    AppendPlain(ARichEdit, Copy(AText, Start, MaxInt));
end;

class function TMarkdownRenderer.StripPrefix(const ALine, APrefix: string): string;
begin
  Result := Trim(Copy(ALine, Length(APrefix) + 1, MaxInt));
end;

class function TMarkdownRenderer.IsTableRow(const ALine: string): Boolean;
var
  S: string;
begin
  S := Trim(ALine);
  Result := (S <> '') and S.Contains('|') and (S.Chars[0] = '|');
end;

class function TMarkdownRenderer.IsTableSeparator(const ALine: string): Boolean;
var
  S: string;
  C: Char;
  HasDash: Boolean;
begin
  S := Trim(ALine);
  Result := False;
  HasDash := False;

  if not IsTableRow(S) then
    Exit;

  S := StringReplace(S, '|', '', [rfReplaceAll]);
  S := StringReplace(S, ':', '', [rfReplaceAll]);
  S := Trim(S);

  if S = '' then
    Exit;

  for C in S do
  begin
    if C = '-' then
      HasDash := True
    else if not CharInSet(C, [' ', #9]) then
      Exit;
  end;

  Result := HasDash;
end;

class function TMarkdownRenderer.SplitTableRow(const ALine: string): TArray<string>;
var
  Parts: TStringList;
  S: string;
  I: Integer;
begin
  S := Trim(ALine);

  if S.StartsWith('|') then
    Delete(S, 1, 1);
  if S.EndsWith('|') then
    Delete(S, Length(S), 1);

  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := '|';
    Parts.DelimitedText := S;
    SetLength(Result, Parts.Count);
    for I := 0 to Parts.Count - 1 do
      Result[I] := Trim(Parts[I]);
  finally
    Parts.Free;
  end;
end;

class function TMarkdownRenderer.PadRightSafe(const AText: string; AWidth: Integer): string;
begin
  Result := AText;
  while Length(Result) < AWidth do
    Result := Result + ' ';
end;

class procedure TMarkdownRenderer.RenderTable(ARichEdit: TRichEdit; const ALines: TStringList; var AIndex: Integer);
var
  Rows: TList<TArray<string>>;
  Widths: TList<Integer>;
  Cells: TArray<string>;
  Row: TArray<string>;
  I, J, MaxCols, W: Integer;
  Line: string;

  procedure EnsureWidthCount(ACount: Integer);
  begin
    while Widths.Count < ACount do
      Widths.Add(0);
  end;

  function BuildSeparator: string;
  var
    K: Integer;
  begin
    Result := '+';
    for K := 0 to Widths.Count - 1 do
      Result := Result + StringOfChar('-', Widths[K] + 2) + '+';
  end;

  function BuildRow(const ARow: TArray<string>): string;
  var
    K: Integer;
    Cell: string;
  begin
    Result := '|';
    for K := 0 to Widths.Count - 1 do
    begin
      if K < Length(ARow) then
        Cell := ARow[K]
      else
        Cell := '';
      Result := Result + ' ' + PadRightSafe(Cell, Widths[K]) + ' |';
    end;
  end;

begin
  Rows := TList<TArray<string>>.Create;
  Widths := TList<Integer>.Create;
  try
    while (AIndex < ALines.Count) and IsTableRow(ALines[AIndex]) do
    begin
      if not IsTableSeparator(ALines[AIndex]) then
      begin
        Cells := SplitTableRow(ALines[AIndex]);
        Rows.Add(Cells);
        EnsureWidthCount(Length(Cells));
        for J := 0 to Length(Cells) - 1 do
        begin
          W := Length(Cells[J]);
          if W > Widths[J] then
            Widths[J] := W;
        end;
      end;
      Inc(AIndex);
    end;

    if Rows.Count = 0 then
      Exit;

    MaxCols := Widths.Count;
    for I := 0 to MaxCols - 1 do
      if Widths[I] < 3 then
        Widths[I] := 3;

    ARichEdit.SelAttributes.Name := 'Consolas';
    ARichEdit.SelAttributes.Size := 10;
    ARichEdit.SelAttributes.Style := [];

    Line := BuildSeparator;
    ARichEdit.SelText := Line + sLineBreak;

    for I := 0 to Rows.Count - 1 do
    begin
      Row := Rows[I];
      if I = 0 then
        ARichEdit.SelAttributes.Style := [fsBold]
      else
        ARichEdit.SelAttributes.Style := [];

      ARichEdit.SelText := BuildRow(Row) + sLineBreak;
      ARichEdit.SelAttributes.Style := [];

      if I = 0 then
        ARichEdit.SelText := Line + sLineBreak;
    end;

    ARichEdit.SelText := Line + sLineBreak;
    ARichEdit.SelAttributes.Name := 'Segoe UI';
  finally
    Widths.Free;
    Rows.Free;
  end;
end;

class procedure TMarkdownRenderer.RenderToRichEdit(ARichEdit: TRichEdit; const AMarkdown: string);
var
  Lines: TStringList;
  I: Integer;
  Line: string;
  InCodeBlock: Boolean;
begin
  ARichEdit.Lines.BeginUpdate;
  try
    ARichEdit.Clear;
    ARichEdit.SelStart := 0;
    InCodeBlock := False;

    Lines := TStringList.Create;
    try
      Lines.Text := StringReplace(AMarkdown, #13#10, #10, [rfReplaceAll]);

      I := 0;
      while I < Lines.Count do
      begin
        Line := Lines[I];

        if Line.StartsWith('```') then
        begin
          InCodeBlock := not InCodeBlock;
          Inc(I);
          Continue;
        end;

        if InCodeBlock then
        begin
          ARichEdit.SelAttributes.Name := 'Consolas';
          ARichEdit.SelAttributes.Size := 10;
          ARichEdit.SelAttributes.Style := [];
          ARichEdit.SelText := Line + sLineBreak;
          Inc(I);
          Continue;
        end;

        if IsTableRow(Line) and (I + 1 < Lines.Count) and IsTableSeparator(Lines[I + 1]) then
        begin
          RenderTable(ARichEdit, Lines, I);
          Continue;
        end;

        if Line.StartsWith('# ') then
        begin
          ARichEdit.SelAttributes.Name := 'Segoe UI';
          ARichEdit.SelAttributes.Size := 16;
          ARichEdit.SelAttributes.Style := [fsBold];
          ARichEdit.SelText := StripPrefix(Line, '# ') + sLineBreak;
          Inc(I);
          Continue;
        end;

        if Line.StartsWith('## ') then
        begin
          ARichEdit.SelAttributes.Name := 'Segoe UI';
          ARichEdit.SelAttributes.Size := 14;
          ARichEdit.SelAttributes.Style := [fsBold];
          ARichEdit.SelText := StripPrefix(Line, '## ') + sLineBreak;
          Inc(I);
          Continue;
        end;

        if Line.StartsWith('### ') then
        begin
          ARichEdit.SelAttributes.Name := 'Segoe UI';
          ARichEdit.SelAttributes.Size := 12;
          ARichEdit.SelAttributes.Style := [fsBold];
          ARichEdit.SelText := StripPrefix(Line, '### ') + sLineBreak;
          Inc(I);
          Continue;
        end;

        if Line.StartsWith('- ') or Line.StartsWith('* ') then
        begin
          AppendPlain(ARichEdit, '• ');
          AppendInlineMarkdown(ARichEdit, Trim(Copy(Line, 3, MaxInt)));
          AppendPlain(ARichEdit, sLineBreak);
          Inc(I);
          Continue;
        end;

        if Trim(Line) = '---' then
        begin
          AppendPlain(ARichEdit, StringOfChar('-', 70) + sLineBreak);
          Inc(I);
          Continue;
        end;

        AppendInlineMarkdown(ARichEdit, Line);
        AppendPlain(ARichEdit, sLineBreak);
        Inc(I);
      end;
    finally
      Lines.Free;
    end;
  finally
    ARichEdit.Lines.EndUpdate;
  end;
end;

end.
