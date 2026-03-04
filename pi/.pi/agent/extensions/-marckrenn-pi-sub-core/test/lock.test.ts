import test from "node:test";
import assert from "node:assert/strict";
import { getStorage, setStorage, type StorageAdapter } from "../src/storage.js";
import { tryAcquireFileLock, releaseFileLock } from "../src/storage/lock.js";

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

test("tryAcquireFileLock overrides stale locks", () => {
	const { storage, files } = createMemoryStorage();
	const originalStorage = getStorage();
	setStorage(storage);

	try {
		const lockPath = "/tmp/lock";
		assert.ok(tryAcquireFileLock(lockPath, 10));
		files.set(lockPath, String(Date.now() - 1000));
		assert.ok(tryAcquireFileLock(lockPath, 10));
		releaseFileLock(lockPath);
		assert.equal(files.has(lockPath), false);
	} finally {
		setStorage(originalStorage);
	}
});
