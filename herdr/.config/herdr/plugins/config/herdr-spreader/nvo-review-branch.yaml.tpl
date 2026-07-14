workspaces:
  - name: NVO-REVIEW
    root: ~/workspace/badaniya/NVO-REVIEW
    tabs:
      # ── 1 - Agent ────────────────────────────────────────────────────
      # pi agent for the review session — lands in GoDCApp/NVO on the branch
      - label: 1 - Agent
        panes:
          - cwd: GoDCApp/NVO
            command: pi

      # ── 2 - JIRA/PR ──────────────────────────────────────────────────
      # Top: Jira ticket details
      # Bottom: PR overview with comments
      - label: 2 - JIRA/PR
        panes:
          - command: jira issue view ${TICKET}

          - split: right
            ratio: 0.5
            cwd: GoDCApp
            command: gh pr view ${BRANCH} --comments
            focus: true

      # ── 3 - Diff ─────────────────────────────────────────────────────
      # Top: PR diff piped through hunk for a readable patch view
      # Bottom: Neovim opened on every file changed in the PR
      - label: 3 - Diff
        panes:
          - cwd: GoDCApp
            command: >-
              gh pr diff ${BRANCH}
              | hunk patch -

          - split: down
            ratio: 0.5
            cwd: GoDCApp
            command: >-
              nvim $(gh pr diff ${BRANCH} --name-only | tr '\n' ' ')
            focus: true

      # ── 4 - Build ────────────────────────────────────────────────────
      # Top full-width: NVO service log tail → loggo
      - label: 4 - Build
        panes:
          - command: >-
              tail -F
              /var/log/network/network-server.log
              /var/log/edge/edge-server.log
              /var/log/scheduler/scheduler-server.log
              /var/log/runonce/runonce-server.log
              /var/log/system/system-server.log
              | loggo stream -t ~/.private-nvo-loggo.tpl

          # Bottom row (~42% height) — left: lazydocker
          - split: down
            ratio: 0.42
            command: lazydocker

          # Bottom-right column (3 equal-height panes) — top: PCM shell
          - split: right
            ratio: 0.65
            cwd: PlatformCommonModels/scripts/development
            command: git fetch --all

          # Bottom-right mid: PlatformServices shell
          - split: down
            ratio: 0.33
            cwd: PlatformServices/scripts/development
            command: git fetch --all

          # Bottom-right bottom: GoDCApp NVO shell — branch already checked out
          - split: down
            ratio: 0.5
            cwd: GoDCApp/NVO/scripts/development
            focus: true
