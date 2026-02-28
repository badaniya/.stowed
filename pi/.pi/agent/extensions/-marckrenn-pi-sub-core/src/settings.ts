/**
 * Settings persistence for sub-core
 */

import * as path from "node:path";
import type { Settings } from "./settings-types.js";
import { getDefaultSettings, mergeSettings, SETTINGS_VERSION } from "./settings-types.js";
import { getStorage } from "./storage.js";
import { getLegacySettingsPath, getSettingsPath } from "./paths.js";
import { clearCache } from "./cache.js";

/**
 * Settings file path
 */
export const SETTINGS_PATH = getSettingsPath();
const LEGACY_SETTINGS_PATH = getLegacySettingsPath();

/**
 * In-memory settings cache
 */
let cachedSettings: Settings | undefined;

type LoadedSettings = {
	settings: Settings;
	loadedVersion: number;
};

/**
 * Ensure the settings directory exists
 */
function ensureSettingsDir(): void {
	const storage = getStorage();
	const dir = path.dirname(SETTINGS_PATH);
	storage.ensureDir(dir);
}

function loadSettingsFromDisk(settingsPath: string): LoadedSettings | null {
	const storage = getStorage();
	if (!storage.exists(settingsPath)) return null;
	const content = storage.readFile(settingsPath);
	if (!content) return null;
	const loaded = JSON.parse(content) as Partial<Settings>;
	const loadedVersion = typeof loaded.version === "number" ? loaded.version : 0;
	const merged = mergeSettings(loaded);
	return { settings: merged, loadedVersion };
}

function applyVersionMigration(settings: Settings, loadedVersion: number): { settings: Settings; needsSave: boolean } {
	if (loadedVersion < SETTINGS_VERSION) {
		clearCache();
		return { settings: { ...settings, version: SETTINGS_VERSION }, needsSave: true };
	}
	return { settings, needsSave: false };
}

function tryLoadSettings(settingsPath: string): LoadedSettings | null {
	try {
		return loadSettingsFromDisk(settingsPath);
	} catch (error) {
		console.error(`Failed to load settings from ${settingsPath}:`, error);
		return null;
	}
}

/**
 * Load settings from disk
 */
export function loadSettings(): Settings {
	if (cachedSettings) {
		return cachedSettings;
	}

	const diskSettings = tryLoadSettings(SETTINGS_PATH);
	if (diskSettings) {
		const { settings: next, needsSave } = applyVersionMigration(diskSettings.settings, diskSettings.loadedVersion);
		if (needsSave) {
			saveSettings(next);
		}
		cachedSettings = next;
		return cachedSettings;
	}

	const legacySettings = tryLoadSettings(LEGACY_SETTINGS_PATH);
	if (legacySettings) {
		const { settings: next } = applyVersionMigration(legacySettings.settings, legacySettings.loadedVersion);
		const saved = saveSettings(next);
		if (saved) {
			getStorage().removeFile(LEGACY_SETTINGS_PATH);
		}
		cachedSettings = next;
		return cachedSettings;
	}

	// Return defaults if file doesn't exist or failed to load
	cachedSettings = getDefaultSettings();
	return cachedSettings;
}

/**
 * Save settings to disk
 */
export function saveSettings(settings: Settings): boolean {
	const storage = getStorage();
	try {
		ensureSettingsDir();
		const content = JSON.stringify(settings, null, 2);
		storage.writeFile(SETTINGS_PATH, content);
		cachedSettings = settings;
		return true;
	} catch (error) {
		console.error(`Failed to save settings to ${SETTINGS_PATH}:`, error);
		return false;
	}
}

/**
 * Reset settings to defaults
 */
export function resetSettings(): Settings {
	const defaults = getDefaultSettings();
	saveSettings(defaults);
	return defaults;
}

/**
 * Get current settings (cached)
 */
export function getSettings(): Settings {
	return loadSettings();
}

/**
 * Clear the settings cache (force reload on next access)
 */
export function clearSettingsCache(): void {
	cachedSettings = undefined;
}
