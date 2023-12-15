# Http.lean

[![CI](https://github.com/axiomed/Http.lean/actions/workflows/push.yml/badge.svg)](https://github.com/axiomed/Http.lean/actions/workflows/push.yml)

A WIP implementation of HTTP protocol in [Lean 4](https://github.com/leanprover/lean4).

## The Goal

The goal of this project is to provide Lean community an HTTP Client and Server implementations as well
as working and sensible set of HTTP primitives.

The broader goal of [Axiomed](https://github.com/axiomed) initiative is to build an ecosystem of tools in Lean 4 that
software engineers need in their everyday tasks, such as HTTP libs, async frameworks, DB connectors, parsers etc.

If you think Lean 4 can shine not only as a theorem prover, but as a general purpose language - you're welcome to 
join the organization!

## Usage

Add Http to your `lakefile.lean`:

```lean
require Http from git "https://github.com/axiomed/Http.lean.git"
```

## Acknowledgements

This library is based on work [@algebraic-sofia](https://github.com/algebraic-sofia) has done for [her Rhina de Backends](https://blog.codeminer42.com/overcoming-challenges-and-crafting-in-the-uncharted-territory-of-lean4/) challenge.
