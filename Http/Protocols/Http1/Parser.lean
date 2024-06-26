import Http.Protocols.Http1.Data
import Http.Protocols.Http1.Grammar
import Http.Data.URI.Parser
import Http.Data.Headers
import Http.Config
import Http.Data

namespace Http.Protocols.Http1
open Http.Protocols.Http1.Data
open Http.Data
open Http

/-! This module handles HTTP/1.1 protocol parsing and state management. It includes functions for
handling URI, fields, and headers of an HTTP request.
-/

/-- State structure to keep track of the request or repsonse that we are parsing right now -/
structure State where
  req: Request
  res: Response

  prop : String
  value : String

  bodySize : Nat
  uriSize : Nat

  hasContentLength : Bool
  contentLength : Option Nat
  host : Option String
  isChunked : Bool
  uri: URI.Parser

  headers: Headers

  chunkHeaders : Headers
  trailer : Trailers

inductive ParsingError where
  | invalidMessage (s: Nat)
  | uriTooLong
  | bodyTooLong
  | headerTooLong
  | headersTooLong
  deriving Repr

def checkRequest (options: MessageConfig) (info: State) : IO (Except ParsingError Unit) := do
  if let some size := options.maxRequestBody then
    if info.bodySize > size then
      return .error .bodyTooLong

  if info.uriSize > options.maxURISize then
    return .error .uriTooLong

  if info.value.length > options.maxHeaderSize ∨
    info.prop.length > options.maxHeaderSize then
    return .error .headerTooLong

  if info.chunkHeaders.size > options.maxHeaders ∨
     info.req.headers.size > options.maxHeaders ∨
     info.trailer.1.size > options.maxHeaders then
    return .error .headersTooLong

  return .ok ()

abbrev Parser := Grammar.Data State

/-- Creates an initial empty state for parsing with a given URI parser -/
def State.empty : State :=
  { host := none
  , hasContentLength := false
  , uriSize := 0
  , chunkHeaders := Headers.empty
  , isChunked := false
  , bodySize := 0
  , req := Request.empty
  , res := Response.empty
  , contentLength := none
  , prop := Inhabited.default
  , value := Inhabited.default
  , trailer := Inhabited.default
  , headers := Inhabited.default
  , uri := URI.Parser.create }

/-- Processes a URI fragment and updates the URI in the state -/
private def onUri (str: ByteArray) (data: State) : IO (State × Nat) := do
  let uri ← URI.Parser.feed data.uri str
  pure ({ data with uri, uriSize := data.uriSize + str.size }, 0)

/-- Finalizes the URI parsing and updates the request's URI field -/
private def endUri (data: State) : IO (State × Nat) := do
  match data.uri.data with
  | .ok uri => pure ({ data with uri := URI.Parser.create, req := {data.req with uri}}, 0)
  | .error _ => pure (data, 1)

/-- Processes and finalizes a field (header) in the HTTP request -/
private def endField (config: MessageConfig) (data: State) : IO (State × Nat) := do
  let prop := data.prop.toLower
  let value := data.value

  let (data, code) :=
    match prop with
    | "host" =>
      if data.host.isSome then
        (data, false)
      else
        let data := {data with host := some value }
        (data, (data.uri.info.authority.map (· != value)).getD true)
    | "transfer-encoding" =>
      let parts: Headers.Header .transferEncoding _ := inferInstance
      let parts := parts.parse value
      let parts := (Array.find? · Headers.TransferEncoding.isChunked) =<< parts
      if let some _ := parts
          then ({data with isChunked := true}, true)
          else (data, true)
    | _ => (data, true)

  if value.length > config.maxHeaderSize ∨ prop.length > config.maxHeaderSize then
    return (data, 1)

  let headers := data.headers.addRaw prop value

  pure ({ data with headers, prop := "", value := ""}, if code then 0 else 1)

private def onEndFieldExt (config: MessageConfig) (data: State) : IO (State × Nat) := do
  let prop := data.prop.toLower
  let value := data.value

  if value.length > config.maxHeaderSize ∨ prop.length > config.maxHeaderSize then
    return (data, 1)

  let chunkHeaders := data.chunkHeaders.addRaw prop value
  pure ({ data with chunkHeaders, prop := "", value := ""}, 0)

private def onEndFieldTrailer (config: MessageConfig) (data: State) : IO (State × Nat) := do
  let prop := data.prop.toLower
  let value := data.value

  if value.length > config.maxHeaderSize ∨ prop.length > config.maxHeaderSize then
    return (data, 1)

  let trailer := data.trailer.add prop value
  pure ({ data with trailer, prop := "", value := ""}, 0)

/-- Checks if the property being processed is "content-length" -/
private def endProp (data: State) : IO (State × Nat) := do
  let hasLength := data.prop.toLower == "content-length"

  let data :=
    if hasLength
      then { data with hasContentLength := true }
      else data

  pure (data, if hasLength then 1 else 0)

/-- Handles the body of the HTTP request and updates the request with the body content -/
private def onBody (fn: ByteArray → IO Unit) (body: ByteArray) (acc: State) : IO (State × Nat) := do
  fn body
  pure ({acc with bodySize := acc.bodySize + body.size}, 0)

/-- Processes the request line to set the HTTP method and version in the state -/
private def onRequestLine (method: Nat) (major: Nat) (minor: Nat) (acc: State) : IO (State × Nat) := do
  let method := Option.get! $ Method.ofNat method
  match Version.fromNumber major minor with
  | none => return (acc, 1)
  | some version => return ({acc with req := {acc.req with version, method}}, 0)

/-- Processes the response line to set the HTTP method and version in the state -/
private def onResponseLine (statusCode: Nat) (major: Nat) (minor: Nat) (acc: State) : IO (State × Nat) := do
  let status := Option.get! $ Status.fromCode statusCode.toUInt16
  match Version.fromNumber major minor with
  | none => return (acc, 1)
  | some version => do
    let acc := {acc with res := {acc.res with version, status}}
    return (acc, 0)

/-- Finalizes the headers and sets the content length if present, checking for required conditions -/
private def onEndHeaders {isRequest: Bool} (callback: (if isRequest then Request else Response) → IO Bool) (content: Nat) (acc: State) : IO (State × Nat) := do
  let code :=
    if acc.isChunked then 1
      else if acc.hasContentLength || (isRequest ∧ acc.req.method == .get) then 0
      else 2

  let code ← do
    let result ←
      match isRequest with
      | true => do
        let req := {acc.req with headers := acc.headers }
        callback req
      | false => do
        let res := {acc.res with headers := acc.headers }
        callback res
    pure (if result then code else 3)

  pure ({acc with contentLength := some content}, code)

/-- Handles the body of the HTTP request and updates the request with the body content -/
private def onChunk (fn: Chunk → IO Unit) (body: ByteArray) (acc: State) : IO (State × Nat) := do
  fn (Chunk.mk acc.chunkHeaders body)
  pure ({acc with chunkHeaders := Inhabited.default}, 0)

/-- Handles the end of the request usually with a function that receives the trailer -/
private def onEndRequest (fn: Trailers → IO Unit) (acc: State) : IO (State × Nat) := do
  fn acc.trailer
  pure (State.empty, 0)

/-- Creates the HTTP request parser with the provided body callback -/
def Parser.create
    (config: MessageConfig)
    (isRequest: Bool)
    (endHeaders: (if isRequest then Request else Response) → IO Bool)
    (endBody: ByteArray → IO Unit)
    (endChunk: Chunk → IO Unit)
    (endTrailers: Trailers → IO Unit)
    : Parser
    :=
      let data :=
        Grammar.create
          (onReasonPhrase := toString (λ_ acc => pure (acc, 0)))
          (onProp := toString (λval acc => pure ({acc with prop := acc.prop.append val}, 0)))
          (onValue := toString (λval acc => pure ({acc with value := acc.value.append val}, 0)))
          (onUrl := toByteArray onUri)
          (onBody := toByteArray (onBody endBody))
          (onChunkData := toByteArray (onChunk endChunk))
          (onEndHeaders := onEndHeaders endHeaders)
          (onEndProp := endProp)
          (onEndUrl := endUri)
          (onEndField := endField config)
          (onEndRequestLine := onRequestLine)
          (onEndFieldExt := onEndFieldExt config)
          (onEndFieldTrailer := onEndFieldTrailer config)
          (onEndRequest := onEndRequest endTrailers)
          (onEndResponseLine := onResponseLine)
          State.empty
      { data with type := if isRequest then 1 else 0 }
  where
    toByteArray func st en bt data := func (bt.extract st en) data
    toString func st en bt data := func (String.fromAscii $ bt.extract st en) data
    appendOr (data: Option String) (str: String) : Option String :=
      match data with
      | some res => some $ res.append str
      | none => some str

/-- Feeds data into the parser. This function takes a parser and a ByteArray, and processes the
data to update the parser state incrementally. -/
def Parser.feed (options: MessageConfig) (parser: Parser) (data: ByteArray) : IO (Except ParsingError Parser) := do
  let parser ← Grammar.parse parser data

  if parser.error = 22 then return .error .headerTooLong
  if parser.error ≠ 0 then return .error (.invalidMessage parser.error)

  let result ← checkRequest options parser.info

  return pure parser <* result
