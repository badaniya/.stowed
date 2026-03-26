---
description: Self reflection with skills optimization
agent: nvo-developer
model: github-copilot/claude-opus-4.6
---

Run a self-reflection on this session:

# DO'S
- Evaluate the session and optimize all skills utilized using the skill-creator, tokenscope skills.
- Use a sub-agent, one per skill that needs to be refactored and optimized. Ensure that sub-agent triggering instruction is generic for any agent harness to understand.
- Ensure that the skills are RELIABLE (skill triggering, referencing resources/examples, and scripts execution MUST be followed).
- Optimize by reducing the number of tool calls by the agent and sub-agents. This takes PRIORITY over token optimizations.
- Any interruptions and course corrections by the user for skill/workflow corrections MUST be incorporated back into the skill.
- Validate the skill is within specification and refactor accordingly, BUT correct triggering and progressive discloure MUST be maintained.
- Ensure skill compliance with standards with the extra restriction that SKILLS.md should be under 200 lines.
- Limit skill references to 200 lines as well and refactor to preserve domain knowledge.

# DONT'S
- Hard-code credentials in the skills. ONLY use the skill config ENV variables or generic labels and terms if no ENV exist.
- Hard-code the credentials file name. ONLY use the skill config ENV variable for the credentials file.
- Run evals. ONLY do a skill optimization unless specifically prompted to run a eval.
