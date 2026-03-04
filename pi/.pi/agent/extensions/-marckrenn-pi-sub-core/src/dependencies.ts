/**
 * Default dependencies using real implementations
 */

import * as fs from "node:fs";
import * as os from "node:os";
import { execFileSync } from "node:child_process";
import type { ExecFileSyncOptionsWithStringEncoding } from "node:child_process";
import type { Dependencies } from "./types.js";

/**
 * Create default dependencies using Node.js APIs
 */
export function createDefaultDependencies(): Dependencies {
	return {
		fetch: globalThis.fetch,
		readFile: (path: string) => {
			try {
				return fs.readFileSync(path, "utf-8");
			} catch {
				return undefined;
			}
		},
		fileExists: (path: string) => {
			try {
				return fs.existsSync(path);
			} catch {
				return false;
			}
		},
		execFileSync: (file: string, args: string[], options?: ExecFileSyncOptionsWithStringEncoding) => {
			return execFileSync(file, args, options) as string;
		},
		homedir: () => os.homedir(),
		env: process.env,
	};
}
