# Constitution Metadata

**Version:** 1
**Created:** 2025-01-27
**Previous:** None (initial version)

## Changelog

### Version 1 - Initial Constitution
**What Changed:**
- Established initial architectural rules for spectacular plugin development
- Defined mandatory patterns for skill and command creation
- Set testing requirements using RED-GREEN-REFACTOR approach
- Documented tech stack (markdown, YAML, bash)

**Rationale:**
This is the initial constitution for the spectacular plugin. As a Claude Code plugin, spectacular is pure documentation (markdown files) rather than executable code. However, the documentation itself is load-bearing - commands and skills directly influence how Claude behaves.

The RED-GREEN-REFACTOR approach is critical here: Claude tends to rationalize away rules when they're inconvenient. By adopting TDD-style patterns from superpowers (write test first, watch it fail, minimal code to pass), we ensure that skills actually enforce the behaviors they document.

Key principles:
- **Process as code**: Skills are process documentation that Claude executes
- **Test before trust**: Use testing-skills-with-subagents to validate skills work under pressure
- **Rigidity prevents rationalization**: Strict rules (with rationalization tables) prevent Claude from taking shortcuts
- **Metaskills are mandatory**: writing-skills, testing-skills-with-subagents ensure quality

Without these foundational rules, spectacular would drift from a disciplined workflow tool into vague suggestions that Claude ignores when convenient.
