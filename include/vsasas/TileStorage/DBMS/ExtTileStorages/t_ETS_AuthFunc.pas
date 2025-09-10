{******************************************************************************}
{* SAS.Planet (SAS.�������)                                                   *}
{* Copyright (C) 2007-2012, SAS.Planet development team.                      *}
{* This program is free software: you can redistribute it and/or modify       *}
{* it under the terms of the GNU General Public License as published by       *}
{* the Free Software Foundation, either version 3 of the License, or          *}
{* (at your option) any later version.                                        *}
{*                                                                            *}
{* This program is distributed in the hope that it will be useful,            *}
{* but WITHOUT ANY WARRANTY; without even the implied warranty of             *}
{* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *}
{* GNU General Public License for more details.                               *}
{*                                                                            *}
{* You should have received a copy of the GNU General Public License          *}
{* along with this program.  If not, see <http://www.gnu.org/licenses/>.      *}
{*                                                                            *}
{* http://sasgis.ru                                                           *}
{* az@sasgis.ru                                                               *}
{******************************************************************************}

unit t_ETS_AuthFunc;

interface

type
  // ask authentication information from EXE
  // return FALSE if cancelled
  TExtStorageAuthFunc = function (Sender: TObject;
                                  const AGlobalStorageIdentifier: String;
                                  const AServiceName, AConnectionInfo: String;
                                  const AOptionsIn: LongWord;
                                  var ADomain: WideString;
                                  var ALogin: WideString;
                                  var APassword: WideString;
                                  const APtrOptionsOut: PLongWord): Boolean of object;

implementation

end.