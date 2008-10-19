(*======================================================================*
 | unitMessageYEncodedBinary unit for NewsReader3                       |
 |                                                                      |
 | yEnc attachment Decoder                                              |
 |                                                                      |
 | Provides the bare minimum at the moment.                             |
 |                                                                      |
 | 1.  No multipart support                                             |
 | 2.  No CRC or other checking.                                        |
 |                                                                      |
 | The contents of this file are subject to the Mozilla Public License  |
 | Version 1.1 (the "License"); you may not use this file except in     |
 | compliance with the License. You may obtain a copy of the License    |
 | at http://www.mozilla.org/MPL/                                       |
 |                                                                      |
 | Software distributed under the License is distributed on an "AS IS"  |
 | basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See  |
 | the License for the specific language governing rights and           |
 | limitations under the License.                                       |
 |                                                                      |
 | Copyright � Colin Wilson 2002  All Rights Reserved                   |
 |                                                                      |
 | Version  Date        By    Description                               |
 | -------  ----------  ----  ------------------------------------------|
 | 1.0      02/05/2002  CPWW  Original                                  |
 *======================================================================*)

unit unitMessageYEncodedBinary;

interface

uses
  Windows, Classes, SysUtils, unitMessages, graphics, dialogs, Jpeg;

type
  TmvYEncodedBinary = class(TmvMessagePart)
  private
    fGotBegin: Boolean;
    fFileName: string;
    procedure ParseHeaderLine(const st: string);
  protected
    class function IsBoundary(const st: string; MIMEHeader: TMIMEHeader): Boolean; override;
    function IsBoundaryEnd(const st: string): Boolean; override;
    function ProcessHeaderLine(const st: string): Boolean; override;
    function GetGraphic: TGraphic; override;
    function GetFileName: string; override;
    function GetDecodeType: TDecodeType; override;
  public
    procedure GetData(s: TStream); override;
  end;

implementation

{ TmvYEncodedBinary }

(*----------------------------------------------------------------------*
 | procedure TmvYEncodedBinary.GetData                                  |
 |                                                                      |
 | Decode the data in fData into stream 's'                             |
 |                                                                      |
 | Parameters:                                                          |
 |   s: TStream          Receives the decoded data.                     |
 *----------------------------------------------------------------------*)
procedure TmvYEncodedBinary.GetData(s: TStream);
var
  b: Byte;
  ms: TMemoryStream;
  pSrc: PByte;
  pSrcEnd: PByte;
  pDst: PByte;
  pDstStart: PByte;
begin
  if not Assigned(fData) then
    Exit;

  pSrc := fData.Memory;
  pSrcEnd := pSrc + fData.Size - 1;

  ms := TMemoryStream.Create;
  try
    ms.Size := fData.Size;               // "pre-allocate" buffer stream.
    pDstStart := ms.Memory;
    pDst := pDstStart + ms.Position;

    if Assigned(pDstStart) then
    begin
      while pSrc <= pSrcEnd do
      begin
        b := pSrc^;
        if b = Ord('=') then
        begin                            // If our (incomplete) chunk of encoded data ends
                                         // with '=', finish.  We'll catch it next time,
                                         // when we've got more data to work with.
          if pSrc = pSrcEnd then
            Break
          else
          begin                          // Next character is munged.
            Inc(pSrc);
            b := Byte(pSrc^ - 64 - 42);  // Un-munge it
            Inc(pSrc);
          end;
        end
        else
        begin                            // This is a probably a good character.
          Inc(pSrc);
          if b in [10, 13] then          // ... but drop CR & LF. They'll always be munged.
            Continue;
          b := Byte(b - 42);             // Subtract 42? The answer to the ultimate question!
        end;

        pDst^ := b;                      // Write to buffer stream.
        Inc(pDst);
      end;

      ms.Size := pDst - pDstStart;       // Re-adjust buffer stream size.
    end;
    s.CopyFrom(ms, 0);
  finally
    ms.Free;
  end;
end;

function TmvYEncodedBinary.GetDecodeType: TDecodeType;
begin
  Result := ttYEnc;
end;

function TmvYEncodedBinary.GetFileName: string;
begin
  Result := fFileName;
end;

(*----------------------------------------------------------------------*
 | procedure TmvYEncodedBinary.GetGraphic                               |
 |                                                                      |
 | I'm not sure why this isn't in the base class.  It's the same as     |
 | the uuencoded message part stuff.                                    |
 |                                                                      |
 | Get the graphic representation of the attachment                     |
 *----------------------------------------------------------------------*)
function TmvYEncodedBinary.GetGraphic: TGraphic;
var
  ext: string;
  gc: TGraphicClass;
begin
  if not fGotGraphic then
  begin
    if not Assigned(fGraphic) then
    begin
      ext := ExtractFileExt(FileName);
      gc := GetGraphicClass(ext);
    end
    else
      gc := nil;

    DecodeGraphic(gc);
  end;
  Result := fGraphic;
end;

(*----------------------------------------------------------------------*
 | class procedure TmvYEncodedBinary.IsBoundary                         |
 |                                                                      |
 | Return 'True' if the line is the start line of a yEnc attachment     |
 |                                                                      |
 | Parameters:                                                          |
 |   const st: string;          The string to check                     |
 |   fIsMIME: Boolean           Maybe we should check this, and return  |
 |                              false if it's set?                      |
 *----------------------------------------------------------------------*)
class function TmvYEncodedBinary.IsBoundary(const st: string; MIMEHeader: TMIMEHeader): Boolean;
begin
  Result := (Length(st) > 7) and
            (CompareText(Copy(st, 1, 7), '=ybegin') = 0) and
            (st[8] = ' ');
end;

(*----------------------------------------------------------------------*
 | procedure TmvYEncodedBinary.IsBoundaryEnd                            |
 |                                                                      |
 | Return 'True' if the line is the end line of a yEnc attachment       |
 |                                                                      |
 | The spec says check the CRC, bytes & lines to ensure that the        |
 | data is valid.  But let's take a more laissez-faire attitude.  There |
 | may be *something* thats OK!                                         |
 |                                                                      |
 | Parameters:                                                          |
 |   const st: string           The string to check                     |
 *----------------------------------------------------------------------*)
function TmvYEncodedBinary.IsBoundaryEnd(const st: string): Boolean;
begin
  Result := (Length(st) > 5) and
            (CompareText(Copy(st, 1, 5), '=yend') = 0) and
            (st[6] = ' ');
end;

(*----------------------------------------------------------------------*
 | procedure TmvYEncodedBinary.ParseHeaderLine                          |
 |                                                                      |
 | The line may be the =ybegin one, or a a =ypart one.  Break it apart  |
 *----------------------------------------------------------------------*)
procedure TmvYEncodedBinary.ParseHeaderLine(const st: string);
var
  s1: string;
  vName, vValue: string;
  inPart: Boolean;
  p: Integer;
begin
  inPart := False;
  if not fGotBegin then // If we haven't already got =ybegin, nothing else will do.
    if CompareText(Copy(st, 1, 7), '=ybegin') <> 0 then
      Exit
    else
      fGotBegin := True
  else
                        // If we have already had =ybegin, then this should be =ypart
    if CompareText(Copy(st, 1, 6), '=ypart') <> 0 then
      Exit
    else
      inPart := True;

  s1 := st;
  p := Pos(' ', st);
  while p > 0 do
  begin
    s1 := Trim(Copy(s1, p + 1, MaxInt));
    p := Pos('=', s1);
    if p > 0 then
    begin
      vName := Trim(Copy(s1, 1, p - 1));
      s1 := Trim(Copy(s1, p + 1, MaxInt));

                        // 'name' is always the last thing.  And the file-name may
                        // contain a quoted-string with spaces.  So make sure we don't
                        // continue.
      if CompareText(vName, 'name') = 0 then
      begin
        fFileName := Trim(s1);
        Exit;
      end
      else
      begin
        p := Pos(' ', s1);
        if p > 0 then
          vValue := Trim(Copy(s1, 1, p - 1))
        else
          vValue := Trim(s1);
      end;

      if (vName <> '') and (vValue <> '') then
      begin
        if InPart then
        // Save size, lines, crc, etc.
      end
      else
        Break;
    end;
  end;
end;

(*----------------------------------------------------------------------*
 | procedure TmvYEncodedBinary.ProcessHeaderLine                        |
 |                                                                      |
 | The line may be =ybegin, =ypart, or the first line of data           |
 | If it's the first line of data, stuff it into the encoded data       |
 | buffer - otherwise parse it.                                         |
 |                                                                      |
 | Parameters:                                                          |
 |   const st: string           The line to check                       |
 |                                                                      |
 | The function returns False if it was a data line.                    |
 *----------------------------------------------------------------------*)
function TmvYEncodedBinary.ProcessHeaderLine(const st: string): Boolean;
begin
  Result := Copy(st, 1, 2) = '=y';
  if not Result then
  begin
    fData := TMemoryStream.Create;
    AddLine(AnsiString(st));
    Exit;
  end;

  ParseHeaderLine(st);
end;

initialization
  RegisterMessagePart(TmvYEncodedBinary);
end.
