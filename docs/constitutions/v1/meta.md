# Constitution Metadata

**Version:** 1

**Created:** 2025-10-23

**Previous Version:** None (initial version)

## Purpose

This is the initial constitution for the Spectacular Claude Code plugin. It establishes foundational architectural rules, mandatory patterns, and technical standards for plugin development.

## What This Version Establishes

### Architecture
- Commands vs Skills separation of concerns
- Plugin structure with `.claude-plugin/`, `commands/`, and `skills/` directories
- Delegation pattern: commands orchestrate, skills implement

### Mandatory Patterns
- Skills must follow superpowers format with frontmatter and structured sections
- Commands must use YAML frontmatter with description field
- All workflows must use TodoWrite for multi-step processes
- Process documentation follows RED-GREEN-REFACTOR principle

### Tech Stack
- Superpowers plugin as core dependency
- Git-spice for stacked branch management
- Markdown for all documentation
- No build/compile step (pure documentation)

### File Structure
- Skill files at `skills/{name}/SKILL.md`
- Command files at `commands/{name}.md`
- Constitution versioning in `docs/constitutions/v{N}/`
- Symlink pattern for version abstraction

### Testing Approach
- Manual testing via command invocation in test repositories
- Skills testing via `testing-skills-with-subagents` skill
- No traditional test suite (documentation-only project)

## Changelog

**v1 (2025-10-23)** - Initial constitution
- Establishes plugin architecture and file structure
- Defines mandatory patterns for commands and skills
- Documents tech stack dependencies
- Sets file naming conventions
- Defines validation approach

## Rationale

This constitution exists to ensure consistency across commands and skills as the plugin evolves. By documenting foundational rules explicitly:

1. **New contributors** can understand architectural boundaries without reading all existing code
2. **Breaking changes** become visible through version increments
3. **Pattern violations** can be identified by comparing against constitutional rules
4. **Architectural decisions** are preserved with rationale, not lost to git history

The versioning approach enables safe evolution: when fundamental patterns change (e.g., switching to different plugin format), we create v2 while keeping v1 immutable for historical reference.
