{**********************************************************************}
{                                                                      }
{    "The contents of this file are subject to the Mozilla Public      }
{    License Version 1.1 (the "License"); you may not use this         }
{    file except in compliance with the License. You may obtain        }
{    a copy of the License at http://www.mozilla.org/MPL/              }
{                                                                      }
{    Software distributed under the License is distributed on an       }
{    "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express       }
{    or implied. See the License for the specific language             }
{    governing rights and limitations under the License.               }
{                                                                      }
{    The Initial Developer of the Original Code is Matthias            }
{    Ackermann. For other initial contributors, see contributors.txt   }
{    Subsequent portions Copyright Creative IT.                        }
{                                                                      }
{    Current maintainer: Eric Grange                                   }
{                                                                      }
{**********************************************************************}
{$I dws.inc}
unit dwsErrors;

interface

uses
   Classes, SysUtils, dwsStrings, dwsUtils;

type

   TdwsMessageList = class;

   // TSourceFile
   //
   TSourceFile = class
      public
         SourceFile: String;
         SourceCode: String;
   end;

   // TScriptPos
   //
   PScriptPos = ^TScriptPos;
   TScriptPos = packed record
      private
         // 12bits for the column (4096)
         // 20bits for the line (1048576)
         FLineCol : Cardinal;

         function GetLine : Integer; inline;
         procedure SetLine(const aLine : Integer); inline;
         function GetCol : Integer; inline;
         procedure SetCol(const aCol : Integer); inline;

      public
         SourceFile : TSourceFile;

         constructor Create(aSourceFile : TSourceFile; aLine, aCol : Integer);

         property LineCol : Cardinal read FLineCol write FLineCol;
         property Line : Integer read GetLine write SetLine;
         property Col : Integer read GetCol write SetCol;

         function SamePosAs(const aPos : TScriptPos) : Boolean;

         procedure IncCol; inline;
         procedure NewLine; inline;

         function AsInfo : String;
   end;
   TScriptPosArray = array of TScriptPos; // dynamic array that can hold ScriptPos settings (needed for ReadNameList)

   // TdwsMessage
   //
   TdwsMessage = class abstract
      private
         FMsgs: TdwsMessageList;
         FText: String;

      public
         constructor Create(Msgs: TdwsMessageList; const Text: String);

         function SameMessageAs(aMsg : TdwsMessage) : Boolean; virtual;
         function AsInfo: String; virtual; abstract;
         property Text : String read FText;
   end;

   // Messages without position

   TInfoMessage = class(TdwsMessage)
      function AsInfo: String; override;
   end;

   TErrorMessage = class(TdwsMessage)
      function AsInfo: String; override;
   end;

   // Messages with position

   // TScriptMessage
   //
   TScriptMessage = class(TdwsMessage)
      Pos: TScriptPos;
      constructor Create(Msgs: TdwsMessageList; const Text: String; const P: TScriptPos); overload;
      function SameMessageAs(aMsg : TdwsMessage) : Boolean; override;
      function AsInfo: String; override;
   end;

   TScriptMessageClass = class of TScriptMessage;

   THintMessage = class(TScriptMessage)
      function AsInfo: String; override;
   end;

   TWarningMessage = class(TScriptMessage)
      function AsInfo: String; override;
   end;

   TCompilerErrorMessage = class(TScriptMessage)
      function AsInfo: String; override;
   end;

   TSyntaxErrorMessage = class(TScriptMessage)
      function AsInfo: String; override;
   end;

   TExecutionErrorMessage = class(TScriptMessage)
      function AsInfo: String; override;
   end;

   // TdwsMessageList
   //
   TdwsMessageList = class
      private
         FSourceFiles: TTightList;
         FMessageList: TTightList;
         FHasErrors : Boolean;
         FHasCompilerErrors : Boolean;
         FHasExecutionErrors : Boolean;
         FLastScriptError : TScriptPos;

         function GetMsg(Index: Integer): TdwsMessage;
         function GetMsgCount: Integer;
         procedure AddMsg(aMessage: TdwsMessage);

      public
         constructor Create;
         destructor Destroy; override;

         function RegisterSourceFile(const SourceFile: String; const SourceCode: String): TSourceFile;
         function GetSourceFile(const aSourceFile: String): TSourceFile;

         procedure AddInfo(const Text: String);
         procedure AddError(const Text: String);
         procedure AddErrorStop(const Text: String);

         // Called in compiler

         procedure AddCompilerInfo(const Text: String);

         procedure AddCompilerHint(const Pos: TScriptPos; const Text: String);

         procedure AddCompilerWarning(const Pos: TScriptPos; const Text: String);
         procedure AddCompilerWarningFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const);

         procedure AddCompilerError(const Pos: TScriptPos; const Text: String; messageClass : TScriptMessageClass); overload;
         procedure AddCompilerError(const Pos: TScriptPos; const Text: String); overload;
         procedure AddCompilerErrorFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const; messageClass : TScriptMessageClass); overload;
         procedure AddCompilerErrorFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const); overload;

         procedure AddCompilerStop(const Pos: TScriptPos; const Text: String; messageClass : TScriptMessageClass); overload;
         procedure AddCompilerStop(const Pos: TScriptPos; const Text: String); overload;
         procedure AddCompilerStopFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const; messageClass : TScriptMessageClass); overload;
         procedure AddCompilerStopFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const); overload;

         // Called during execution

         procedure AddExecutionError(const Text: String); overload;
         procedure AddExecutionError(const Pos: TScriptPos; const Text: String); overload;

         procedure AddExecutionStop(const Pos: TScriptPos; const Text: String);
         procedure AddExecutionStopFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const);

         procedure SetLastScriptError(const Pos: TScriptPos);

         procedure Clear;

         function AsInfo: String;

         property Msgs[Index: Integer]: TdwsMessage read GetMsg; default;
         property Count: Integer read GetMsgCount;
         property HasErrors: Boolean read FHasErrors;
         property HasCompilerErrors: Boolean read FHasCompilerErrors;
         property HasExecutionErrors: Boolean read FHasExecutionErrors;
   end;

   // The script initialization failed because a class needs one or more methods
   // to be implemented.
   EClassIncompleteError = class(Exception)
      private
         FClassSymObj: TObject;   // object that refers to the TClassSymbol

      public
         property ClassSymObj: TObject read FClassSymObj write FClassSymObj;
   end;

   EClassPropertyIncompleteError = class(EClassIncompleteError);

   // The script has to be stopped because of an error
   EScriptError = class(Exception)
      private
         FScriptPos : TScriptPos;

      public
         constructor CreatePosFmt(const pos : TScriptPos; const Msg: string; const Args: array of const);

         property Pos : TScriptPos read FScriptPos;
   end;

   ECompileError = class(EScriptError);

   EReraise = class(Exception);

const
   cNullPos: TScriptPos = (FLineCol: 0; SourceFile: nil);

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

// ------------------
// ------------------ TScriptPos ------------------
// ------------------

// Create
//
constructor TScriptPos.Create(aSourceFile : TSourceFile; aLine, aCol : Integer);
begin
   SourceFile:=aSourceFile;
   Line:=(aCol shr 20)+aLine;
end;

// GetLine
//
function TScriptPos.GetLine : Integer;
begin
   Result:=FLineCol and $FFFFF;
end;

// SetLine
//
procedure TScriptPos.SetLine(const aLine : Integer);
begin
   FLineCol:=(FLineCol and $FFF00000) or Cardinal(aLine);
end;

// GetCol
//
function TScriptPos.GetCol : Integer;
begin
   Result:=(FLineCol shr 20) and $FFF;
end;

// SetCol
//
procedure TScriptPos.SetCol(const aCol : Integer);
begin
   FLineCol:=(FLineCol and $FFFFF) or (Cardinal(aCol) shl 20);
end;

// SamePosAs
//
function TScriptPos.SamePosAs(const aPos : TScriptPos) : Boolean;
begin
   Result:=    (FLineCol=aPos.FLineCol)
           and (SourceFile=aPos.SourceFile);
end;

// IncCol
//
procedure TScriptPos.IncCol;
begin
   Inc(FLineCol, $100000);
end;

// NewLine
//
procedure TScriptPos.NewLine;
begin
   FLineCol:=(FLineCol and $FFFFF)+$100001;
end;

// AsInfo
//
function TScriptPos.AsInfo : String;
begin
   if SourceFile=nil then
      Result:=''
   else begin
      if SourceFile.SourceFile<>MSG_MainModule then
         Result:=Format(MSG_ScriptPosFile, [SourceFile.SourceFile])
      else Result:='';
      if Col<>cNullPos.Col then begin
         if Result<>'' then
            Result:=', '+Result;
         Result:=Format(MSG_ScriptPosColumn, [Col])+Result;
      end;
      if Line<>cNullPos.Line then begin
         if Result<>'' then
            Result:=', '+Result;
         Result:=Format(MSG_ScriptPosLine, [Line])+Result;
      end;
      if Result<>'' then
         Result:=' ['+Result+']';
   end;
end;

// ------------------
// ------------------ EScriptError ------------------
// ------------------

// CreatePosFmt
//
constructor EScriptError.CreatePosFmt(const pos : TScriptPos; const Msg: string; const Args: array of const);
begin
   inherited CreateFmt(msg, args);
   FScriptPos:=pos;
end;

// ------------------
// ------------------ TdwsMessageList ------------------
// ------------------

// Create
//
constructor TdwsMessageList.Create;
begin
   FLastScriptError:=cNullPos;
end;

// Destroy
//
destructor TdwsMessageList.Destroy;
begin
   FSourceFiles.Clean;
   FMessageList.Clean;
   inherited;
end;

// Clear
//
procedure TdwsMessageList.Clear;
begin
   FMessageList.Clean;
   FHasErrors:=False;
   FHasCompilerErrors:=False;
   FHasExecutionErrors:=False;
   FLastScriptError:=cNullPos;
end;

// GetMsg
//
function TdwsMessageList.GetMsg(Index: Integer): TdwsMessage;
begin
   Result:=TdwsMessage(FMessageList.List[Index]);
end;

// GetMsgCount
//
function TdwsMessageList.GetMsgCount: Integer;
begin
   Result:=FMessageList.Count;
end;

// AddMsg
//
procedure TdwsMessageList.AddMsg(aMessage: TdwsMessage);
var
   i : Integer;
   msg : TdwsMessage;
begin
   for i:=0 to FMessageList.Count-1 do begin
      msg:=TdwsMessage(FMessageList.List[i]);
      if msg.SameMessageAs(aMessage) then begin
         aMessage.Free;
         Exit;
      end;
   end;
   FMessageList.Add(aMessage);
end;

// RegisterSourceFile
//
function TdwsMessageList.RegisterSourceFile(const SourceFile: String; const SourceCode: String): TSourceFile;
var
   sf: TSourceFile;
begin
   sf:=GetSourceFile(SourceFile);
   if not Assigned(sf) or (sf.SourceCode <> SourceCode) then begin
      Result:=TSourceFile.Create;
      Result.SourceFile:=SourceFile;
      Result.SourceCode:=SourceCode;
      FSourceFiles.Add(Result);
   end else Result:=sf;
end;

// GetSourceFile
//
function TdwsMessageList.GetSourceFile(const aSourceFile: String): TSourceFile;
var
   i : Integer;
begin
   for i:=0 to FSourceFiles.Count-1 do begin
      Result:=TSourceFile(FSourceFiles.List[i]);
      if Result.SourceFile=aSourceFile then Exit;
   end;
   Result:=nil;
end;

// AddInfo
//
procedure TdwsMessageList.AddInfo(const Text: String);
begin
   AddMsg(TInfoMessage.Create(Self, Text));
end;

// AddError
//
procedure TdwsMessageList.AddError(const Text: String);
begin
   AddMsg(TErrorMessage.Create(Self, Text));
   FHasErrors:=True;
end;

// AddErrorStop
//
procedure TdwsMessageList.AddErrorStop(const Text: String);
begin
   AddError(Text);
   raise EScriptError.Create('')
end;

// AddCompilerInfo
//
procedure TdwsMessageList.AddCompilerInfo;
begin
   AddMsg(TInfoMessage.Create(Self, Text));
end;

// AddCompilerHint
//
procedure TdwsMessageList.AddCompilerHint(const Pos: TScriptPos; const Text: String);
begin
   AddMsg(THintMessage.Create(Self, Text, Pos));
end;

// AddCompilerWarning
//
procedure TdwsMessageList.AddCompilerWarning(const Pos: TScriptPos; const Text: String);
begin
   AddMsg(TWarningMessage.Create(Self, Text, Pos));
end;

// AddCompilerWarningFmt
//
procedure TdwsMessageList.AddCompilerWarningFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const);
begin
   AddCompilerWarning(Pos, Format(textFormat, args));
end;

// AddCompilerError
//
procedure TdwsMessageList.AddCompilerError(const Pos: TScriptPos; const Text: String; messageClass : TScriptMessageClass);
begin
   AddMsg(messageClass.Create(Self, Text, Pos));
   FHasCompilerErrors:=True;
   FHasErrors:=True;
end;

// AddCompilerError
//
procedure TdwsMessageList.AddCompilerError(const Pos: TScriptPos; const Text: String);
begin
   AddCompilerError(Pos, Text, TSyntaxErrorMessage);
end;

// AddCompilerErrorFmt
//
procedure TdwsMessageList.AddCompilerErrorFmt(const Pos: TScriptPos;
   const textFormat: String; const args: array of const; messageClass : TScriptMessageClass);
begin
   AddCompilerError(Pos, Format(textFormat, args), messageClass);
end;

// AddCompilerErrorFmt
//
procedure TdwsMessageList.AddCompilerErrorFmt(const Pos: TScriptPos;
   const textFormat: String; const args: array of const);
begin
   AddCompilerErrorFmt(Pos, textFormat, args, TSyntaxErrorMessage);
end;

// AddCompilerStop
//
procedure TdwsMessageList.AddCompilerStop(const Pos: TScriptPos; const Text: String; messageClass : TScriptMessageClass);
begin
   AddCompilerError(Pos, Text, messageClass);
   raise ECompileError.Create(Text);
end;

// AddCompilerStop
//
procedure TdwsMessageList.AddCompilerStop(const Pos: TScriptPos; const Text: String);
begin
   AddCompilerStop(Pos, Text, TSyntaxErrorMessage);
end;

// AddCompilerStopFmt
//
procedure TdwsMessageList.AddCompilerStopFmt(const Pos: TScriptPos; const textFormat : String;
                                   const args: array of const; messageClass : TScriptMessageClass);
begin
   AddCompilerStop(Pos, Format(textFormat, args), messageClass);
end;

// AddCompilerStopFmt
//
procedure TdwsMessageList.AddCompilerStopFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const);
begin
   AddCompilerStop(Pos, Format(textFormat, args), TSyntaxErrorMessage);
end;

// AddExecutionError
//
procedure TdwsMessageList.AddExecutionError(const Pos: TScriptPos; const Text: String);
begin
   AddMsg(TExecutionErrorMessage.Create(Self, Text, Pos));
   FHasExecutionErrors:=True;
   FHasErrors:=True;
end;

// AddExecutionError
//
procedure TdwsMessageList.AddExecutionError(const Text: String);
begin
   AddExecutionError(FLastScriptError, Text)
end;

// AddExecutionStop
//
procedure TdwsMessageList.AddExecutionStop(const Pos: TScriptPos; const Text: String);
begin
   AddExecutionError(Pos, Text);
   raise EScriptError.Create(Text);
end;

// AddExecutionStopFmt
//
procedure TdwsMessageList.AddExecutionStopFmt(const Pos: TScriptPos; const textFormat : String; const args: array of const);
begin
   AddExecutionStop(Pos, Format(textFormat, args));
end;

// SetLastScriptError
//
procedure TdwsMessageList.SetLastScriptError(const Pos: TScriptPos);
begin
   FLastScriptError:=Pos;
end;

// AsInfo
//
function TdwsMessageList.AsInfo: String;
var
   i: Integer;
begin
   Result:='';
   for i:=0 to Count-1 do
      Result:=Result+Msgs[i].AsInfo+#13#10
end;

// ------------------
// ------------------ TdwsMessage ------------------
// ------------------

// Create
//
constructor TdwsMessage.Create(Msgs: TdwsMessageList; const Text: String);
begin
   FMsgs:=Msgs;
   FText:=Text;
end;

// SameMessageAs
//
function TdwsMessage.SameMessageAs(aMsg : TdwsMessage) : Boolean;
begin
   Result:=(ClassType=aMsg.ClassType) and (FText=aMsg.FText);
end;

// ------------------
// ------------------ TInfoMessage ------------------
// ------------------

// AsInfo
//
function TInfoMessage.AsInfo: String;
begin
   Result:=Format(MSG_Info, [inherited AsInfo]);
end;

// ------------------
// ------------------ TErrorMessage ------------------
// ------------------

// AsInfo
//
function TErrorMessage.AsInfo: String;
begin
   Result:=Format(MSG_Error, [inherited AsInfo]);
end;

// ------------------
// ------------------ TScriptMessage ------------------
// ------------------

// Create
//
constructor TScriptMessage.Create(Msgs: TdwsMessageList; const Text: String; const P: TScriptPos);
begin
   inherited Create(Msgs, Text);
   Pos:=P;
end;

// SameMessageAs
//
function TScriptMessage.SameMessageAs(aMsg : TdwsMessage) : Boolean;
begin
   Result:=    inherited SameMessageAs(aMsg)
           and (Pos.SamePosAs((aMsg as TScriptMessage).Pos));
end;

// AsInfo
//
function TScriptMessage.AsInfo: String;
begin
   Result:=FText+Pos.AsInfo;
end;

// ------------------
// ------------------ THintMessage ------------------
// ------------------

// AsInfo
//
function THintMessage.AsInfo: String;
begin
   Result:=Format(MSG_Hint, [inherited AsInfo]);
end;

// ------------------
// ------------------ TWarningMessage ------------------
// ------------------

// AsInfo
//
function TWarningMessage.AsInfo: String;
begin
   Result:=Format(MSG_Warning, [inherited AsInfo]);
end;

// ------------------
// ------------------ TCompilerErrorMessage ------------------
// ------------------

// AsInfo
//
function TCompilerErrorMessage.AsInfo: String;
begin
   Result:=Format(MSG_CompileError, [inherited AsInfo]);
end;

// ------------------
// ------------------ TSyntaxErrorMessage ------------------
// ------------------

// AsInfo
//
function TSyntaxErrorMessage.AsInfo: String;
begin
   Result:=Format(MSG_SyntaxError, [inherited AsInfo]);
end;

// ------------------
// ------------------ TExecutionErrorMessage ------------------
// ------------------

// AsInfo
//
function TExecutionErrorMessage.AsInfo: String;
begin
   Result:=Format(MSG_RuntimeError, [inherited AsInfo]);
end;

end.