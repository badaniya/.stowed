import test from "node:test";
import assert from "node:assert/strict";
import { createUsageController } from "../src/usage/controller.js";
import { getDefaultSettings } from "../src/settings-types.js";
import { CACHE_PATH } from "../src/cache.js";
import { getStorage, setStorage, type StorageAdapter } from "../src/storage.js";
import { createDeps, createJsonResponse, getAuthPath } from "./helpers.js";
import type { UsageSnapshot } from "../src/types.js";

function createMemoryStorage(): { storage: StorageAdapter; files: Map<string, string> } {
	const files = new Map<string, string>();
	const storage: StorageAdapter = {
		readFile: (filePath) => files.get(filePath),
		writeFile: (filePath, contents) => {
			files.set(filePath, contents);
		},
		writeFileExclusive: (filePath, contents) => {
			if (files.has(filePath)) return false;
			files.set(filePath, contents);
			return true;
		},
		exists: (filePath) => files.has(filePath),
		removeFile: (filePath) => {
			files.delete(filePath);
		},
		ensureDir: () => {},
	};
	return { storage, files };
}

test("refresh clears state when provider is not detected", async () => {
	const { deps } = createDeps({
		fetch: async () => createJsonResponse({}),
	});
	const controller = createUsageController(deps);
	const settings = getDefaultSettings();
	const state = {
		currentProvider: "copilot" as const,
		cachedUsage: { provider: "copilot", displayName: "Copilot", windows: [] },
		lastSuccessAt: Date.now(),
		providerCycleIndex: 0,
	};
	const updates: Array<{ provider?: string }> = [];

	await controller.refresh({ model: undefined } as never, settings, state, (update) => updates.push(update));

	assert.equal(state.currentProvider, undefined);
	assert.equal(state.cachedUsage, undefined);
	assert.equal(updates.at(-1)?.provider, undefined);
});

test("refresh falls back to cached usage on fetch error", async () => {
	const { storage, files } = createMemoryStorage();
	const originalStorage = getStorage();
	setStorage(storage);

	try {
		const home = "/home/test";
		const { deps, files: depFiles } = createDeps({
			fetch: async () => createJsonResponse({}, { ok: false, status: 500 }),
			homedir: home,
		});
		depFiles.set(getAuthPath(home), JSON.stringify({ "github-copilot": { refresh: "token" } }));

		const cachedUsage: UsageSnapshot = {
			provider: "copilot",
			displayName: "Copilot Plan",
			windows: [{ label: "Month", usedPercent: 10 }],
		};
		const cacheEntry = {
			fetchedAt: Date.now() - 5000,
			usage: cachedUsage,
			status: { indicator: "none" as const },
		};
		files.set(CACHE_PATH, JSON.stringify({ copilot: cacheEntry }));

		const controller = createUsageController(deps);
		const settings = getDefaultSettings();
		settings.behavior.minRefreshInterval = 0;
		settings.providers.copilot.enabled = "on";

		const state = { providerCycleIndex: 0 };
		const updates: Array<{ usage?: UsageSnapshot }> = [];

		await controller.refresh(
			{ model: { provider: "github" } } as never,
			settings,
			state,
			(update) => updates.push(update),
			{ force: true },
		);

		const finalUsage = updates.at(-1)?.usage;
		assert.ok(finalUsage);
		assert.equal(finalUsage?.windows.length, 1);
		assert.equal(finalUsage?.status?.indicator, "minor");
		assert.equal(finalUsage?.error?.code, "HTTP_ERROR");
	} finally {
		setStorage(originalStorage);
	}
});
