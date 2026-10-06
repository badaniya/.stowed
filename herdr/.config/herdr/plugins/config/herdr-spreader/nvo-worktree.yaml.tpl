workspaces:
  - name: "${WORKSPACE_NAME}"
    root: ${WORKTREE_DIR}
    focus: true
    tabs:
      # Claude Code, already cd'd into the new worktree on its own branch
      - label: 1 - Agent
        panes:
          - command: claude
