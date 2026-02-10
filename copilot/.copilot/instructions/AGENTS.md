# Agent Instructions for .stowed Repository

## Language Server Protocol (LSP) Priority

**CRITICAL: When working with code, you MUST use Language Server Protocol (LSP) capabilities if available, rather than text-based search tools.**

### LSP-First Rule

Before using `grep`, `glob`, `find`, or text-based search tools, check if an LSP is available for the language:

- **Available LSPs in this repository:**
  - **Neovim Lua**: lua-language-server (via nvim LSP)
  - **Shell scripts**: bash-language-server
  - **Python**: pyright or pylsp
  - **Go**: gopls
  - **YAML/JSON**: yaml-language-server, json-language-server

### When to Use LSP vs Search Tools

| Task | Use LSP | Use grep/glob |
|------|---------|---------------|
| Find function/class definition | ✅ REQUIRED | ❌ Forbidden |
| Find all references to symbol | ✅ REQUIRED | ❌ Forbidden |
| Navigate to type definition | ✅ REQUIRED | ❌ Forbidden |
| Find implementations | ✅ REQUIRED | ❌ Forbidden |
| Get function signature/hover info | ✅ REQUIRED | ❌ Forbidden |
| Rename symbol across files | ✅ REQUIRED | ❌ Forbidden |
| Find files by name pattern | ❌ N/A | ✅ Allowed |
| Search for literal strings/patterns | ❌ N/A | ✅ Allowed |
| Non-code files (configs, markdown) | ❌ N/A | ✅ Allowed |

### How to Use LSP

1. **Start an async bash session** with the appropriate LSP client (e.g., nvim in headless mode)
2. **Send LSP commands** via write_bash to:
   - Go to definition: `:lua vim.lsp.buf.definition()`
   - Find references: `:lua vim.lsp.buf.references()`
   - Get hover info: `:lua vim.lsp.buf.hover()`
   - Rename symbol: `:lua vim.lsp.buf.rename()`
3. **Parse the structured output** instead of regex matching

### Example: Finding Function Definition

**❌ WRONG (text search):**
```bash
grep -r "function myFunction" .
```

**✅ CORRECT (LSP):**
```bash
# Start nvim with LSP
nvim --headless -c "lua vim.lsp.buf.definition()" file.lua

# Or use LSP client directly
lua-language-server --check .
```

## Rationale

LSPs provide:
- **Semantic accuracy**: Understands code structure, not just text patterns
- **Cross-file navigation**: Follows imports/requires correctly
- **Refactoring safety**: Renames are scope-aware
- **Type information**: Knows actual types, not guessed patterns

Text search tools are:
- **Pattern-based**: Can miss dynamically generated names
- **Context-unaware**: Can't distinguish between string literals and actual code
- **Error-prone**: False positives/negatives common

## Enforcement

Agents **MUST NOT** use `grep`, `glob`, `find`, `rg`, or similar tools when:
1. An LSP is available for the file type
2. The task involves code navigation or symbol lookup
3. Semantic understanding is required

Violation of this rule should be treated as a critical error requiring immediate correction.

