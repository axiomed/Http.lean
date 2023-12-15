import Soda
import Soda.Data.ByteSlice
import Soda.Grape
import Soda.Grape.Text

import Http.Data.Headers
import «Tests».Framework

-- This instance might look like non-sense,
-- but it should be enough for real-world tasks as
-- `Result.cont` is never what you want to compare
instance [BEq a] : BEq (Result a) where
  beq
    | Result.done i is, Result.done j js => i == j && is.toASCIIString == js.toASCIIString
    | Result.error i is, Result.error j js => i == j && is == js
    | _, _ => false

def headersTests : List Assertion := [
  Assertion.make "Headers.isEmpty returns true on Request.empty"
    true
    Headers.empty.isEmpty,

  Assertion.make "Headers.headerParser can parse `foo: bar`"
    (Result.done ("foo", "bar") default)
    (Grape.run Headers.headerParser ("foo: bar".toSlice))
]
