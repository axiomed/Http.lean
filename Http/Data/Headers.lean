import Lean.Data.HashMap

import Soda
import Soda.Grape
import Soda.Grape.Text

open Lean


-- | Headers are a map from header names to header values.
structure Headers where
  headers : HashMap String String

instance : Repr Headers where
  reprPrec h _ := repr h.headers.toList

instance : ToString Headers where
  toString h :=
    let headerStrings := h.headers.toList.map (fun (k, v) => k ++ ": " ++ v)
    String.intercalate "\r\n" headerStrings

def Headers.empty : Headers := { headers := HashMap.empty }

instance : Inhabited Headers where
  default := Headers.empty

def Headers.add (headers : Headers) (name : String) (value : String) : Headers :=
  { headers with headers := headers.headers.insert name value }

def Headers.with (name: String) (value: String) (headers: Headers) : Headers :=
  headers.add name value

def Headers.isEmpty (headers : Headers) : Bool :=
  headers.headers.isEmpty

-- | Parse a single header key-value pair
def Headers.headerParser : Grape.Grape (String × String) := do
  let headerName ← Grape.takeWhile (fun c => c ≠ 58 && c ≠ 13)
  let _ ← Grape.string ": "
  let headerValue ← Grape.takeWhile (fun c => c ≠ 13)
  let _ ← Grape.string "\r\n"
  Grape.pure (headerName.toASCIIString, headerValue.toASCIIString)

def Headers.parser : Grape.Grape Headers := do
  let headerList ← Grape.list Headers.headerParser
  let headers := HashMap.ofList headerList
  Grape.pure { headers }
