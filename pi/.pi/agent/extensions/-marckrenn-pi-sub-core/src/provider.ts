/**
 * Provider interface and registry
 */

import type { Dependencies, ProviderName, ProviderStatus, UsageSnapshot } from "./types.js";

/**
 * Interface for a usage provider
 */
export interface UsageProvider {
	readonly name: ProviderName;
	readonly displayName: string;

	/**
	 * Fetch current usage data for this provider
	 */
	fetchUsage(deps: Dependencies): Promise<UsageSnapshot>;

	/**
	 * Fetch current status for this provider (optional)
	 */
	fetchStatus?(deps: Dependencies): Promise<ProviderStatus>;

	/**
	 * Check if credentials are available (optional)
	 */
	hasCredentials?(deps: Dependencies): boolean;
}

/**
 * Base class for providers with common functionality
 */
export abstract class BaseProvider implements UsageProvider {
	abstract readonly name: ProviderName;
	abstract readonly displayName: string;

	abstract fetchUsage(deps: Dependencies): Promise<UsageSnapshot>;

	hasCredentials(_deps: Dependencies): boolean {
		return true;
	}

	/**
	 * Create an empty snapshot with an error
	 */
	protected emptySnapshot(error?: import("./types.js").UsageError): UsageSnapshot {
		return {
			provider: this.name,
			displayName: this.displayName,
			windows: [],
			error,
		};
	}

	/**
	 * Create a snapshot with usage data
	 */
	protected snapshot(data: Partial<Omit<UsageSnapshot, "provider" | "displayName">>): UsageSnapshot {
		return {
			provider: this.name,
			displayName: this.displayName,
			windows: [],
			...data,
		};
	}
}
