import Http.Classes.Canonical
import Http.Util.Date

namespace Http.Data
open Http.Classes

-- Module based on: https://httpwg.org/specs/rfc6265.html

/-- Controls if the cookie will be sent with cross-site requests so it protects a little bit against
cross-site request forgery attacks.

* Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
-/
inductive Cookie.SameSite where
  | strict
  | lax
  | none
  deriving Repr

instance : Inhabited Cookie.SameSite where
  default := .lax

instance : Canonical Cookie.SameSite where
  repr
    | .strict => "Strict"
    | .lax => "Lax"
    | .none => "None"

/-- This cookie structure is based on the structure defined inside the Set-Cookie header.

* Reference: https://httpwg.org/specs/rfc6265.html#sane-set-cookie
-/
structure Cookie where
  name: String
  value: String
  quoted: Bool

  -- Attributes

  expires: Option (Time.DateTime .GMT)
  maxAge: Nat
  domain: Option String
  path: Option String
  secure: Bool
  httpOnly: Bool
  partitioned: Bool
  sameSite: Cookie.SameSite

  deriving Inhabited, Repr

/-- Creates a new cookie without all the flags. -/
def Cookie.new (name value: String) (quoted: Bool) : Cookie :=
  let default : Cookie := Inhabited.default
  { default with name, value, quoted }

instance : Canonical Cookie where
  repr cookie := Id.run do
    let value := if cookie.quoted then String.quote cookie.value else cookie.value
    let mut result := s!"{cookie.name}={value}"

    match cookie.expires with
    | some res => result := s!"{result}; Expires={Http.Util.Date.RFC822.format res}"
    | none => ()

    if cookie.maxAge ≠ 0 then
      result := s!"{result}; Max-Age={cookie.maxAge}"

    match cookie.domain with
    | some domain => result := s!"{result}; Domain={domain}"
    | none => ()

    match cookie.path with
    | some path => result := s!"{result}; Path={path}"
    | none => ()

    if cookie.secure then
      result := s!"{result}; Secure"

    if cookie.httpOnly then
      result := s!"{result}; HttpOnly"

    if cookie.partitioned then
      result := s!"{result}; Partitioned"

    result
