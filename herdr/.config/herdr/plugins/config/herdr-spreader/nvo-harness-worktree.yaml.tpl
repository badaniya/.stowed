workspaces:
  - name: "${WORKSPACE_NAME}"
    root: ${PROJECT_DIR}
    focus: true
    tabs:
      # ── 1 - Agent ────────────────────────────────────────────────────
      # Claude Code, cd'd into the project dir containing all four worktrees
      - label: 1 - Agent
        panes:
          - command: claude
