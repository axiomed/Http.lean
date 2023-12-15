import Lake
open Lake DSL

package «Http» where
  -- add package configuration options here

lean_lib «Http» where
  -- add library configuration options here

lean_lib «Tests» where
  -- add library configuration options here

lean_exe «tests» where
  root := `Tests
  supportInterpreter := true

require soda   from git "https://github.com/algebraic-sofia/soda.git"
require Socket from git "https://github.com/KislyjKisel/Socket.lean.git"
