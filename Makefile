###############################################################################
# Spectacular Plugin Development Makefile
###############################################################################
#
# DEVELOPMENT:
#   make link         - Link plugin to ~/.claude for testing
#   make unlink       - Remove plugin link from ~/.claude
#   make test-link    - Check if plugin is currently linked
#
# VERSION MANAGEMENT (no push):
#   make version VERSION=1.2.3  - Set specific version
#   make bump-patch             - Bump patch (1.2.3 -> 1.2.4), commit + tag
#   make bump-minor             - Bump minor (1.2.3 -> 1.3.0), commit + tag
#   make bump-major             - Bump major (1.2.3 -> 2.0.0), commit + tag
#
# RELEASE (bump + push):
#   make release-patch          - Bump patch and push to remote
#   make release-minor          - Bump minor and push to remote
#   make release-major          - Bump major and push to remote
#
###############################################################################

.PHONY: help link unlink test-link version bump-patch bump-minor bump-major release-patch release-minor release-major
.DEFAULT_GOAL := help

# Show available commands
help:
	@echo "Spectacular Plugin Development"
	@echo ""
	@echo "DEVELOPMENT:"
	@echo "  make link         - Link plugin to ~/.claude for testing"
	@echo "  make unlink       - Remove plugin link from ~/.claude"
	@echo "  make test-link    - Check if plugin is currently linked"
	@echo ""
	@echo "VERSION MANAGEMENT (no push):"
	@echo "  make version VERSION=1.2.3  - Set specific version"
	@echo "  make bump-patch             - Bump patch (1.2.3 -> 1.2.4), commit + tag"
	@echo "  make bump-minor             - Bump minor (1.2.3 -> 1.3.0), commit + tag"
	@echo "  make bump-major             - Bump major (1.2.3 -> 2.0.0), commit + tag"
	@echo ""
	@echo "RELEASE (bump + push):"
	@echo "  make release-patch          - Bump patch and push to remote"
	@echo "  make release-minor          - Bump minor and push to remote"
	@echo "  make release-major          - Bump major and push to remote"

# Link plugin to ~/.claude for testing
link:
	@echo "Linking spectacular plugin for development..."
	@# Remove any existing installations to avoid conflicts
	@if [ -e ~/.claude/plugins/marketplaces/spectacular ]; then \
		echo "  Removing marketplaces/spectacular (will be replaced with symlink)"; \
		rm -rf ~/.claude/plugins/marketplaces/spectacular; \
	fi
	@if [ -L ~/.claude/plugins/cache/spectacular ]; then \
		echo "  Removing existing cache symlink"; \
		rm -f ~/.claude/plugins/cache/spectacular; \
	fi
	@# Create symlink in marketplaces (higher priority than cache)
	@mkdir -p ~/.claude/plugins/marketplaces
	@ln -sf "$(PWD)" ~/.claude/plugins/marketplaces/spectacular
	@echo "✓ Linked. Restart Claude Code to load changes."
	@echo "  Plugin location: $(PWD)"
	@echo "  Symlink: ~/.claude/plugins/marketplaces/spectacular"

# Unlink plugin from ~/.claude
unlink:
	@echo "Unlinking spectacular plugin..."
	@rm -rf ~/.claude/plugins/marketplaces/spectacular
	@rm -f ~/.claude/plugins/cache/spectacular
	@echo "✓ Unlinked. Restart Claude Code to remove plugin."
	@echo ""
	@echo "Note: To reinstall from marketplace, restart Claude Code"
	@echo "      or manually clone to ~/.claude/plugins/marketplaces/spectacular"

# Test if link exists and is valid
test-link:
	@echo "Checking plugin installation..."
	@echo ""
	@if [ -L ~/.claude/plugins/marketplaces/spectacular ]; then \
		echo "✓ Development symlink active"; \
		echo "  Location: ~/.claude/plugins/marketplaces/spectacular"; \
		echo "  Target: $$(readlink ~/.claude/plugins/marketplaces/spectacular)"; \
		if [ -d ~/.claude/plugins/marketplaces/spectacular ]; then \
			echo "  Status: Valid"; \
			if [ -f ~/.claude/plugins/marketplaces/spectacular/.claude-plugin/plugin.json ]; then \
				VERSION=$$(jq -r '.version' ~/.claude/plugins/marketplaces/spectacular/.claude-plugin/plugin.json 2>/dev/null || echo "unknown"); \
				echo "  Version: $$VERSION"; \
			fi; \
		else \
			echo "  Status: Broken (target doesn't exist)"; \
		fi; \
	elif [ -d ~/.claude/plugins/marketplaces/spectacular ]; then \
		echo "⚠️  Production installation (not symlinked)"; \
		echo "  Location: ~/.claude/plugins/marketplaces/spectacular"; \
		if [ -f ~/.claude/plugins/marketplaces/spectacular/.claude-plugin/plugin.json ]; then \
			VERSION=$$(jq -r '.version' ~/.claude/plugins/marketplaces/spectacular/.claude-plugin/plugin.json 2>/dev/null || echo "unknown"); \
			echo "  Version: $$VERSION"; \
		fi; \
		echo "  Run 'make link' to switch to development mode"; \
	elif [ -L ~/.claude/plugins/cache/spectacular ]; then \
		echo "⚠️  Old cache symlink found (low priority)"; \
		echo "  Location: ~/.claude/plugins/cache/spectacular"; \
		echo "  Run 'make link' to move to marketplaces (higher priority)"; \
	else \
		echo "✗ Plugin not installed"; \
		echo "  Run 'make link' to install for development"; \
	fi

# Update version in plugin.json and marketplace.json (no git operations)
version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION required"; \
		echo "Usage: make version VERSION=1.2.3"; \
		exit 1; \
	fi
	@./scripts/update-version.sh $(VERSION)

# Bump patch version (1.2.3 -> 1.2.4) and create stacked branch
bump-patch:
	@CURRENT=$$(jq -r '.version' .claude-plugin/plugin.json); \
	NEW=$$(echo $$CURRENT | awk -F. '{$$NF = $$NF + 1;} 1' | sed 's/ /./g'); \
	echo "Bumping version: $$CURRENT -> $$NEW"; \
	./scripts/update-version.sh $$NEW && \
	git add .claude-plugin/*.json && \
	gs branch create "update-version-to-$$NEW" -m "Bump version to $$NEW" && \
	git tag "v$$NEW" && \
	echo "✓ Version bumped to $$NEW (branch created + tagged)"

# Bump minor version (1.2.3 -> 1.3.0) and create stacked branch
bump-minor:
	@CURRENT=$$(jq -r '.version' .claude-plugin/plugin.json); \
	NEW=$$(echo $$CURRENT | awk -F. '{$$2 = $$2 + 1; $$3 = 0;} 1' | sed 's/ /./g'); \
	echo "Bumping version: $$CURRENT -> $$NEW"; \
	./scripts/update-version.sh $$NEW && \
	git add .claude-plugin/*.json && \
	gs branch create "update-version-to-$$NEW" -m "Bump version to $$NEW" && \
	git tag "v$$NEW" && \
	echo "✓ Version bumped to $$NEW (branch created + tagged)"

# Bump major version (1.2.3 -> 2.0.0) and create stacked branch
bump-major:
	@CURRENT=$$(jq -r '.version' .claude-plugin/plugin.json); \
	NEW=$$(echo $$CURRENT | awk -F. '{$$1 = $$1 + 1; $$2 = 0; $$3 = 0;} 1' | sed 's/ /./g'); \
	echo "Bumping version: $$CURRENT -> $$NEW"; \
	./scripts/update-version.sh $$NEW && \
	git add .claude-plugin/*.json && \
	gs branch create "update-version-to-$$NEW" -m "Bump version to $$NEW" && \
	git tag "v$$NEW" && \
	echo "✓ Version bumped to $$NEW (branch created + tagged)"

# Bump patch version, create branch, and push (1.2.3 -> 1.2.4)
release-patch:
	@CURRENT=$$(jq -r '.version' .claude-plugin/plugin.json); \
	NEW=$$(echo $$CURRENT | awk -F. '{$$NF = $$NF + 1;} 1' | sed 's/ /./g'); \
	echo "Releasing version: $$CURRENT -> $$NEW"; \
	./scripts/update-version.sh $$NEW && \
	git add .claude-plugin/*.json && \
	gs branch create "update-version-to-$$NEW" -m "Bump version to $$NEW" && \
	git tag "v$$NEW" && \
	git push && \
	git push --tags && \
	echo "✓ Version $$NEW released (branch created + tagged + pushed)"

# Bump minor version, create branch, and push (1.2.3 -> 1.3.0)
release-minor:
	@CURRENT=$$(jq -r '.version' .claude-plugin/plugin.json); \
	NEW=$$(echo $$CURRENT | awk -F. '{$$2 = $$2 + 1; $$3 = 0;} 1' | sed 's/ /./g'); \
	echo "Releasing version: $$CURRENT -> $$NEW"; \
	./scripts/update-version.sh $$NEW && \
	git add .claude-plugin/*.json && \
	gs branch create "update-version-to-$$NEW" -m "Bump version to $$NEW" && \
	git tag "v$$NEW" && \
	git push && \
	git push --tags && \
	echo "✓ Version $$NEW released (branch created + tagged + pushed)"

# Bump major version, create branch, and push (1.2.3 -> 2.0.0)
release-major:
	@CURRENT=$$(jq -r '.version' .claude-plugin/plugin.json); \
	NEW=$$(echo $$CURRENT | awk -F. '{$$1 = $$1 + 1; $$2 = 0; $$3 = 0;} 1' | sed 's/ /./g'); \
	echo "Releasing version: $$CURRENT -> $$NEW"; \
	./scripts/update-version.sh $$NEW && \
	git add .claude-plugin/*.json && \
	gs branch create "update-version-to-$$NEW" -m "Bump version to $$NEW" && \
	git tag "v$$NEW" && \
	git push && \
	git push --tags && \
	echo "✓ Version $$NEW released (branch created + tagged + pushed)"
