# OpenCode Agent Instructions

## LSP-First Rule (CRITICAL)

**For any code symbol operation, ALWAYS use LSP tools (`lsp_goto_definition`, `lsp_find_references`, `lsp_symbols`, `lsp_diagnostics`, `lsp_rename`) INSTEAD OF grep/glob/find/rg/ast_grep_search.**

Using text search for symbol lookup when LSP is available is a critical error.

### Fallback Order (when LSP unavailable)

1. LSP tools — always try first
2. `ast_grep_search` — AST-aware pattern matching
3. `Grep` — content/regex search
4. `Glob` — file discovery by pattern

### Text Search IS Appropriate For

- Literal strings (error messages, log output, config values)
- File discovery by name pattern
- Non-code files (markdown, yaml, json)
- Languages where `lsp_diagnostics` returns no results
