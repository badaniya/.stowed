# OpenCode Agent Instructions

## Language Server Protocol (LSP) Priority

**CRITICAL: When working with code, you MUST use Language Server Protocol (LSP) capabilities over text-based search tools.**

### LSP-First Rule

Before using `grep`, `glob`, `find`, `rg`, `ast_grep_search`, or any text-based search tool, check if an LSP tool is available:

- **Available LSP Tools:**
  - `lsp_goto_definition` - Jump to symbol definition
  - `lsp_find_references` - Find ALL usages across workspace
  - `lsp_symbols` - Get file outline or workspace symbol search
  - `lsp_diagnostics` - Get errors, warnings before build
  - `lsp_prepare_rename` - Check if rename is valid
  - `lsp_rename` - Rename symbol across entire workspace

### When to Use LSP vs Search Tools

| Task | Use LSP | Use grep/glob/ast-grep |
|------|---------|------------------------|
| Find function/class definition | `lsp_goto_definition` **REQUIRED** | Forbidden |
| Find all references to symbol | `lsp_find_references` **REQUIRED** | Forbidden |
| Navigate to type definition | `lsp_goto_definition` **REQUIRED** | Forbidden |
| Get file outline/structure | `lsp_symbols` **REQUIRED** | Forbidden |
| Search workspace for symbol | `lsp_symbols(scope='workspace')` **REQUIRED** | Forbidden |
| Rename symbol across files | `lsp_rename` **REQUIRED** | Forbidden |
| Get diagnostics/errors | `lsp_diagnostics` **REQUIRED** | Forbidden |
| Find files by name pattern | N/A | `Glob` Allowed |
| Search for literal strings | N/A | `Grep` Allowed |
| Non-code files (markdown, config) | N/A | Allowed |
| AST pattern matching (no LSP available) | N/A | `ast_grep_search` Allowed |

### LSP Tool Usage Examples

**Finding a definition:**
```
lsp_goto_definition(filePath="/path/to/file.go", line=42, character=15)
```

**Finding all usages of a symbol:**
```
lsp_find_references(filePath="/path/to/file.ts", line=10, character=8)
```

**Getting file outline:**
```
lsp_symbols(filePath="/path/to/file.py", scope="document")
```

**Searching workspace for symbol:**
```
lsp_symbols(filePath="/any/file.go", scope="workspace", query="MyFunction")
```

**Safe rename across codebase:**
```
lsp_prepare_rename(filePath="/path/to/file.lua", line=5, character=10)
lsp_rename(filePath="/path/to/file.lua", line=5, character=10, newName="newSymbolName")
```

### Fallback Order

When LSP is unavailable for a file type, use this precedence:

1. **LSP tools** - Always try first
2. **ast_grep_search** - AST-aware pattern matching (25 languages supported)
3. **Grep** - Content search with regex support
4. **Glob** - File discovery by pattern

### When Text Search IS Appropriate

- Searching for literal strings (error messages, log output)
- Finding files by name pattern
- Non-code files (markdown, yaml, json configs)
- Languages without LSP support in current environment
- Pattern matching across file types

## Rationale

LSP provides:
- **Semantic accuracy**: Understands code structure, not just text patterns
- **Cross-file navigation**: Follows imports/requires correctly
- **Refactoring safety**: Renames are scope-aware
- **Type information**: Knows actual types, not guessed patterns
- **Real-time diagnostics**: Catch errors before running build

Text search tools are:
- **Pattern-based**: Can miss dynamically generated names
- **Context-unaware**: Can't distinguish between string literals and actual code
- **Error-prone**: False positives/negatives are common
- **Slower for semantic queries**: Must scan entire codebase

## Enforcement

Agents **MUST NOT** use `grep`, `glob`, `find`, `rg`, `ast_grep_search` or similar tools when:
1. An LSP is available for the file type
2. The task involves code navigation or symbol lookup
3. Semantic understanding is required (definitions, references, types)

Violation of this rule should be treated as a **critical error** requiring immediate correction.

## Supported Languages (LSP Available)

The following languages have LSP support configured - use LSP tools for these:

- **Go**: gopls
- **Python**: pyright, pylsp
- **TypeScript/JavaScript**: typescript-language-server
- **Lua**: lua-language-server
- **Rust**: rust-analyzer
- **Shell/Bash**: bash-language-server
- **YAML**: yaml-language-server
- **JSON**: json-language-server
- **HTML/CSS**: vscode-html-language-server, vscode-css-language-server

For unlisted languages, check `lsp_diagnostics` first - if it returns results, LSP is available.
