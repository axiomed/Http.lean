import Http.Data.Headers
import Http.Data.Version
import Http.Data.Method
import Http.Data.Status
import Http.Data.Body

import Http.IO.Buffer

namespace Http.Data
open Http.IO

/-! HTTP [Response] with a bunch of parts like version and status and a body with the α type
that can be anything that can be transformed into a byte sequence -/
structure Response where
  status       : Status
  version      : Version
  headers      : Headers

namespace Response

def empty : Response :=
  Response.mk Status.ok Version.v11 Inhabited.default

instance : ToString Response where
  toString r :=
    let headerString := toString r.version ++ " " ++ toString r.status.toCode ++ " " ++ r.status.canonicalReason ++ "\r\n" ++ toString r.headers
    headerString ++ "\r\n\r\n"

instance : Serialize Response where
  serialize res := BufferBuilder.write (toString res)
