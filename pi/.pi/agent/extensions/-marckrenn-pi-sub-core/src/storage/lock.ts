/**
 * File lock helpers for storage-backed locks.
 */

import { getStorage } from "../storage.js";

export function tryAcquireFileLock(lockPath: string, staleAfterMs: number): boolean {
	const storage = getStorage();
	try {
		if (storage.writeFileExclusive(lockPath, String(Date.now()))) {
			return true;
		}
	} catch {
		// ignore
	}

	try {
		if (storage.exists(lockPath)) {
			const lockContent = storage.readFile(lockPath) ?? "";
			const lockTime = parseInt(lockContent, 10);
			if (Date.now() - lockTime > staleAfterMs) {
				storage.writeFile(lockPath, String(Date.now()));
				return true;
			}
		}
	} catch {
		// Ignore, lock is held by another process
	}

	return false;
}

export function releaseFileLock(lockPath: string): void {
	const storage = getStorage();
	try {
		if (storage.exists(lockPath)) {
			storage.removeFile(lockPath);
		}
	} catch {
		// Ignore
	}
}

export async function waitForLockRelease(
	lockPath: string,
	maxWaitMs: number,
	pollMs: number = 100
): Promise<boolean> {
	const storage = getStorage();
	const startTime = Date.now();

	while (Date.now() - startTime < maxWaitMs) {
		await new Promise((resolve) => setTimeout(resolve, pollMs));
		if (!storage.exists(lockPath)) {
			return true;
		}
	}

	return false;
}
