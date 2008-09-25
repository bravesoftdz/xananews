(*======================================================================*
 | Article Folders for XanaNews                                         |
 |                                                                      |
 | nb.                                                                  |
 |                                                                      |
 |  The Primary Key is used to identify the article by unique ID.       |
 |                                                                      |
 |  For News articles the unique ID is the server/group index +':' +    |
 |                    the article number.                               |
 |                                                                      |
 |  For mail articles the Unique ID is the UIDL of the article.         |
 |                                                                      |
 |  The secondary key is used to provide the sorted list.               |
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
 | Copyright � Colin Wilson 2004  All Rights Reserved
 |                                                                      |
 | Version  Date        By    Description                               |
 | -------  ----------  ----  ------------------------------------------|
 | 1.1      19/01/2004  CPWW  Rewritten                                 |
 *======================================================================*)

unit unitSavedArticles;

interface

uses Windows, Classes, SysUtils, Forms, ConTnrs, unitNNTPServices, unitObjectCache, unitMessages, unitArticleHash, unitSettings, unitIdentities, unitBTree, NewsGlobals, unitExSettings;

type

TFolderArticle = class;

//----------------------------------------------------------------------------
// Cache the most recently access articles in a group - to improve performance
  TFolderArticleCache = class(TObjectCache)
  private
    fCurrentArticle: TFolderArticle;
    fCurrentIdx: Integer;
    procedure CheckArticleProc(obj: TObject; idx, param: Integer; var continue: Boolean);
  protected
    function CanRemove(Obj: TObject): Boolean; override;
  public
    function FindArticle(idx: Integer): TFolderArticle;
  end;

//----------------------------------------------------------------------------
// A folder containing TFolderArticle s
TArticleFolder = class (TArticleContainer)
private
  fIndexing : boolean;
  fArticleCount : Integer;
  fIndex : TBTree;
  fSecondaryIndex : TBTree;
  fFileStream : TFileStream;
  fFileName : string;
  fNoIndex : boolean;
  fNewFile : boolean;
  fSequentialPos : Integer;
  fSequentialIdx : Integer;
  fDeletedArticles : TStringList;
  fFolderArticleCache : TFolderArticleCache;
  function GetIsEmpty: boolean;
  procedure Activate;
  procedure Deactivate;
  procedure ReCreateIndex (sortOrder : TThreadSortOrder);

  function GetFileName: string;
  function GetTempFileName: string;
  function GetIndexFileName: string;
  function GetSecIndexFileName: string;
  procedure FixDots;
protected
  function GetArticleBase (idx : Integer) : TArticleBase; override;
  function GetArticleCount : Integer; override;
  function GetNext : TArticleContainer; override;
  function GetUnreadArticleCount: Integer; override;
  function GetServerSettings : TServerSettings; override;
  function GetLoaded : boolean; override;
  function RawLoadArticleHeader (idx : Integer; var pos : Integer) : TFolderArticle;
  procedure SortArticles; override;
  procedure SetName(const Value: string); override;
  function GetAdjustedArticleCount: Integer; override;

public
  constructor Create (const AName : String);
  constructor CreateFile (const AFileName : String; ANewFile, ANoIndex : boolean);
  destructor Destroy; override;

  procedure BeginAdd;
  procedure EndAdd;
  procedure AddArticle (article : TArticleBase);
  procedure Clear;
  function FindUniqueID (const msgID : string) : TArticleBase; override;
  procedure LoadArticles; override;
  procedure RawDeleteArticle (cno : Integer); override;
  procedure RawRemoveArticle (article : TArticleBase); override;
  procedure RawAddArticle (article : TarticleBase); override;
  procedure RawSortArticles; override;
  procedure RemoveDeletedMessages;
  procedure Reindex;
  function SequentialReadArticle : TFolderArticle;      // Only used for 'export'
  function IndexOf (article : TArticleBase) : Integer; override;

  property FileName : string read GetFileName;
  property IndexFileName : string read GetIndexFileName;
  property SecIndexFileName : string read GetSecIndexFileName;
  property IsEmpty : boolean read GetIsEmpty;
end;

//----------------------------------------------------------------------------
// An article in a TArticleFolder
TFolderArticle = class (TArticleBase)
private
  fOrigGroup: string;
  fOrigServer: string;
  fIDX : Integer;
  fOffset : Integer;
  fExtraHeaders : TStrings;
  fSeenMessage : boolean;
  function PrimaryKey : string; virtual;
protected
  function GetIndex : Integer; override;
  function GetMsg: TmvMessage; override;
  procedure SetIsDeleted(const Value: boolean); override;
  function GetUniqueID: string; override;
  function GetCodePage : Integer; override;
  procedure SetCodePage (const cp : Integer); override;
  function PeekAtMsgHdr(const hdr: string): string; override;
  function GetIsRead: boolean; override;
public
  destructor Destroy; override;
  function MsgValid : boolean;
  property OrigServer : string read fOrigServer;
  property OrigGroup : string read fOrigGroup;
end;

TSentMessage = class (TFolderArticle)
private
  function PrimaryKey : string; override;
public
  constructor CreateInit (AOwner : TArticleFolder; ArticleNo : Integer; AHdr : TStrings; const AMsg : string; ACodePage : Integer; Attachments : TObjectList);
end;

//----------------------------------------------------------------------
// Cache active TArticleFolders.  At the moment the cache size is set to
// two - so the indexes, etc. for two folders can be open at one time.
//
// This keeps resources to a minimum, but still allows eg. copying from one
// folder to another - where you need two folders to be open.
  TActiveFolderCache = class(TObjectCache)
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
    function CanRemove(AObject: TObject): Boolean; override;
  end;

//----------------------------------------------------------------------
// Container for the article folders.
//
// The first folder is always the 'Posted Messages' folder.  The last folder
// is always the 'Purged Messages' folder.
TArticleFolders = class (TObjectList)
private
  fActiveFolderCache : TActiveFolderCache;
  fBinFolder : string;
  fLastServerName : string;
  fLastGroupName : string;
  fLastXanaRef : Integer;
  fXanaRef : TStringList;
  function GetFolder (idx : Integer) : TArticleFolder;
  function GetXNRef (const serverName, groupName : string) : Integer;
  procedure SortFolders;
  function UniqueFolderName : string;
public
  constructor Create;
  destructor Destroy; override;
  procedure AddNew;
  function FindFolder (const name : string) : TArticleFolder;
  procedure DeleteFolder (fldr : TArticleFolder);
  procedure Tidy;

  property Folder [idx : Integer] : TArticleFolder read GetFolder;
end;

TPurgedMessages = class (TArticleFolder)
end;

TSentMessages = class (TArticleFolder)
private
  procedure AddSentArticle (article : TSentMessage; const body : string);
public
  procedure AddMessage (Account : TNNTPAccount; header : TStrings; const msg : string; attachments : TObjectList; codepage : Integer; ATextPartStyle : TTextPartStyle);
end;

var
  gArticleFolders : TArticleFolders;

procedure InitializeFolders (rootReg : TExSettings);

implementation

uses unitStreamTextReader, unitSearchString, unitMailServices, idGlobal,
  unitCharsetMap, IdGlobalProtocols;

(*----------------------------------------------------------------------*
 | procedure InitializeFolders                                          |
 |                                                                      |
 | Called from TNNTPAccounts.Create.  Create and initialize the global  |
 | gArticleFolders, but not until the settings for (eg.) which folder   |
 | is the Purged Messages folder have been loaded.                      |
 *----------------------------------------------------------------------*)
procedure InitializeFolders  (rootReg : TExSettings);
var
  f : TSearchRec;
begin
  gArticleFolders.fBinFolder := rstPurgedMessages;

  with rootReg do        // Get the Purged Messages folder
  try
    if HasSection ('Archive') then
    begin
      Section := 'Archive';
      gArticleFolders.fBinFolder := GetStringValue ('Purged Messages Folder', gArticleFolders.fBinFolder)
    end
  finally
    Section := ''
  end;

  ForceDirectories (gMessageBaseRoot + '\Archive\' + gArticleFolders.fBinFolder);
  gArticleFolders.Add(TPurgedMessages.Create(gArticleFolders.fBinFolder));

  ForceDirectories (gMessageBaseRoot + '\Archive\' + 'Posted Messages');
  gArticleFolders.Add(TSentMessages.Create('Posted Messages'));

                // load the folders
  if FindFirst (gMessageBaseRoot + '\Archive\*.*', faDirectory, f) = 0 then
  try
    repeat
      if ((f.Attr and faDirectory) <> 0) and  (f.Name [1] <> '.') and (f.Name <> gArticleFolders.fBinFolder) and (f.Name <> 'Posted Messages') then
        gArticleFolders.Add(TArticleFolder.Create(f.Name))
    until FindNext (f) <> 0
  finally
    FindClose (f)
  end;

  gArticleFolders.SortFolders;
end;

(*----------------------------------------------------------------------*
 | function CompareFolders                                              |
 |                                                                      |
 | Compare two folders.  Used by TArticleFolders.SortFolders            |
 *----------------------------------------------------------------------*)
function CompareFolders (p1, p2 : pointer) : Integer;
var
  f1, f2 : TArticleFolder;
begin
  f1 := TArticleFolder (p1);
  f2 := TArticleFolder (p2);

  if f1 is TPurgedMessages then         // Ensure the rubbish bin is at the end
    result := 1
  else
    if f2 is TPurgedMessages then
      result := -1
    else
      if f1 is TSentMessages then      // Sent messages at the beginning
        result := -1
      else
        if f2 is TSentMessages then
          result := 1
        else
          result := CompareText (f1.Name, f2.Name)
end;

(*----------------------------------------------------------------------*
 | function DateToByteStr (dt : TDateTime)                              |
 |                                                                      |
 | Convert a TDateTime into an 8 byte string that sorts correctly       |
 *----------------------------------------------------------------------*)
function DateToByteStr (dt : TDateTime) : string;
var
  st : string;
  i : Integer;
begin
  SetLength (st, sizeof (dt));
  Move (dt, st [1], sizeof (dt));
  SetLength (result, Length (st));
  for i := 1 to Length (st) do
    result [9 - i] := st [i]
end;

(*----------------------------------------------------------------------*
 | function SecondaryKey                                                |
 |                                                                      |
 | Return the secondary key for an article.                             |
 *----------------------------------------------------------------------*)
function SecondaryKey (art : TArticleBase; so : TThreadSortOrder): string;
var
  fn : string;
begin
  case so of
    soDate      : result := DateToByteStr (art.Date);
    soLines     : result := Format ('%8.8d', [art.Lines]);
    soSubject   : result := art.Subject;
    soAuthor    : DecodeFromEMail (art.From, result, fn, art.fCodePage);
  end;

  if so <> soDate then
    result := result + DateToByteStr (art.Date);
end;

function GetNextSentArticleNo : Integer;
var
  reg : TExSettings;
begin
  reg := CreateExSettings;
  try
    result := reg.GetIntegerValue('Last Sent Article No', -1) + 1;
    reg.SetIntegerValue('Last Sent Article No', result, -1)
  finally
    reg.Free
  end
end;

{ TArticleFolder }

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.Activate                                    |
 |                                                                      |
 | Activate a folder.  Open the file and the index(es).  Recreate the   |
 | primary index if it's missing.                                       |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.Activate;
var
  indexExists : boolean;
  st: string;
  ae : Integer;
begin
  if Assigned (fFileStream) then        // Alrady active?
    Exit;

  fSequentialPos := 0;
  fSequentialIdx := 0;
  if fNewFile then
    DeleteFile (FileName);

                                        // Create the cache
  fFolderArticleCache := TFolderArticleCache.Create(21, True);

                                        // File already exists?
  if FileExists (FileName) then
  begin
    fFileStream := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyWrite);

    if not fNoIndex then
    begin
      indexExists := FileExists (IndexFileName);

      if not indexExists then           // Reindex the folder if the primary index is
        ReCreateIndex (soMessageNo)     // missing
      else
        fIndex := TBTree.Create(IndexFileName);

      if FileExists (SecIndexFileName) then
      begin
                                        // Open the secondary index and get the
                                        // field it applies to
        fSecondaryIndex := TBTree.Create (SecIndexFilename);
        st := fSecondaryIndex.ExtraData;

        ae := StrToIntDef (st, -1);

        if (ae < 0) or (ae >= Ord (High (TThreadSortOrder))) then
        begin
                                        // Invalid 'extra data'.  Can't determine
          FreeAndNil (fSecondaryIndex); // which field the index applies to - delete
          DeleteFile (SecIndexFilename);// the index.
          ae := Ord (soMessageNo);
        end;

        fThreadSortOrder := TThreadSortOrder (ae);
        fCurrentThreadSortOrder := fThreadSortOrder
      end
    end
  end
  else
  begin               // New folder.  Create empty index.
    fFileStream := TFileStream.Create(FileName, fmCreate);
    if not fNoIndex then
      fIndex := TBTree.Create(IndexFileName)
  end;

  fFileName := FileName;
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.AddArticle ()                               |
 |                                                                      |
 | Add an article to a folder.  The article can be a news article, a    |
 | mail message, or an article from another folder.                     |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.AddArticle(article: TArticleBase);
var
  header : TStrings;
  s : string;
  p, artNo : Integer;
  xnref, origRef, ref : string;
  serverName, groupName, fixedBody : string;
  ok : boolean;
begin
  if Assigned (article.Msg) then
  begin
    LoadArticles;
    header := TStringList.Create;
    try
      header.Add('Message-ID:' + article.MessageId);
      header.Add('Subject:' + article.Subject);
      header.Add('From:' + article.From);
      header.Add('Date:' + SafeDateTimeToInternetStr (article.Date, True));
      header.Add('Lines:' + IntToStr (article.Lines));
      if article.References <> '' then
        header.Add('References:' + article.References);

      header.AddStrings(article.Msg.Header);

      origRef := article.Header ['XRef'];

      if article is TFolderArticle then
      begin
        serverName := TFolderArticle (article).OrigServer;
        groupName := TFolderArticle (article).OrigGroup
      end
      else
      begin
        serverName := article.Owner.ServerSettings.ServerName;
        if article.Owner.ServerSettings.ServerPort <> 119 then
          serverName := serverName + '(' + IntToStr (article.Owner.ServerSettings.ServerPort) + ')';
        groupName := article.Owner.Name
      end;

      artNo := article.ArticleNo;

      ref := serverName + ' ' + groupName + ':' + IntToStr (artNo);

      if origRef <> ref then            // We need to reliably save the server &
      begin                             // group name in an X-Ref header.  Sometimes
                                        // the existing XRef header is OK - sometime's it's not.
        header.NameValueSeparator := ':';
        header.Values ['X-Ref'] := ref
      end;

      fFileStream.Seek(0, soFromEnd);   // Position in text file to write to
      p := fFileStream.Position;

      if not fNoIndex then
      begin
                                        // Index on the server/group index & article no.
        xnref := IntToHex (gArticleFolders.GetXNRef (serverName, groupName), 4) + ':' + IntToHex (artNo, 8);
        ok := fIndex.AddKey (xnref, p);
        if Assigned (fSecondaryIndex) then
        begin
          xnref := SecondaryKey (article, ThreadSortOrder);
          fSecondaryIndex.AddKey(xnref, p)
        end

      end
      else
        ok := True;

      if ok then                        // Successfully wrote the index - now write the data.
      begin
        s := header.Text + #13#10;
        fFileStream.Write(PChar (s)^, Length (s));

        SetString (fixedBody, PChar (article.Msg.RawData.Memory), article.Msg.RawData.Size);
        fixedBody := StringReplace (fixedBody, #13#10'.'#13#10, #13#10'..'#13#10, [rfReplaceAll]);
        fFileStream.Write(fixedBody [1], article.Msg.RawData.Size);
        s := #13#10'.'#13#10;
        fFileStream.Write(PChar (s)^, Length (s));

        if fArticleCount > -1 then
          Inc (fArticleCount)
      end;
    finally
      header.Free
    end
  end
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.BeginAdd                                    |
 |                                                                      |
 | Speed up the Add operation by putting the index in Update mode       |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.BeginAdd;
begin
  LoadArticles;
  if not fNoIndex then
  begin
    fIndex.BeginUpdate;
    if Assigned (fSecondaryIndex) then
      fSecondaryIndex.BeginUpdate
  end
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.Clear                                       |
 |                                                                      |
 | Clear all articles from a folder.                                    |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.Clear;
begin
  if Assigned(fFolderArticleCache) then         // Get rid of any cached articled
    fFolderArticleCache.Clear;
  fDeletedArticles.Clear;                       // Get rid of any deleted articles

       // Deactivate the folder if it's active by forcing it out of the cache
  gArticleFolders.fActiveFolderCache.Remove(Self);
  fArticleCount := -1;
  DeleteFile(SecIndexfileName);
  DeleteFile(IndexFileName);                    // Delete the files.
  DeleteFile(FileName);
end;

(*----------------------------------------------------------------------*
 | constructor TArticleFolder.Create                                    |
 |                                                                      |
 | Create the TArticleFolder                                            |
 *----------------------------------------------------------------------*)
constructor TArticleFolder.Create(const AName: String);
begin
  inherited Create (AName, Nil, Nil);
  fArticleCount := -1;
  fDeletedArticles := TStringList.Create;       // Maintain a list of which
                                                // articles have been deleted
  fThreadSortOrder := soMessageNo;
  fCurrentThreadSortOrder := soMessageNo;
  fThreadOrder := toChronological;
  fCurrentThreadOrder := toChronological;
end;

(*----------------------------------------------------------------------*
 | constructor TArticleFolder.CreateFile                                |
 |                                                                      |
 |                                                                      |
 |                                                                      |
 | Parameters:                                                          |
 |   const AFileName: String; ANewFile, ANoIndex: boolean               |
 |                                                                      |
 | The function returns None                                            |
 *----------------------------------------------------------------------*)
constructor TArticleFolder.CreateFile(const AFileName: String; ANewFile,
  ANoIndex: boolean);
begin
  Create (AFileName);

  fFileName := AFileName;

  fNoIndex := ANoIndex;
  fNewFile := ANewFile;
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.Deactivate                                  |
 |                                                                      |
 | Deactivate a folder.  This happens when it's removed from the Active |
 | Folder Cache                                                         |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.Deactivate;
begin
  MessageCacheController.Clear;
  FreeAndNil(fFolderArticleCache);     // Remove it's cached articles
  FreeAndNil(fIndex);                  // Unload the primary key
  FreeAndNil(fFileStream);             // Release the file
  FreeAndNil(fSecondaryIndex);         // Unload the secondary key

  // nb.  Don't clear the 'Deleted Articles' list.
end;

(*----------------------------------------------------------------------*
 | destructor TArticleFolder.Destroy                                    |
 *----------------------------------------------------------------------*)
destructor TArticleFolder.Destroy;
begin
        // The folder may or may not be active.  If it *is*, deactivate it by
        // forcing it out of the cache.
  if Assigned(gArticleFolders) then
    gArticleFolders.fActiveFolderCache.Remove(Self);
  fDeletedArticles.Free;
  inherited Destroy;
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.EndAdd                                      |
 |                                                                      |
 | End bulk addtion started by BeginAdd                                 |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.EndAdd;
begin
  if Assigned (fIndex) then
    fIndex.EndUpdate;
  if Assigned (fSecondaryIndex) then
    fSecondaryIndex.EndUpdate
end;

(*----------------------------------------------------------------------*
 | TArticleFolder.FindUniqueID
 |                                                                      |
 |
 |                                                                      |
 | Parameters:                                                          |
 |   const msgID: string
 |                                                                      |
 | The function returns TArticleBase
 *----------------------------------------------------------------------*)
function TArticleFolder.FindUniqueID(const msgID: string): TArticleBase;
var
  idx, dr : Integer;
  xnr : string;
  t : TBTree;
  sd : TThreadSortDirection;

begin
  xnr := msgID;
  LoadArticles;
  idx := fIndex.GetIndexOfKey (xnr, dr);
  if idx >= 0 then
  begin
    t := Nil;
    sd := fThreadSortDirection;
    if Assigned (fSecondaryIndex) then
    begin
      fFolderArticleCache.Clear;
      t := fSecondaryIndex;
      fSecondaryIndex := Nil;
      fThreadSortDirection := sdAscending;
    end;
    result := ArticleBase [idx];
    fSecondaryIndex := t;

    if t <> Nil then
    begin
      xnr := SecondaryKey (result, ThreadSortOrder);
      TFolderArticle (result).fIDX := t.GetIndexOfKey(xnr, dr);
      if sd = sdDescending then
        TFolderArticle (result).fIDX := ArticleCount - TFolderArticle (result).fIdx - 1;
      fThreadSortDirection := sd;
    end
  end
  else
    result := Nil
end;

procedure TArticleFolder.FixDots;
var
  f : TTextFileReader;
  fw : TTextFileWriter;
  st : string;
begin
  Deactivate;

  fw := Nil;
  f := TTextFileReader.Create(FileName);
  try
    fw := TTextFileWriter.Create(GetTempFileName);
    while f.ReadLn (st) do
    begin
      if st = '.' then
      begin
        if f.ReadLn (st) then
        begin
          if SameText (Copy (st, 1, 11), 'Message-Id:') then
            fw.WriteLn('.')
          else
            fw.WriteLn('..');

          fw.WriteLn(st);
        end
        else
          fw.WriteLn('.')
      end
      else
        fw.WriteLn(st)
    end;

    FreeAndNil (fw);
    FreeAndNil (f);

    DeleteFile (FileName);
    RenameFile (GetTempFileName, FileName);




  finally
    f.Free;
    fw.Free;

  end;

end;

(*----------------------------------------------------------------------*
 | function TArticleFolder.GetArticleBase                               |
 |                                                                      |
 | Load an article, by index.  Note that the index relates to the       |
 | secondary key if it exists - otherwise it release to the primary     |
 | key.                                                                 |
 *----------------------------------------------------------------------*)
function TArticleFolder.GetArticleBase(idx: Integer): TArticleBase;
var
  res : TFolderArticle;
  pos : Integer;
  key : string;
begin
  LoadArticles;

  if ThreadSortDirection = sdDescending then
    idx := ArticleCount - (idx + 1);

                        // Check the cache first.
  res := fFolderArticleCache.FindArticle(idx);

  if (res = nil) and (idx < ArticleCount) then
  begin
    if Assigned (fSecondaryIndex) then

    begin               // Look in secondary index.

      fSecondaryIndex.GetKey(idx, pos);
      res := RawLoadArticleHeader (idx, pos);

      if res = Nil then
        MEssageBeep ($ffff);

      key := res.PrimaryKey;    // Get primary key so we can
                                // check if it's been deleted.
    end
    else
    begin
      key := fIndex.GetKey(idx, pos);
      res := RawLoadArticleHeader (idx, pos)
    end;
                        // Add the article to the cache.
    if Assigned (res) then
    begin
      if fDeletedArticles.IndexOf(key) >= 0 then
        res.fFlags := res.fFlags or fgDeleted;
      fFolderArticleCache.Add(res);
    end;
  end;

  result := res
end;

(*----------------------------------------------------------------------*
 | function TArticleFolder.GetLoaded                                    |
 |                                                                      |
 | We always loaded - even when we're not!                              |
 *----------------------------------------------------------------------*)
function TArticleFolder.GetLoaded: boolean;
begin
  result := True;
end;


(*----------------------------------------------------------------------*
 | function TArticleFolder.GetNext                                      |
 |                                                                      |
 | Return the next article folder sibling.                              |
 *----------------------------------------------------------------------*)
function TArticleFolder.GetNext: TArticleContainer;
var
  idx : Integer;
begin
  result := Nil;
  idx := gArticleFolders.IndexOf(self);
  if idx = -1 then Exit;

  if idx + 1 < gArticleFolders.Count then
    result := gArticleFolders.Folder [idx + 1]
end;


(*----------------------------------------------------------------------*
 | function TArticleFolder.GetSecIndexFileName                          |
 |                                                                      |
 | Get the secondary index file name                                    |
 *----------------------------------------------------------------------*)
function TArticleFolder.GetSecIndexFileName: string;
begin
  result := gMessageBaseRoot + '\Archive\' + Name + '\Sort Articles.IDX'
end;

(*----------------------------------------------------------------------*
 | function TArticleFolder.GetUnreadArticleCount                        |
 |                                                                      |
 | Messages in these folders are always considered to be 'read'         |
 *----------------------------------------------------------------------*)
function TArticleFolder.GetUnreadArticleCount: Integer;
begin
  result := 0;
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.LoadArticles                                |
 |                                                                      |
 | Load the articles.  When the folder is added to the fromt of the     |
 | Active Folder cache, the articles get loaded                         |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.LoadArticles;
begin
  if (gArticleFolders.fActiveFolderCache.Count = 0) or (gArticleFolders.fActiveFolderCache[0] <> self) then
    gArticleFolders.fActiveFolderCache.Add(Self);
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.RawAddArticle                               |
 |                                                                      |
 | Stub                                                                 |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.RawAddArticle(article: TarticleBase);
begin
// Stub
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.RawDeleteArticle                            |
 |                                                                      |
 | Stub                                                                 |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.RawDeleteArticle(cno: Integer);
begin
// Stub
end;

(*----------------------------------------------------------------------*
 | function TArticleFolder.RawLoadArticleHeader                         |
 |                                                                      |
 | Create a new FolderArticle with Index = 'idx', and load it's headers |
 | starting at position 'pos' in the data file.                         |
 |                                                                      |
 | On exit, 'Pos' contains the position in the datafile of the message  |
 | body.                                                                |
 *----------------------------------------------------------------------*)
function TArticleFolder.RawLoadArticleHeader(idx: Integer;
  var pos: Integer): TFolderArticle;
var
  reader : TStreamTextReader;
  s : TStringList;
  st : string;
begin
  if pos >= fFileStream.Size then
  begin
    result := Nil;
    exit
  end;

  if self is TSentMessages then
    result := TSentMessage.Create(self)
  else
    result := TFolderArticle.Create (self);
  try
    result.fIDX := idx;                 // Remember the index passed in.

    reader := TStreamTextReader.Create(fFileStream);
    try
      result.fOffset := pos;
      s := TStringList.Create;
      s.NameValueSeparator := ':';
      reader.Position := pos;           // Go to position in the data file


                                        // Read the header lines into 's'
      while reader.ReadLn(st) and (st <> '') do
        s.Add(st);

      if st = '' then
      begin
        result.fMessageOffset := reader.Position;
                                        // Initialize the TFolderArticle.  This
                                        // removes the XOVER headers from 's',
                                        // leaving the extra headers.
        result.Initialize(idx, s);
        result.fExtraHeaders := s;

                                        // Get the server, group & article no from
                                        // the XRef or X-Ref header.
        st := Trim (s.Values ['X-Ref']);
        if st = '' then
          st := Trim (s.Values ['XRef']);

        if st <> '' then
        begin
          result.fOrigServer := SplitString (' ', st);
          result.fOrigGroup := SplitString (':', st);
          result.fArticleNo := StrToIntDef (st, 0)
        end
      end
      else
        raise Exception.Create ('Corrupt article in archive');
    finally
      pos := reader.Search(#13#10'.'#13#10);
      pos := Reader.Position;
      Reader.Free
    end
  except
    FreeAndNil (result)
  end
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.RawRemoveArticle                            |
 |                                                                      |
 | Stub                                                                 |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.RawRemoveArticle(article: TArticleBase);
begin
// Stub
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.ReCreateIndex                               |
 |                                                                      |
 | Recreate the primary or secondary index.                             |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.ReCreateIndex (sortOrder : TThreadSortOrder);
var
  lpc, articleStart, pc, ae, xr : Integer;
  reader : TStreamTextReader;
  idx : TBTree;
  fn, key, st, fld, server, group : string;
  deleted, isMailAccount : boolean;
  date : TDateTime;

// Return the specified header field.
  function FindHeaderField (const field : string; var deleted, mail : boolean; var date : TDateTime) : string;
  var
    st, st1, dtst : string;
    l1 : boolean;
    gotDate, gotResult : boolean;
  begin
    deleted := False;
    mail := False;
    l1 := True;
    gotDate := False;
    gotResult := False;
    repeat                    // Get each header line until we find XRef
      if not reader.ReadLn(st) then
        break;

      if st = '' then
        break;

      if l1 then // 1st line of header.  The article has been deleted
      begin      // from the folder if the first char is lower case.
        deleted := st [1] = LowerCase (st [1]);
        l1 := False
      end;

      st1 := SplitString (':', st);

      if SameText (st1, field) then
      begin
        result := st;
        if SameText (field, 'Date') then
        begin
          gotDate := True;
          dtst := st
        end;
        if not SameText (field, 'xref') then
          gotResult := True;
      end
      else
        if SameText (field, 'xref') and (SameText (st1, 'x-ref') or SameText (st1, 'x-uidl')) then
        begin
          if sameText (st1, 'x-uidl') then
            mail := True;
          result := st;
          gotResult := True;
          break
        end
        else
          if SameText (st1, 'date') then
          begin
            dtst := st;
            gotDate := True
          end
    until gotDate and gotResult;

    if gotDate then                  
      date := GMTToLocalDateTime (dtst);

    if not gotResult then
      result := ''
    else
      result := Trim (result)
  end;

begin  // ReCreateIndex
  fIndexing := True;
  gAppTerminating := True;
  try
    lpc := -1;
    reader := Nil;

    if sortOrder = soMessageNo then
    begin
      idx := fIndex;
      fn := IndexFileName
    end
    else
    begin
      idx := fSecondaryIndex;
      fn := SecIndexFileName
    end;

    idx.Free;
    DeleteFile (fn);
    idx := TBTree.Create (fn);
    if sortOrder <> soMessageNo then
      idx.Duplicates := dupAccept;

    idx.BeginUpdate;
    try
      case SortOrder of
        soDate      : fld := 'Date';
        soSubject   : fld := 'Subject';
        soAuthor    : fld := 'From';
        soLines     : fld := 'Lines';
        soMessageNo : fld := 'XRef';
        soPostingHost : fld := 'NNTP-Posting-host'
      end;

      if fld = '' then Exit;

      fFileStream.Position := 0;
      reader := TStreamTextReader.Create(fFileStream, 4100);

      articleStart := 0;
      if reader.Stream.Size <> 0 then
      repeat
        pc := (reader.Stream.Position * 100) div reader.Stream.Size;
        if pc <> lpc then
        begin
          SetTempStatusMessage ('Indexing folder ' + Name, pc, 100);
          lpc := pc;
        end;


        st := FindHeaderField (fld, deleted, isMailAccount, date);

                                          // Find the end of article #13#10.#13#10
                                          // sequence

        ae := reader.Search(#13#10'.'#13#10);
        if (ae <> -1) and not deleted then
        begin
          case sortOrder of
            soMessageNo:
              begin
                if isMailAccount then
                  key := st
                else
                begin
                  key := '';
                  server := SplitString (' ', st);
                  isMailAccount := MailAccounts.FindMailAccountServer(server) <> Nil;
                  group := SplitString (':', st);
                  xr := StrToIntDef (st, -1);
                  if isMailAccount or (xr <> -1) then
                  begin
                    if isMailAccount then
                      key := IntToHex (idx.RecordCount + 1, 8)
                    else
                      key := IntToHex (xr, 8);
                    key := IntToHex (gArticleFolders.GetXNRef (server, group), 4) + ':' + key
                  end
                end
              end;
            soDate  : key := DateToByteStr (date);
            soLines :
              begin
                key := st;
                while length (key) < 8 do
                  key := '0' + key;
                key := key + DateToByteStr (date);
              end;
            soAuthor :
              begin
                DecodeFromEMail (st, key, fn);
                key := key + DateToByteStr (date)
              end
            else
              key := st + DateToByteStr (date)
          end;
          if key <> '' then
            idx.AddKey (key, articleStart)
        end;
        articleStart := ae + 5;
      until ae = -1;
    finally
      idx.EndUpdate;
      if sortOrder = soMessageNo then
        fIndex := idx
      else
      begin
        fSecondaryIndex := idx;
        fSecondaryIndex.ExtraData := IntToStr (Ord (fThreadSortOrder))
      end;
      reader.Free;
      SetTempStatusMessage ('', 0, 0);
    end
  finally
    fIndexing := False;
    gAppTerminating := False;
  end
end;

(*----------------------------------------------------------------------*
 | procedure TArticleFolder.Reindex                                     |
 |                                                                      |
 | nb.  Don't do any work here - simply prepare, so that next time the  |
 | folder is reactivated it is reindexed.                               |
 *----------------------------------------------------------------------*)
procedure TArticleFolder.Reindex;
begin
  if Assigned(fFolderArticleCache) then
    fFolderArticleCache.Clear;
  fDeletedArticles.Clear;
  gArticleFolders.fActiveFolderCache.Remove(Self);
  fArticleCount := -1;
  FixDots;
  DeleteFile(IndexFileName);
end;

procedure TArticleFolder.RawSortArticles;
begin
  if fCurrentThreadSortOrder <> fThreadSortOrder then
  begin
    if Assigned(fFolderArticleCache) then
      fFolderArticleCache.Clear;
    if fThreadSortOrder = soMessageNo then
    begin
      FreeAndNil (fSecondaryIndex);
      DeleteFile (SecIndexFileName);
    end
    else
      ReCreateIndex (fThreadSortOrder);
    fCurrentThreadSortOrder := fThreadSortOrder;
    fArticleCount := -1;
  end
  else
    if fCurrentThreadSortDirection <> fThreadSortDirection then
      fFolderArticleCache.Clear;
end;

procedure TArticleFolder.SortArticles;
begin
  RawSortArticles;

end;

{ TArticleFolders }

procedure TArticleFolders.AddNew;
var
  folder : TArticleFolder;
begin
  folder := TArticleFolder.Create (UniqueFolderName);
  if ForceDirectories (gMessageBaseRoot + '\Archive\' + folder.Name) then
  begin
    Add(folder);
    SortFolders
  end
  else
    folder.Free;
end;

constructor TArticleFolders.Create;
begin
  inherited Create;

  fActiveFolderCache := TActiveFolderCache.Create(2, False);
end;

procedure TArticleFolders.DeleteFolder(fldr: TArticleFolder);
var
  idx : Integer;
  name : string;
begin
  fldr.Clear;
  idx := IndexOf (fldr);
  if idx >= 0 then
  begin
    name := fldr.Name;
    Delete(idx);
    PurgeDirectory (gMessageBaseRoot + '\Archive\' + name)
  end
end;

destructor TArticleFolders.Destroy;
begin
  fActiveFolderCache.Free;
  fXanaRef.Free;
  inherited;
end;

function TArticleFolders.FindFolder(const name: string): TArticleFolder;
// if name is blank, return 'bin' folder
var
  i : Integer;
  nm : string;
begin
  result := Nil;
  if name = '' then
    nm := fBinFolder
  else
    nm := name;
  for i := 0 to Count - 1 do
    if CompareText (Folder [i].Name, nm) = 0 then
    begin
      result := Folder [i];
      break
    end
end;

function TArticleFolders.GetFolder (idx : Integer) : TArticleFolder;
begin
  result := TArticleFolder (items [idx])

end;

function TArticleFolders.GetXNRef(const serverName,
  groupName: string): Integer;
var
  ref : string;
  i, n, highest : Integer;
begin
  if (serverName = fLastServerName) and (groupName = fLastGroupName) then
  begin
    result := fLastXanaRef;
    Exit
  end;

  if not Assigned (fXanaref) then
  begin
    fXanaRef := TStringList.Create;
    fXanaRef.CaseSensitive := False;

    if FileExists (gMessageBaseRoot + '\Archive\XanaRef.txt') then
      fXanaRef.LoadFromFile(gMessageBaseRoot + '\Archive\XanaRef.txt');
    fXanaRef.Sorted := True
  end;

  ref := fXanaRef.Values [serverName + ':' + groupName];

  if ref = '' then
  begin
    highest := -1;
    for i := 0 to fXanaRef.Count - 1 do
    begin
      ref := fXanaRef [i];
      SplitString ('=', ref);
      n := StrToInt (ref);
      if n > highest then
        highest := n
    end;

    result := highest + 1;
    fXanaRef.Add(serverName + ':' + groupName + '=' + IntToStr (result));
    fXanaRef.SaveToFile(gMessageBaseRoot + '\Archive\XanaRef.txt');
  end
  else
    result := StrToInt (ref);

  fLastServerName := serverName;
  fLastGroupName := groupName;
  fLastXanaRef := result
end;

procedure TArticleFolders.SortFolders;
begin
  if Count > 1 then
    Sort(CompareFolders);
end;

procedure TArticleFolders.Tidy;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Folder[I].RemoveDeletedMessages;
  fActiveFolderCache.Clear;
end;

function TArticleFolder.GetArticleCount: Integer;
begin
  if fIndexing then
  begin
    result := 0;
    exit
  end;
  if fArticleCount = -1 then
  begin
    LoadArticles;
    if Assigned (fSecondaryIndex) then
    begin
      fArticleCount := fSecondaryIndex.RecordCount;
      if fArticleCount > fIndex.RecordCount then
        fArticleCount := fIndex.RecordCount
    end
    else
      fArticleCount := fIndex.RecordCount
  end;
  result := fArticleCount;
end;

function TArticleFolder.GetFileName: string;
begin
  if fFileName = '' then
    result := gMessageBaseRoot + '\Archive\' + Name + '\Saved Articles.TXT'
  else
    result := fFileName;
end;

function TArticleFolder.GetIndexFileName: string;
begin
  result := gMessageBaseRoot + '\Archive\' + Name + '\Saved Articles.IDX'
end;

function TArticleFolder.GetIsEmpty: boolean;
begin
  result := ArticleCount = 0;
end;

function TArticleFolder.GetServerSettings: TServerSettings;
begin
  result := Nil
end;

function TArticleFolder.GetTempFileName: string;
begin
  result := gMessageBaseRoot + '\Archive\' + Name + '\Saved Articles.tmp'
end;

procedure TArticleFolder.RemoveDeletedMessages;
var
  pos : Integer;
  key : string;
  ch : char;
begin
  LoadArticles;
  fFolderArticleCache.Clear;
  fNeedsPurge := False;
  if fDeletedArticles.Count = 0 then
    Exit;

  if fDeletedArticles.Count = ArticleCount then
    Clear
  else
  begin
    while fDeletedArticles.Count > 0 do
    begin
      key := fDeletedArticles [0];
      fDeletedArticles.Delete(0);
      if fIndex.Find(key, pos) and fIndex.DeleteKey (Key) then
      begin
        fFileStream.Position := pos;
        fFileStream.Read(ch, sizeof (ch));
        ch := LowerCase (ch) [1];
        fFileStream.Position := pos;
        fFileStream.Write (ch, sizeof (ch));
        Dec (fArticleCount);
      end
    end;
    gArticleFolders.fActiveFolderCache.Remove(Self);
    fArticleCount := -1;
    Deactivate;
    DeleteFile(SecIndexFileName);
  end
end;

function TArticleFolder.SequentialReadArticle: TFolderArticle;
begin
  LoadArticles;
  Result := RawLoadArticleHeader(fSequentialIdx, fSequentialPos);
  if Assigned(Result) then
  begin
    fFolderArticleCache.Add(Result);
    Inc(fSequentialIdx);
  end
end;

function TArticleFolders.UniqueFolderName: string;
var
  i, n : Integer;
  fn : string;
  used : boolean;
begin
           // Folder name incorporates the date, but make sure there are no
           // slashes - they're illegal in file names.
  fn := StringReplace (Format (rstDefaultFolderName, [DateToStr (now)]), '/', '-', [rfReplaceAll]);

  n := 0;
  repeat
    if n = 0 then
      result := fn
    else
      result := Format ('%s (%d)', [fn, n]);

    used := False;
    for i := 0 to Count - 1 do
      if CompareText (Folder [i].Name, result) = 0 then
      begin
        used := True;
        break
      end;
    Inc (n)
  until not used;
end;

{ TActiveFolderCache }

function TActiveFolderCache.CanRemove(AObject: TObject): boolean;
begin
  Result := not TArticleFolder(AObject).fIndexing;
end;

procedure TActiveFolderCache.Notify(Ptr: Pointer; Action: TListNotification);
begin
  if not ReOrdering and (TObject(Ptr) is TArticleFolder) then
    case Action of
      lnAdded: TArticleFolder(Ptr).Activate;
      lnDeleted: TArticleFolder(Ptr).Deactivate;
    end;
  inherited Notify(Ptr, Action);
end;

{ TFolderArticle }

destructor TFolderArticle.Destroy;
begin
  MessageCacheController.AlwaysRemove := True;
  try
    MessageCacheController.Remove(Self);
  finally
    MessageCacheController.AlwaysRemove := False
  end;
  fExtraHeaders.Free;
  FreeAndNil(fMsg);
  inherited Destroy;
end;

function TFolderArticle.GetCodePage: Integer;
begin
  if fSeenMessage then
    result := fCodePage
  else
    result := Msg.Codepage
end;

function TFolderArticle.GetIndex: Integer;
begin
  result := fIdx;
end;

function TFolderArticle.GetIsRead: boolean;
begin
  result := True;
end;

function TFolderArticle.GetMsg: TmvMessage;
var
  reader : TStreamTextReader;
  st : string;
  ap, ae : Integer;
begin
  if not Assigned (fMsg) then
  begin
    reader := TStreamTextReader.Create(TArticleFolder (Owner).fFileStream);
    try
      reader.Position := fMessageOffset;

      fMsg := TmvMessage.Create(self);
      try
        fMsg.Header.AddStrings(fExtraHeaders);

        if st = '' then
        begin
          ap := reader.Position;
          ae := reader.Search(#13#10'.'#13#10);
          if ae > ap then
          begin
            SetLength (st, ae - ap);
            reader.ReadChunk(PChar (st)^, ap, ae - ap);

            st := StringReplace (st, #13#10'..'#13#10, #13#10'.'#13#10, [rfReplaceAll]);

            fMsg.RawData.Write(PChar (st)^, Length (st))
          end
        end
      except
        FreeAndNil (fMsg);
        raise
      end;

      fSeenMessage := True;
      fCodePage := Msg.Codepage;
      MessageCacheController.Add(Self);
    finally
      reader.Free
    end
  end;

  result := fMsg;
end;

function TFolderArticle.GetUniqueID: string;
begin
  Owner.LoadArticles;
  result := PrimaryKey
end;

function TFolderArticle.MsgValid: boolean;
begin
  result := Assigned (fMsg);
end;

function TFolderArticle.PeekAtMsgHdr(const hdr: string): string;
begin
  result := fExtraHeaders.Values [hdr];

end;

function TFolderArticle.PrimaryKey: string;
var
  st : string;
  artNo : Integer;
begin
  result := Header ['X-UIDL'];  // Is it a mail article?
  if result = '' then
  begin
    st := Header ['X-Ref'];
    if st = '' then
      st := Header ['XRef'];

    if st <> '' then
    begin
      SplitString (':', st);
      artNo := StrToIntDef (st, 0);
      result :=IntToHex (gArticleFolders.GetXNRef (OrigServer, OrigGroup), 4) + ':' + IntToHex (artNo, 8)
    end
  end
end;

procedure TFolderArticle.SetCodePage(const cp: Integer);
begin
  if not fSeenMessage then GetMsg;
  fCodePage := cp
end;

procedure TFolderArticle.SetIsDeleted(const Value: boolean);
var
  key : string;
  idx : Integer;
  ownr : TArticleFolder;
begin
  inherited;

  ownr := TArticleFolder (Owner);
  ownr.LoadArticles;
  key := PrimaryKey;
  if key <> '' then
  begin
    if value then
      ownr.fDeletedArticles.Add (key)
    else
    begin
      idx := ownr.fDeletedArticles.IndexOf(key);
      if idx >= 0 then
        ownr.fDeletedArticles.Delete (idx)
    end
  end
end;

{ TFolderArticleCache }

function TFolderArticleCache.CanRemove(Obj: TObject): boolean;
var
  article: TFolderArticle;
begin
  Result := True;

  if Obj is TFolderArticle then
  begin
    article := TFolderArticle(Obj);

    if article.MsgValid then
      if Article.Msg.BeingDisplayed then
        Result := False;
  end;
end;

procedure TFolderArticleCache.CheckArticleProc(obj: TObject; idx,
  param: Integer; var continue: Boolean);
begin
  if TFolderArticle(obj).fIdx = param then
  begin
    fCurrentArticle := TFolderArticle(obj);
    fCurrentIDX := idx;
    continue := False;
  end;
end;

function TFolderArticleCache.FindArticle(idx: Integer): TFolderArticle;
begin
  Result := nil;
  fCurrentIdx := -1;
  ForEach(CheckArticleProc, idx);
  if fCurrentIdx <> -1 then
  begin
    BringToFront(fCurrentIdx);
    Result := fCurrentArticle;
  end;
end;

procedure TArticleFolder.SetName(const Value: string);
begin
  if Assigned(gArticleFolders) then
    gArticleFolders.fActiveFolderCache.Remove(Self);

  if not RenameFile (gMessageBaseRoot + '\Archive\' + Name, gMessageBaseRoot + '\Archive\' + Value) then
    RaiseLastOSError;
  fFileName := '';
  inherited
end;

{ TSentMessages }

procedure TSentMessages.AddMessage(Account: TNNTPAccount;
  header: TStrings; const msg: string; attachments: TObjectList;
  codepage: Integer; ATextPartStyle: TTextPartStyle);
var
  m : TSentMessage;
  serverst, st : string;
  sl : TStrings;
  artNo : Integer;
begin
  serverSt := Account.NNTPServerSettings.ServerName;
  if Account.NNTPServerSettings.ServerPort <> 119 then
    serverSt := serverSt + '(' + IntToStr (Account.NNTPServerSettings.ServerPort) + ')';

  if header.Values ['Message-Id'] = '' then
  begin
    if (Account.NNTPSettings.MessageIDDomain = '') or
       (Account.NNTPSettings.MessageIDDomain = '<Auto>') then
      st := LowerCase (Account.NNTPServerSettings.ServerName)
    else
      st := Account.NNTPSettings.MessageIDDomain;
    header.Add('Message-Id=' + GenerateMessageID ('xn', Account.NNTPSettings.MessageIDStub, st))
  end;

  artNo := GetNextSentArticleNo;
  header.Add('X-Ref=' + serverSt + ' ~XNS:' + IntToHex (artNo, 8));

  m := TSentMessage.CreateInit(self, artNo, header, msg, codepage, attachments);
  try
    m.fOrigServer := serverSt;
    m.fDate := Now;
    sl := TStringList.Create;
    try
      sl.Text := msg;
      m.fLines := sl.Count
    finally
      sl.Free
    end;
    AddSentArticle (m, msg);
  finally
    m.Free
  end
end;

procedure TSentMessages.AddSentArticle(article: TSentMessage; const body : string);
var
  p : Integer;
  ok : boolean;
  xnref, s : string;
  header : TStrings;
  fixedBody : string;
begin
  LoadArticles;
  header := TStringList.Create;
  try
    header.Add('Message-ID:' + article.MessageId);
    header.Add('Subject:' + article.Subject);
    header.Add('From:' + article.From);
    header.Add('Date:' + SafeDateTimeToInternetStr (article.Date, True));
    if article.Lines <> 0 then
      header.Add('Lines:' + IntToStr (article.Lines));
    if article.References <> '' then
      header.Add('References:' + article.References);
    header.AddStrings(article.fExtraHeaders);

    fFileStream.Seek(0, soFromEnd);   // Position in text file to write to
    p := fFileStream.Position;
    xnref := IntToHex (Article.ArticleNo, 8);
    ok := fIndex.AddKey (xnref, p);
    if Assigned (fSecondaryIndex) then
    begin
      xnref := SecondaryKey (article, ThreadSortOrder);
      fSecondaryIndex.AddKey(xnref, p)
    end;

    if ok then                        // Successfully wrote the index - now write the data.
    begin
      s := header.Text + #13#10;
      fFileStream.Write(PChar (s)^, Length (s));

      fixedBody := StringReplace (body, #13#10'.'#13#10, #13#10'..'#13#10, [rfReplaceAll]);

      fFileStream.Write(fixedBody [1], Length (fixedBody));
      s := #13#10'.'#13#10;
      fFileStream.Write(PChar (s)^, Length (s));

      if fArticleCount > -1 then
        Inc (fArticleCount)
    end
  finally
    header.Free
  end
end;

{ TSentMessage }

constructor TSentMessage.CreateInit(AOwner : TArticleFolder; ArticleNo : Integer; AHdr: TStrings; const AMsg: string;
  ACodePage: Integer; Attachments: TObjectList);
var
  hdr : TStrings;
  i : Integer;
begin
  inherited Create (AOwner);

  hdr := TStringList.Create;
  hdr.AddStrings(AHdr);
  for i := 0 to hdr.Count - 1 do
    hdr [i] := StringReplace (hdr [i], '=', ':', []);
  fCodePage := ACodePage;
  Initialize (ArticleNo, hdr);
  fExtraHeaders := hdr;

end;

function TSentMessage.PrimaryKey: string;
begin
  result := IntToHex (ArticleNo, 8);
end;

function TArticleFolder.IndexOf(article: TArticleBase): Integer;
begin
  result := article.Index
end;

function TArticleFolder.GetAdjustedArticleCount: Integer;
begin
  result := ArticleCount;
end;

initialization
finalization
  FreeAndNil (gArticleFolders)
end.
