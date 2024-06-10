import Http.Classes.FromString
import Lean.Data.Trie

namespace Http.Classes

/-- Standard type class is useful for things that have a custom and a standard string
representation -/
class Standard (α : Type) (β: outParam Type) where
  custom : String → α
  standard : β → α

def Standard.parse [str: FromString β] [inst: Standard α β] (input: String) : α :=
  match str.trie.find? input with
  | some res => inst.standard res
  | none => inst.custom input
