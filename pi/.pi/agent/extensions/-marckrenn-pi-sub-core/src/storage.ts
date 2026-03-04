/**
 * Storage abstraction for settings and cache persistence.
 */

import * as fs from "node:fs";
import * as path from "node:path";

export interface StorageAdapter {
	readFile(path: string): string | undefined;
	writeFile(path: string, contents: string): void;
	writeFileExclusive(path: string, contents: string): boolean;
	exists(path: string): boolean;
	removeFile(path: string): void;
	ensureDir(path: string): void;
}

export function createFsStorage(): StorageAdapter {
	return {
		readFile(filePath: string): string | undefined {
			try {
				return fs.readFileSync(filePath, "utf-8");
			} catch {
				return undefined;
			}
		},
		writeFile(filePath: string, contents: string): void {
			fs.writeFileSync(filePath, contents, "utf-8");
		},
		writeFileExclusive(filePath: string, contents: string): boolean {
			try {
				fs.writeFileSync(filePath, contents, { flag: "wx" });
				return true;
			} catch {
				return false;
			}
		},
		exists(filePath: string): boolean {
			return fs.existsSync(filePath);
		},
		removeFile(filePath: string): void {
			try {
				fs.unlinkSync(filePath);
			} catch {
				// Ignore remove errors
			}
		},
		ensureDir(dirPath: string): void {
			fs.mkdirSync(path.resolve(dirPath), { recursive: true });
		},
	};
}

let activeStorage: StorageAdapter = createFsStorage();

export function getStorage(): StorageAdapter {
	return activeStorage;
}

export function setStorage(storage: StorageAdapter): void {
	activeStorage = storage;
}
