unit MarkdownRenderer;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.ComCtrls,
  Vcl.Graphics;

type
  TMarkdownRenderer = class
  private
    class procedure AppendPlain(ARichEdit: TRichEdit; const AText: string); static;
    class procedure AppendStyled(ARichEdit: TRichEdit; const AText: string; AStyles: TFontStyles); static;
    class procedure AppendInlineMarkdown(ARichEdit: TRichEdit; const AText: string); static;
    class function StripPrefix(const ALine, APrefix: string): string; static;
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

      for I := 0 to Lines.Count - 1 do
      begin
        Line := Lines[I];

        if Line.StartsWith('```') then
        begin
          InCodeBlock := not InCodeBlock;
          Continue;
        end;

        if InCodeBlock then
        begin
          ARichEdit.SelAttributes.Name := 'Consolas';
          ARichEdit.SelAttributes.Size := 10;
          ARichEdit.SelAttributes.Style := [];
          ARichEdit.SelText := Line + sLineBreak;
          Continue;
        end;

        if Line.StartsWith('# ') then
        begin
          ARichEdit.SelAttributes.Name := 'Segoe UI';
          ARichEdit.SelAttributes.Size := 16;
          ARichEdit.SelAttributes.Style := [fsBold];
          ARichEdit.SelText := StripPrefix(Line, '# ') + sLineBreak;
          Continue;
        end;

        if Line.StartsWith('## ') then
        begin
          ARichEdit.SelAttributes.Name := 'Segoe UI';
          ARichEdit.SelAttributes.Size := 14;
          ARichEdit.SelAttributes.Style := [fsBold];
          ARichEdit.SelText := StripPrefix(Line, '## ') + sLineBreak;
          Continue;
        end;

        if Line.StartsWith('### ') then
        begin
          ARichEdit.SelAttributes.Name := 'Segoe UI';
          ARichEdit.SelAttributes.Size := 12;
          ARichEdit.SelAttributes.Style := [fsBold];
          ARichEdit.SelText := StripPrefix(Line, '### ') + sLineBreak;
          Continue;
        end;

        if Line.StartsWith('- ') or Line.StartsWith('* ') then
        begin
          AppendPlain(ARichEdit, '• ');
          AppendInlineMarkdown(ARichEdit, Trim(Copy(Line, 3, MaxInt)));
          AppendPlain(ARichEdit, sLineBreak);
          Continue;
        end;

        if Trim(Line) = '---' then
        begin
          AppendPlain(ARichEdit, StringOfChar('-', 70) + sLineBreak);
          Continue;
        end;

        AppendInlineMarkdown(ARichEdit, Line);
        AppendPlain(ARichEdit, sLineBreak);
      end;
    finally
      Lines.Free;
    end;
  finally
    ARichEdit.Lines.EndUpdate;
  end;
end;

end.
