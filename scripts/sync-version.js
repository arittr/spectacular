#!/usr/bin/env node

/**
 * Sync version from package.json to .claude-plugin/*.json files
 * This runs automatically during `npm version` via the "version" script
 */

const fs = require('fs');
const path = require('path');

// Read version from package.json
const packageJson = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../package.json'), 'utf8')
);
const version = packageJson.version;

console.log(`Syncing version ${version} to .claude-plugin/ files...`);

// Update plugin.json
const pluginJsonPath = path.join(__dirname, '../.claude-plugin/plugin.json');
const pluginJson = JSON.parse(fs.readFileSync(pluginJsonPath, 'utf8'));
pluginJson.version = version;
fs.writeFileSync(pluginJsonPath, JSON.stringify(pluginJson, null, 2) + '\n');
console.log(`✓ Updated .claude-plugin/plugin.json`);

// Update marketplace.json
const marketplaceJsonPath = path.join(__dirname, '../.claude-plugin/marketplace.json');
const marketplaceJson = JSON.parse(fs.readFileSync(marketplaceJsonPath, 'utf8'));
marketplaceJson.plugins[0].version = version;
fs.writeFileSync(marketplaceJsonPath, JSON.stringify(marketplaceJson, null, 2) + '\n');
console.log(`✓ Updated .claude-plugin/marketplace.json`);

console.log(`\n✅ Version ${version} synced successfully`);
