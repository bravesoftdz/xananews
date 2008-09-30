(*======================================================================*
 | NewsgroupStatisticsForm                                              |
 |                                                                      |
 | Calculate newsgroup Statistics                                       |
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
 | Copyright � Colin Wilson 2003  All Rights Reserved
 |                                                                      |
 | Version  Date        By    Description                               |
 | -------  ----------  ----  ------------------------------------------|
 | 1.0      01/04/2004  CPWW  Original                                  |
 *======================================================================*)

unit NewsgroupStatisticsForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, ComCtrls, StdCtrls, NewsGlobals, ConTnrs, unitNNTPServices,
  unitSettings, unitMessages, cmpPersistentPosition, unitExSettings, PostMessageForm;

type
  TStatistic = class
  private
    fNumber: Integer;
    fRanking: Integer;
    fDataString: string;
    fDataInteger: Integer;
  public
    property Number: Integer read fNumber;
    property Ranking: Integer read fRanking;
    property DataString: string read fDataString;
    property DataInteger: Integer read fDataInteger;
  end;

  TStatistics = class
  private
    fGroup: TArticleContainer;
    fPosters: TStringList;
    fReaders: TStringList;
    fThreads: TStringList;
    fNoUnanswered: Integer;
    fNoXanaNews: Integer;
    fNonDummyArticleCount: Integer;
  public
    constructor Create(AGroup: TArticleContainer; MaxResults: Integer);
    destructor Destroy; override;
    property NonDummyArticleCount: Integer read fNonDummyArticleCount;
  end;

  TStatisticContainer = class(TArticleObjectContainer)
  private
    fMessagebaseSize: Int64;
  protected
    function GetServerSettings: TServerSettings; override;
    function GetNext: TArticleContainer; override;
    function GetUnreadArticleCount: Integer; override;
    function GetMessagebaseSize: Int64; override;
  public
    constructor Create(AGroup: TArticleContainer; startDate, endDate: TDateTime);
    procedure LoadArticles; override;
    procedure SaveArticles(recreateMessageFile: Boolean); override;
  end;

  TStatisticArticle = class(TArticleBase)
  private
    fAgent: string;
  protected
    function GetHeader(const name: string): string; override;
    function GetMsg: TmvMessage; override;
  public
    constructor Create(AOwner: TArticleContainer); override;
    procedure Assign(article: TArticleBase); override;
  end;

  TfmNewsgroupStatistics = class(TForm)
    btnClose: TButton;
    pcSelect: TPageControl;
    tsThreads: TTabSheet;
    tsPosters: TTabSheet;
    tsNewsreaders: TTabSheet;
    lvThreads: TListView;
    lvPosters: TListView;
    lvNewsreaders: TListView;
    Panel1: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    stNoArticles: TLabel;
    stNoThreads: TLabel;
    stNoUnanswered: TLabel;
    stMessagebaseSize: TLabel;
    Label5: TLabel;
    btnCopyToClipboard: TButton;
    Bevel1: TBevel;
    btnStart: TButton;
    dtpFrom: TDateTimePicker;
    Label6: TLabel;
    Label7: TLabel;
    dtpTo: TDateTimePicker;
    PersistentPosition1: TPersistentPosition;
    btnPostToGroup: TButton;
    lblResult: TLabel;
    cbResults: TComboBox;
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lvNewsreadersData(Sender: TObject; Item: TListItem);
    procedure lvPostersData(Sender: TObject; Item: TListItem);
    procedure lvPostersColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvNewsreadersColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvThreadsData(Sender: TObject; Item: TListItem);
    procedure lvThreadsColumnClick(Sender: TObject; Column: TListColumn);
    procedure btnCopyToClipboardClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure PersistentPosition1GetSettingsClass(Owner: TObject; var SettingsClass: TExSettingsClass);
    procedure PersistentPosition1GetSettingsFile(Owner: TObject; var fileName: string);
    procedure btnPostToGroupClick(Sender: TObject);
    procedure cbResultsKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
  private
    fGroup: TSubscribedGroup;

    fStatistics: TStatistics;
    fStatisticContainer: TStatisticContainer;

    fPostersReverseSort: Boolean;
    fPostersSortColumn: Integer;

    fReadersReverseSort: Boolean;
    fReadersSortColumn: Integer;

    fThreadsReverseSort: Boolean;
    fCalculating: Boolean;
    fThreadsSortColumn: Integer;

    procedure WmSetup(var msg: TMessage); message WM_SETUP;
    procedure GenerateReport(Report: TStrings);
    function GetAccount: TNNTPAccount;
  protected
    procedure UpdateActions; override;
    property Account: TNNTPAccount read GetAccount;
  public
    property Group: TSubscribedGroup read fGroup write fGroup;
  end;

var
  fmNewsgroupStatistics: TfmNewsgroupStatistics;

implementation

uses ClipBrd;

var
  gReverseSort: Boolean = False;

{$R *.dfm}


function ComparePosters(list: TStringList; idx1, idx2: Integer): Integer;
var
  i1, i2: Integer;
begin
  i1 := Integer(list.Objects[idx1]);
  i2 := Integer(list.Objects[idx2]);
  Result := i2 - i1;
  if gReverseSort then
    Result := -Result;
end;


function CompareStatisticDataIntegers(list: TStringList; idx1, idx2: Integer): Integer;
var
  Stat1, Stat2: TStatistic;
begin
  Stat1 := TStatistic(list.Objects[idx1]);
  Stat2 := TStatistic(list.Objects[idx2]);
  Result := Stat1.DataInteger - Stat2.DataInteger;
  if gReverseSort then
    Result := -Result;
end;

function CompareStatisticNumbers(list: TStringList; idx1, idx2: Integer): Integer;
var
  Stat1, Stat2: TStatistic;
begin
  Stat1 := TStatistic(list.Objects[idx1]);
  Stat2 := TStatistic(list.Objects[idx2]);
  Result := Stat1.Number - Stat2.Number;
  if gReverseSort then
    Result := -Result;
end;

function CompareStatisticRankings(list: TStringList; idx1, idx2: Integer): Integer;
var
  Stat1, Stat2: TStatistic;
begin
  Stat1 := TStatistic(list.Objects[idx1]);
  Stat2 := TStatistic(list.Objects[idx2]);
  Result := Stat1.Ranking - Stat2.Ranking;
  if gReverseSort then
    Result := -Result;
end;

function CompareStatisticStrings(list: TStringList; idx1, idx2: Integer): Integer;
begin
  Result := CompareText(list[idx1], list[idx2]);
  if gReverseSort then
    Result := -Result;
end;

function CompareStatisticDataStrings(list: TStringList; idx1, idx2: Integer): Integer;
var
  Stat1, Stat2: TStatistic;
begin
  Stat1 := TStatistic(list.Objects[idx1]);
  Stat2 := TStatistic(list.Objects[idx2]);
  Result := CompareText(Stat1.DataString, Stat2.DataString);
  if gReverseSort then
    Result := -Result;
end;

{ TfmNewsgroupStatistics }

procedure TfmNewsgroupStatistics.btnCopyToClipboardClick(Sender: TObject);
var
  Report: TStringList;
begin
  Report := TStringList.Create;
  try
    GenerateReport(Report);
    Clipboard.AsText := Report.Text
  finally
    Report.Free;
  end
end;

procedure TfmNewsgroupStatistics.btnPostToGroupClick(Sender: TObject);
var
  Report: TStringList;
  Form: TfmPostMessage;
begin
  Report := TStringList.Create;
  try
    GenerateReport(Report);

    if Assigned(Group) and Assigned(Account) then
    begin
      Form := TfmPostMessage.Create(Self);
      try
        Form.GroupName := Group.Name;
        Form.Account := Account;
        Form.NNTPSettings := Group.NNTPSettings;
        Form.DefaultPostingSettings := Group.PostingSettings;

        Form.Subject := Report[0];
        Form.InitialText := Report.Text;
        Form.ReplyToArticle := nil;
        Form.Show;
      except
        Form.Free;
        raise
      end
    end;
  finally
    Report.Free;
  end
end;

procedure TfmNewsgroupStatistics.btnStartClick(Sender: TObject);
begin
  FreeAndnil(fStatistics);
  FreeAndnil(fStatisticContainer);
  PostMessage(handle, WM_SETUP, 0, 0);
end;

procedure TfmNewsgroupStatistics.cbResultsKeyPress(Sender: TObject;
  var Key: Char);
begin
  if not (Key in [#8, '0'..'9']) then
    Key := #0;
end;

procedure TfmNewsgroupStatistics.FormCreate(Sender: TObject);
var
  reg: TExSettings;
  S: string;
begin
  reg := CreateExSettings;
  try
    reg.Section := 'Statistics';
    S := reg.StringValue['MaxResults']
  finally
    reg.Free
  end;
  if S <> '' then
    cbResults.Text := S;
end;

procedure TfmNewsgroupStatistics.FormDestroy(Sender: TObject);
var
  reg: TExSettings;
begin
  reg := CreateExSettings;
  try
    reg.Section := 'Statistics';
    reg.StringValue['MaxResults'] := cbResults.Text;
  finally
    reg.Free
  end;
  fStatistics.Free;
  fStatisticContainer.Free;
end;

procedure TfmNewsgroupStatistics.FormShow(Sender: TObject);
var
  i: Integer;
  art: TArticle;
  sd, ed: TDateTime;
begin
  AdjustFormConstraints(Self);
  Caption := 'Newsgroup Statistics for ' + fGroup.Name;

  sd := 0;
  ed := 0;

  for i := 0 to fGroup.ArticleCount - 1 do
  begin
    art := fGroup.Articles[i];

    if sd = 0 then
      sd := art.Date
    else
      if art.Date < sd then
        sd := art.Date;

    if ed = 0 then
      ed := art.Date
    else
      if art.Date > ed then
        ed := art.Date
  end;

  dtpFrom.DateTime := Int(sd);
  dtpTo.DateTime := ed;
end;


procedure TfmNewsgroupStatistics.GenerateReport(Report: TStrings);
var
  First: Integer;
  Last: Integer;
  I: Integer;
  ArticleNo: Integer;
  Stat: TStatistic;
begin
  Report.Clear;

  Report.Add('XanaNews Statistic for ' + fStatisticContainer.Name + '.  ' + DateTimeToStr(Now));
  Report.Add('');

  if fStatisticContainer.ArticleCount > 0 then
  begin
    First := 0;
    Last  := fStatisticContainer.ArticleCount - 1;
    for I := 0 to fStatisticContainer.ArticleCount - 1 do
    begin
      ArticleNo := fStatisticContainer.ArticleBase[I].ArticleNo;
      if ArticleNo <> 0 then
      begin
        if ArticleNo < fStatisticContainer.ArticleBase[First].ArticleNo then
          First := I;
        if ArticleNo > fStatisticContainer.ArticleBase[Last].ArticleNo then
          Last := I;
      end;
    end;

    Report.Add(Format('From article %d (%s) to article %d (%s)',[
      fStatisticContainer.ArticleBase[First].ArticleNo,
      DateTimeToStr(fStatisticContainer.ArticleBase[First].Date),
      fStatisticContainer.ArticleBase[Last].ArticleNo,
      DateTimeToStr(fStatisticContainer.ArticleBase[Last].Date)]));
    Report.Add('');
  end;

  Report.Add('Number of threads  ................... ' + IntToStr(fStatisticContainer.ThreadCount));
  Report.Add('Number of articles  .................. ' + IntToStr(fStatisticContainer.ArticleCount));
  Report.Add('Average articles per thread  ......... ' + Format('%0.2f',[fStatisticContainer.ArticleCount / fStatisticContainer.ThreadCount]));
  Report.Add('Number of unanswered posts  .......... ' + IntToStr(fStatistics.fNoUnanswered));
  Report.Add('Number of posts from XanaNews users .. ' + IntToStr(fStatistics.fNoXanaNews));
  Report.Add('');
  Report.Add('');
  Report.Add('Top Threads');
  Report.Add('');
  Report.Add('Ranking  Articles  Subject');
  Report.Add('-------  --------  ----------------------------------');

  for I := 0 to fStatistics.fThreads.Count - 1 do
  begin
    Stat := TStatistic(fStatistics.fThreads.Objects[I]);
    if Stat.Number > 1 then
      Report.Add(Format('%7d  %8d  %s',[Stat.Ranking, Stat.Number, fStatistics.fThreads[I]]));
  end;
  Report.Add('');
  Report.Add('');

  Report.Add('Top Posters');
  Report.Add('');
  Report.Add('Ranking  Articles  Name                        Last Reader');
  Report.Add('-------  --------  --------------------------  -----------');

  for I := 0 to fStatistics.fPosters.Count - 1 do
  begin
    Stat := TStatistic(fStatistics.fPosters.Objects[I]);
    Report.Add(Format('%7d  %8d  %-26.26s  %-25.25s',[Stat.Ranking, Stat.Number, fStatistics.fPosters[I], Stat.DataString]));
  end;
  Report.Add('');
  Report.Add('');

  Report.Add('Top Newsreaders');
  Report.Add('');
  Report.Add('Ranking  Articles  Newsreader                                    Users');
  Report.Add('-------  --------  --------------------------------------------  -----');

  for I := 0 to fStatistics.fReaders.Count - 1 do
  begin
    Stat := TStatistic(fStatistics.fReaders.Objects[I]);
    Report.Add(Format('%7d  %8d  %-44.44s  %5s',[Stat.Ranking, Stat.Number, fStatistics.fReaders[I], IntToStr(Stat.DataInteger)]));
  end;
end;

function TfmNewsgroupStatistics.GetAccount: TNNTPAccount;
begin
  if Assigned(fGroup) then
    Result := fGroup.Owner
  else
    Result := nil;  
end;

procedure TfmNewsgroupStatistics.lvNewsreadersColumnClick(Sender: TObject;
  Column: TListColumn);
var
  col: Integer;
begin
  col := Column.Index;

  if col = fReadersSortColumn then
    fReadersReverseSort := not fReadersReverseSort
  else
    fReadersReverseSort := False;

  gReverseSort := fReadersReverseSort;

  case col of
    0: fStatistics.fReaders.CustomSort(CompareStatisticRankings);
    1: fStatistics.fReaders.CustomSort(CompareStatisticNumbers);
    2: fStatistics.fReaders.CustomSort(CompareStatisticStrings);
    3: fStatistics.fReaders.CustomSort(CompareStatisticDataIntegers);
  end;

  fReadersSortColumn := Col;
  lvNewsreaders.Invalidate
end;

procedure TfmNewsgroupStatistics.lvNewsreadersData(Sender: TObject;
  Item: TListItem);
var
  idx: Integer;
  Statistic: TStatistic;
begin
  idx := Item.Index;
  if idx < fStatistics.fReaders.Count then
  begin
    Statistic := TStatistic(fStatistics.fReaders.Objects[idx]);

    Item.Caption := IntToStr(Statistic.Ranking);
    Item.SubItems.Add(IntToStr(Statistic.Number));
    Item.SubItems.Add(fStatistics.fReaders[idx]);
    Item.SubItems.Add(IntToStr(Statistic.DataInteger));
  end
end;

procedure TfmNewsgroupStatistics.lvPostersColumnClick(Sender: TObject;
  Column: TListColumn);
var
  col: Integer;
begin
  col := Column.Index;

  if col = fPostersSortColumn then
    fPostersReverseSort := not fPostersReverseSort
  else
    fPostersReverseSort := False;

  gReverseSort := fPostersReverseSort;

  case col of
    0: fStatistics.fPosters.CustomSort(CompareStatisticRankings);
    1: fStatistics.fPosters.CustomSort(CompareStatisticNumbers);
    2: fStatistics.fPosters.CustomSort(CompareStatisticStrings);
    3: fStatistics.fPosters.CustomSort(CompareStatisticDataStrings);
  end;

  fPostersSortColumn := Col;
  lvPosters.Invalidate
end;

procedure TfmNewsgroupStatistics.lvPostersData(Sender: TObject;
  Item: TListItem);
var
  idx: Integer;
  Statistic: TStatistic;
begin
  idx := Item.Index;
  if idx < fStatistics.fPosters.Count then
  begin
    Statistic := TStatistic(fStatistics.fPosters.Objects[idx]);

    Item.Caption := IntToStr(Statistic.Ranking);
    Item.SubItems.Add(IntToStr(Statistic.Number));
    Item.SubItems.Add(fStatistics.fPosters[idx]);
    Item.SubItems.Add(Statistic.DataString)
  end
end;

procedure TfmNewsgroupStatistics.lvThreadsColumnClick(Sender: TObject;
  Column: TListColumn);
var
  col: Integer;
begin
  col := Column.Index;

  if col = fThreadsSortColumn then
    fThreadsReverseSort := not fThreadsReverseSort
  else
    fThreadsReverseSort := False;

  gReverseSort := fThreadsReverseSort;

  case col of
    0: fStatistics.fThreads.CustomSort(CompareStatisticRankings);
    1: fStatistics.fThreads.CustomSort(CompareStatisticNumbers);
    2: fStatistics.fThreads.CustomSort(CompareStatisticStrings);
    3: fStatistics.fThreads.CustomSort(CompareStatisticDataIntegers);
  end;

  fThreadsSortColumn := Col;
  lvThreads.Invalidate
end;


procedure TfmNewsgroupStatistics.lvThreadsData(Sender: TObject;
  Item: TListItem);
var
  idx: Integer;
  Statistic: TStatistic;
begin
  idx := Item.Index;
  if idx < fStatistics.fThreads.Count then
  begin
    Statistic := TStatistic(fStatistics.fThreads.Objects[idx]);

    Item.Caption := IntToStr(Statistic.Ranking);
    Item.SubItems.Add(IntToStr(Statistic.Number));
    Item.SubItems.Add(fStatistics.fThreads[idx]);
  end
end;

procedure TfmNewsgroupStatistics.PersistentPosition1GetSettingsClass(
  Owner: TObject; var SettingsClass: TExSettingsClass);
begin
  SettingsClass := gExSettingsClass;
end;

procedure TfmNewsgroupStatistics.PersistentPosition1GetSettingsFile(
  Owner: TObject; var fileName: string);
begin
 fileName := gExSettingsFile
end;

procedure TfmNewsgroupStatistics.UpdateActions;
begin
  btnCopyToClipboard.Enabled := Assigned(fStatistics) and not fCalculating;
  btnPostToGroup.Enabled := Assigned(fStatistics) and not fCalculating;
end;

procedure TfmNewsgroupStatistics.WmSetup(var msg: TMessage);
var
  oldCursor: TCursor;
begin
  oldCursor := Screen.Cursor;
  try
    fCalculating := True;
    lvNewsReaders.Items.Count := 0;
    lvPosters.Items.Count := 0;
    lvThreads.Items.Count := 0;
    lvNewsReaders.Invalidate;
    lvPosters.Invalidate;
    lvThreads.Invalidate;
    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;

    fStatisticContainer := TStatisticContainer.Create(fGroup, dtpFrom.DateTime, dtpTo.DateTime);
    fStatistics := TStatistics.Create(fStatisticContainer, StrToIntDef(cbResults.Text, fStatisticContainer.fArticles.Count));

    stNoThreads.Caption := IntToStr(fStatisticContainer.ThreadCount);
    stNoArticles.Caption := IntToStr(fStatistics.NonDummyArticleCount);
    stNoUnanswered.Caption := IntToStr(fStatistics.fNoUnanswered);
    stMessagebaseSize.Caption := IntToStr(fStatisticContainer.MessagebaseSize div 1024);

    fPostersReverseSort := True;
    fPostersSortColumn := 0;

    fReadersReverseSort := True;
    fReadersSortColumn := 0;

    fThreadsReverseSort := True;
    fThreadsSortColumn := 0;

    lvNewsReaders.Items.Count := fStatistics.fReaders.Count;
    lvPosters.Items.Count := fStatistics.fPosters.Count;
    lvThreads.Items.Count := fStatistics.fThreads.Count;
    UpdateActions;
  finally
    Screen.Cursor := oldCursor;
    fCalculating := False;
  end
end;

{ TStatisticArticle }

procedure TStatisticArticle.Assign(article: TArticleBase);
begin
  inherited;

  Self.fFlags := article.Flags;
  Self.fArticleNo := article.ArticleNo;
  Self.fAgent := article.Header['X-NewsReader'];
  if Self.fAgent = '' then
    Self.fAgent := article.Header['User-Agent'];
end;

constructor TStatisticArticle.Create(AOwner: TArticleContainer);
begin
  inherited;
  fCodePage := CP_ACP;
end;

function TStatisticArticle.GetHeader(const name: string): string;
begin
  if SameText(name, 'User-Agent') or SameText(name, 'X-NewsReader') then
    Result := fAgent
  else
    Result := ''
end;

function TStatisticArticle.GetMsg: TmvMessage;
begin
  Result := nil
end;

{ TStatisticContainer }

constructor TStatisticContainer.Create(AGroup: TArticleContainer;
  startDate, endDate: TDateTime);
var
  i: Integer;
  art, nart: TArticleBase;
  d: TDateTime;
begin
  inherited Create('', nil, nil);
  Name := AGroup.Name;
  ThreadSortOrder := soDate;
  ThreadOrder := toChronological;

  endDate := Int(endDate) + 1;

  fMessagebaseSize := AGroup.MessagebaseSize;

  for i := 0 to AGroup.ArticleCount - 1 do
  begin
    art := AGroup.ArticleBase[i];
    d := art.Date;
    if (d >= startDate) and (d < endDate) then
    begin
      nart := TStatisticArticle.Create(Self);
      nart.Assign(art);
      RawAddArticle(nart)
    end
  end;

  fUnreadArticleCount := -1;
  fUnloadedArticleCount := -1;
  fArticlesLoaded := True;
  GetUnreadArticleCount;
  ThreadOrder := toThreaded;
end;

function TStatisticContainer.GetMessagebaseSize: Int64;
begin
  Result := fMessagebaseSize;
end;

function TStatisticContainer.GetNext: TArticleContainer;
begin
  Result := nil
end;

function TStatisticContainer.GetServerSettings: TServerSettings;
begin
  Result := nil
end;

function TStatisticContainer.GetUnreadArticleCount: Integer;
var
  i: Integer;
begin
  Result := 0;

  if fUnreadArticleCount = -1 then
  begin
    fUnreadArticleToMeCount := 0;
    fUnreadXananewsArticleCount := 0;
    fUnloadedArticleCount := 0;
    fUnreadReplyCount := 0;
    fUnloadedArticleCount := ArticleCount;
    for i := 0 to ArticleCount - 1 do
      if not ArticleBase[i].IsRead then
      begin
        Inc(Result);
        if ArticleBase[i].IsMine then
          Inc(fUnreadArticleToMeCount);
        if ArticleBase[i].IsReply then
          Inc(fUnreadReplyCount);
        if ArticleBase[i].IsXanaNews then
          Inc(fUnreadXananewsArticleCount)
      end;
    fUnreadArticleCount := Result
  end
  else
    Result := fUnreadArticleCount
end;

procedure TStatisticContainer.LoadArticles;
begin
end;

procedure TStatisticContainer.SaveArticles(recreateMessageFile: Boolean);
begin
end;

{ TStatistics }

constructor TStatistics.Create(AGroup: TArticleContainer; MaxResults: Integer);
var
  i, idx: Integer;
  article: TArticleBase;
  bart: TArticleBase;
  agent, poster: string;
  Stat: TStatistic;

  function GetAgent(article: TArticleBase): string;
  var
    p, idx: Integer;
  begin
    Result := article.Header['X-Newsreader'];
    if Result = '' then
      Result := article.Header['User-Agent'];

    if Result <> '' then
    begin
      p := Pos('/', Result);
      if p > 0 then
        Result := Copy(Result, 1, p - 1);
      p := 0;
      for idx := 3 to Length(Result) do       // Start at 3 so that 40tude doesn't feel left out.
        if Result[idx] in['0'..'9'] then
        begin
          p := idx;
          break
        end;
      if p > 0 then
        Result := Trim(Copy(Result, 1, p - 1));

      if (Length(Result) > 2) and SameText(Copy(Result, Length(Result) - 1, MaxInt), ' v') then
        Result := Copy(Result, 1, Length(Result) - 2);
    end
  end;

  function GetThreadHeight(article: TArticleBase): Integer;
  var
    p: TArticleBase;
  begin
    Result := 1;
    p := Article.Child;
    while Assigned(p) do
    begin
      Inc(Result, GetThreadHeight(p));
      p := p.sibling
    end
  end;

begin
  fGroup := AGroup;

  fPosters := TStringList.Create;  fPosters.CaseSensitive := False; fPosters.Duplicates := dupError; fPosters.Sorted := True;
  fReaders := TStringList.Create;  fReaders.CaseSensitive := False; fReaders.Duplicates := dupError; fReaders.Sorted := True;
  fThreads := TStringList.Create;  fThreads.CaseSensitive := False; fThreads.Duplicates := dupAccept; fThreads.Sorted := True;

  for i := 0 to fGroup.ArticleCount - 1 do
  begin
    article := fGroup.ArticleBase[i];
    if article.ArticleNo <> 0 then
      Inc(fNonDummyArticleCount);

    agent := GetAgent(article);
    if SameText(agent, 'XanaNews') then
      Inc(fNoXanaNews);

    if agent <> '' then
    begin
      idx := fReaders.IndexOf(agent);
      if idx = -1 then
      begin
        Stat := TStatistic.Create;
        fReaders.AddObject(agent, Stat)
      end
      else
        Stat := TStatistic(fReaders.Objects[idx]);
      Inc(Stat.fNumber)
    end;

    poster := article.FromName;

    if poster <> '' then
    begin
      idx := fPosters.IndexOf(poster);
      if idx = -1 then
      begin
        Stat := TStatistic.Create;
        fPosters.AddObject(poster, Stat)
      end
      else
        Stat := TStatistic(fPosters.Objects[idx]);
      Inc(Stat.fNumber);
      if agent <> '' then
        Stat.fDataString := agent
    end
  end;

  fPosters.Sorted := False;
  gReverseSort := True;
  fPosters.CustomSort(CompareStatisticNumbers);
  for i := 0 to fPosters.Count - 1 do
  begin
    Stat := TStatistic(fPosters.Objects[i]);
    Stat.fRanking := i + 1;
    if Stat.fDataString <> '' then
    begin
      idx := fReaders.IndexOf(Stat.fDataString);
      if idx >= 0 then
      begin
        Stat := TStatistic(fReaders.Objects[idx]);
        Inc(Stat.fDataInteger)
      end
    end
  end;

  fReaders.Sorted := False;
  fReaders.CustomSort(CompareStatisticNumbers);
  for idx := 0 to fReaders.Count - 1 do
    TStatistic(fReaders.Objects[idx]).fRanking := idx + 1;

  for i := 0 to fGroup.ThreadCount - 1 do
  begin
    bart := fGroup.Threads[i];

    if (bart.Child = nil) and (bart.Header['References'] = '') then
      Inc(fNoUnanswered);

    Stat := TStatistic.Create;
    Stat.fNumber := GetThreadHeight(bart);
    fThreads.AddObject(DecodeSubject(bart.Subject), Stat);
  end;

  fThreads.Sorted := False;
  fThreads.CustomSort(CompareStatisticNumbers);
  for idx := 0 to fThreads.Count - 1 do
    TStatistic(fThreads.Objects[idx]).fRanking := idx + 1;

  for i := fPosters.Count - 1 downto MaxResults do
  begin
    fPosters.Objects[i].Free;
    fPosters.Delete(i);
  end;

  for i := fReaders.Count - 1 downto MaxResults do
  begin
    fReaders.Objects[i].Free;
    fReaders.Delete(i);
  end;

  for i := fThreads.Count - 1 downto MaxResults do
  begin
    fThreads.Objects[i].Free;
    fThreads.Delete(i);
  end;
end;

destructor TStatistics.Destroy;
var
  i: Integer;
begin
  for i := 0 to fReaders.Count - 1 do
    fReaders.Objects[i].Free;
  fReaders.Free;

  for i := 0 to fPosters.Count - 1 do
    fPosters.Objects[i].Free;
  fPosters.Free;

  for i := 0 to fThreads.Count - 1 do
    fThreads.Objects[i].Free;
  fThreads.Free;
  inherited;
end;

end.
