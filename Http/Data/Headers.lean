import Http.Data.Headers.Transfer.Encoding

import Http.Data.Headers.Content.Accept
import Http.Data.Headers.Content.AcceptCharset
import Http.Data.Headers.Content.AcceptEncoding
import Http.Data.Headers.Content.AcceptLanguage
import Http.Data.Headers.Content.ContentEncoding
import Http.Data.Headers.Content.ContentLength
import Http.Data.Headers.Content.ContentType
import Http.Data.Headers.Content.ContentLocation

import Http.Data.Headers.Cache.Age
import Http.Data.Headers.Cache.CacheControl
import Http.Data.Headers.Cache.Expires

import Http.Data.Headers.Auth.Authorization
import Http.Data.Headers.Auth.WWWAuthenticate
import Http.Data.Headers.Auth.ProxyAuthorization
import Http.Data.Headers.Auth.ProxyAuthenticate

import Http.Data.Headers.Conditional.IfMatch
import Http.Data.Headers.Conditional.IfModifiedSince
import Http.Data.Headers.Conditional.IfNoneMatch
import Http.Data.Headers.Conditional.IfRange
import Http.Data.Headers.Conditional.IfUnmodifiedSince

import Http.Data.Headers.Other.Allow
import Http.Data.Headers.Other.Date
import Http.Data.Headers.Other.Host
import Http.Data.Headers.Other.SetCookie
import Http.Data.Headers.Other.Connection
import Http.Data.Headers.Other.Upgrade
import Http.Data.Headers.Other.KeepAlive

import Http.Classes
import Http.Data.Headers.Name
import CaseInsensitive
import Lean

namespace Http.Data
open Http.Classes
open Http.Data.Headers
open Lean


/-! Definition of a set of HTTP Headers. It is a multi map of fields -/

/-- Header values are a bunch of values that can be equal

* It MUST be possible to combine the multiple header fields into one
  "field-name: field-value" pair, without changing the semantics of the
  message, by appending each subsequent field-value to the first, each
  separated by a comma.

* The order in which header fields with the same
  field-name are received is therefore significant to the
  interpretation of the combined field value, and thus a proxy MUST NOT
  change the order of these field values when a message is forwarded. In
  this library its a ordered array in an unordered map so it will result
  in the same thing.
-/
abbrev Headers.HeaderValues := Array String

/-- Map of case insensitive fields to multiple values -/
def Headers := Lean.HashMap Headers.HeaderName String
  deriving Inhabited

instance : Repr Headers where
  reprPrec h _ :=
    let headerStrings := h.toList.map fun (name, values) =>
      s!"{String.quote (Canonical.text name)}: {String.quote values}"
    s!"\{{String.intercalate ", " headerStrings}}"

instance : Canonical .text Headers where
  repr h :=
    let headerStrings := h.toList.map fun (name, values) =>
      s!"{Canonical.text name}: {values}"
    String.intercalate "\r\n" headerStrings

def Headers.empty : Headers := Lean.HashMap.empty

/-- Adds a new value to the header map -/
def Headers.addRaw (headers: Headers) (name: HeaderName) (value: String) : Headers :=
  let arr := (· ++ ", " ++ value) <$> headers.find? name
  headers.insert name (arr.getD value)

def Headers.add [Canonical .text α] (headers: Headers) (name: HeaderName) (value: α) : Headers :=
  headers.addRaw name (Canonical.text value)

/-- Get the first value of a header s-/
def Headers.find? (headers: Headers) (name: HeaderName.Standard) [i: Header name α] : Option α := do
  let res ← HashMap.find? headers name
  i.parse res.trim

/-- Get the first value of a header s-/
def Headers.findRaw? (headers: Headers) (name: HeaderName) : Option String :=
  HashMap.find? headers name
