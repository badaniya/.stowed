/**
 * Provider status handling helpers.
 */

import type { Dependencies, ProviderName, ProviderStatus } from "../types.js";
import { fetchProviderStatus } from "../status.js";
import { PROVIDER_METADATA } from "./metadata.js";

export function providerHasStatus(
	provider: ProviderName,
	providerInstance?: { fetchStatus?: (deps: Dependencies) => Promise<ProviderStatus> }
): boolean {
	return Boolean(providerInstance?.fetchStatus) || Boolean(PROVIDER_METADATA[provider]?.status);
}

export async function fetchProviderStatusWithFallback(
	provider: ProviderName,
	providerInstance: { fetchStatus?: (deps: Dependencies) => Promise<ProviderStatus> },
	deps: Dependencies
): Promise<ProviderStatus> {
	if (providerInstance.fetchStatus) {
		return providerInstance.fetchStatus(deps);
	}
	return fetchProviderStatus(provider, deps);
}
