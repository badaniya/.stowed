workspaces:
  - name: "${WORKSPACE_NAME}"
    root: ${WORKTREE_DIR}
    tabs:
      # ── 1 - Agent ────────────────────────────────────────────────────
      # Claude Code, already cd'd into the new worktree on its own branch
      - label: 1 - Agent
        panes:
          - command: claude

      # ── 2 - Edit ─────────────────────────────────────────────────────
      # Neovim, same worktree
      - label: 2 - Edit
        panes:
          - command: nvim
