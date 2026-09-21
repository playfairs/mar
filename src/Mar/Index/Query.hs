{-# LANGUAGE OverloadedStrings #-}

module Mar.Index.Query (searchEntries) where

import Data.Char (isAlphaNum, isSpace)
import qualified Data.Text as Text
import Database.SQLite.Simple
import Database.SQLite.Simple.ToField (toField)
import Mar.Core.Types (Entry)
import Mar.Index.Database ()
import Mar.Search.Filters (Filters (..))

searchEntries :: Connection -> String -> Filters -> IO [Entry]
searchEntries connection term filters
    | all (\character -> isAlphaNum character || isSpace character) term = query connection ftsSql (ftsParams term)
    | otherwise = query connection likeSql (likeParams term)
  where
    columns = "e.path,e.name,e.extension,e.parent,e.kind,e.size,e.modified_at,e.created_at,e.permissions,e.symlink_target,e.hidden"
    clauses = typeClause ++ extensionClause ++ hiddenClause ++ pathClause
    ftsSql = Query (Text.pack ("SELECT " ++ columns ++ " FROM entries e JOIN entries_fts f ON f.rowid = e.rowid WHERE f.entries_fts MATCH ?" ++ clauses ++ " ORDER BY e.path"))
    likeSql = Query (Text.pack ("SELECT " ++ columns ++ " FROM entries e WHERE (e.name LIKE ? OR e.path LIKE ?)" ++ clauses ++ " ORDER BY e.path"))
    ftsParams value = toField (value ++ "*") : filterParams filters
    likeParams value = [toField ('%' : map wildcard value ++ "%"), toField ('%' : map wildcard value ++ "%")] ++ filterParams filters
    typeClause = maybe "" (const " AND e.kind = ?") (filterType filters)
    extensionClause = maybe "" (const " AND e.extension = ?") (filterExtension filters)
    hiddenClause = if filterHidden filters then "" else " AND e.hidden = 0"
    pathClause = maybe "" (const " AND e.path LIKE ?") (filterPath filters)
    filterParams value = typeParam value ++ extensionParam value ++ pathParam value
    typeParam value = maybe [] (\kind -> [toField (show kind)]) (filterType value)
    extensionParam value = maybe [] (\extension -> [toField extension]) (filterExtension value)
    pathParam value = maybe [] (\path -> [toField (path ++ "%")]) (filterPath value)
    wildcard '*' = '%'
    wildcard '?' = '_'
    wildcard character = character
