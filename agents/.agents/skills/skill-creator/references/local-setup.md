# Badaniya's Skill Infrastructure Setup

This reference documents the local skill infrastructure and overrides the generic packaging/installation steps.

## Directory Structure & Symlink Chain

```
~/.private_skills/              ← Source of truth (actual skill files)
        │
        └── skill-name/
            ├── SKILL.md
            └── references/
        
~/.agents/skills/               ← Central hub (symlinks to ~/.private_skills/ for private,
        │                          actual directories for public skills)
        └── skill-name -> ~/.private_skills/skill-name
        
        ↓ (all agents symlink to ~/.agents/skills/)
        
├── ~/.config/opencode/skills/  ← OpenCode
│   └── skill-name -> ~/.agents/skills/skill-name
│
├── ~/.copilot/skills/          ← GitHub Copilot
│   └── skill-name -> ~/.agents/skills/skill-name
│
└── ~/.config/goose/skills/     ← Goose
    └── skill-name -> ~/.agents/skills/skill-name
```

**Key benefit:** Edit once in `~/.private_skills/`, all 3 agents see changes immediately.

## Skill Categories

### Private Skills (work-specific, sensitive)
Location: `~/.private_skills/`

These contain company-specific knowledge, credentials patterns, or internal tooling:
- jenkins-access (BASE - Jenkins API foundation)
- nvo-branch-calculator (BASE - branch parameter calculation)
- nvo-ngaio-deploy (depends on: jenkins-access, nvo-branch-calculator)
- pull-request-conventions (depends on: jenkins-access, nvo-branch-calculator)
- nvo-coding-guidelines
- cloud-testbed-access
- querying-loki-logs
- teleport-kubernetes

### Public/Shared Skills (generic, reusable)
Location: `~/.agents/skills/` (as directories, not symlinks)

These are general-purpose skills that could be shared:
- brainstorming
- executing-plans
- find-skills
- mermaid-diagrams
- skill-creator
- subagent-driven-development
- systematic-debugging
- test-driven-development
- writing-plans

## Skill Dependencies

When skills depend on other skills (base skills), document in YAML frontmatter description:

```yaml
---
name: my-skill
description: |
  ...
  **Depends on:** jenkins-access, nvo-branch-calculator
---
```

Current dependency tree:
```
jenkins-access (BASE)    nvo-branch-calculator (BASE)    nvo-ngaio-access (BASE)
     │                          │                              │
     ├──────────────────────────┼──────────────────────────────┤
     ↓                          ↓                              ↓
nvo-ngaio-deploy ───────────────┴──────────────────────────────┘
     
nvo-pull-request ← jenkins-access, nvo-branch-calculator, nvo-github-access
```

## Modified Workflow

### Step 3: Initializing a NEW Skill

**For private skills** (work-specific):

```bash
# Initialize directly in ~/.private_skills/
python3 ~/.agents/skills/skill-creator/scripts/init_skill.py <skill-name> --path ~/.private_skills/

# Create full symlink chain (all 3 agents)
link_private_skill <skill-name>
```

**For public skills** (generic, shareable):

```bash
# Initialize directly in ~/.agents/skills/
python3 ~/.agents/skills/skill-creator/scripts/init_skill.py <skill-name> --path ~/.agents/skills/

# Create symlinks to all agents
link_public_skill <skill-name>
```

### Step 5: Packaging and Installing

**IMPORTANT:** In this setup, packaging is optional. The symlink structure means skills are "live" - edits to `~/.private_skills/` or `~/.agents/skills/` are immediately available to all agents.

**When to package:**
- Sharing skills with others
- Creating backups
- Version control/releases

**Installation from .skill file:**

```bash
# For private skills - unzip to private_skills
unzip <skill-name>.skill -d ~/.private_skills/
link_private_skill <skill-name>

# For public skills - unzip to agents/skills
unzip <skill-name>.skill -d ~/.agents/skills/
link_public_skill <skill-name>
```

## Shell Functions

These functions are already installed in `~/.private_zsh_functions.zsh`:

| Function | Description |
|----------|-------------|
| `link_private_skill <name>` | Link a private skill from `~/.private_skills/` to all 3 agents |
| `link_public_skill <name>` | Link a public skill from `~/.agents/skills/` to all 3 agents |
| `unlink_skill <name>` | Remove skill symlinks from all agents (source preserved) |
| `verify_skill <name>` | Check a single skill's symlink status across all agents |
| `verify_all_skills` | Show status matrix for all skills across all agents |
| `sync_all_skills` | Ensure all skills in hub are linked to all agents |
| `list_skills` | List private/public skills and agent counts |

## Quick Commands

```bash
# List all skills and their types
list_skills

# Verify a skill's symlink chain
verify_skill jenkins-access

# Verify ALL skills across all agents
verify_all_skills

# Sync all skills from hub to all agents
sync_all_skills

# Link a new private skill to all agents
link_private_skill my-new-skill

# Link a new public skill to all agents  
link_public_skill my-public-skill

# Remove skill from all agents (source preserved)
unlink_skill old-skill
```

## File Locations Reference

| Purpose | Path |
|---------|------|
| Skill source (private) | `~/.private_skills/<skill>/` |
| Skill source (public) | `~/.agents/skills/<skill>/` |
| Central hub | `~/.agents/skills/` |
| OpenCode skill dir | `~/.config/opencode/skills/` |
| Copilot skill dir | `~/.copilot/skills/` |
| Goose skill dir | `~/.config/goose/skills/` |
| Skill-creator scripts | `~/.agents/skills/skill-creator/scripts/` |
| Package output (default) | Current working directory |

## Adding a New Agent

If you add another AI agent that reads skills from a directory:

```bash
# 1. Create the agent's skill directory
mkdir -p ~/.config/<new-agent>/skills/

# 2. Update the shell functions above to include the new path

# 3. Link all existing skills
for skill in $(ls ~/.agents/skills/); do
  ln -sf ~/.agents/skills/$skill ~/.config/<new-agent>/skills/$skill
done
```
