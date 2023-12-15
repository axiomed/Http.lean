
open Std

def reset := "\u001B[0m"
def red   := "\u001B[31m"
def green := "\u001B[32m"

inductive Assertion where
| success (message : String) : Assertion
| failure (message : String) (expected : String) (result : String) : Assertion
deriving Repr


def Assertion.make [Repr α] [BEq α] (message : String) (expected : α) (result : α) : Assertion :=
  if (expected == result) then
    success message
  else
    failure message (Format.pretty (reprPrec expected 0)) (Format.pretty (reprPrec result 0))

def Assertion.run (assertion : Assertion) : IO Bool := do
  match assertion with
  | success message =>
      IO.println (green ++ "[OK]   " ++ message ++ reset)
      return true
  | failure message expected result =>
      IO.println (red   ++ "[FAIL] " ++ message ++ reset)
      IO.println ("       Expected: " ++ expected)
      IO.println ("       Result:   " ++ result)
      return false


def run (results : List Assertion) := 
  let rec go (remaining : List Assertion) (failed : Nat) : IO Nat := do
    match remaining with
    | [] => return failed
    | a :: [] => bind a.run (fun success => if success then return failed else return failed + 1)
    | a :: as => bind a.run (fun success => if success then (go as failed) else (go as (failed + 1)))

  do
    let failed <- go results 0
    if failed > 0 then IO.println s!"{failed} tests failed" else IO.println "All tests have passed!"
    if failed > 0 then IO.Process.exit 1

