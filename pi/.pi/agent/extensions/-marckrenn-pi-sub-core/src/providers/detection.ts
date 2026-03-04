/**
 * Provider detection helpers.
 */

import type { ProviderName } from "../types.js";
import { PROVIDERS } from "../types.js";
import { PROVIDER_METADATA } from "./metadata.js";

interface ProviderDetectionHint {
	provider: ProviderName;
	providerTokens: string[];
	modelTokens: string[];
}

const PROVIDER_DETECTION_HINTS: ProviderDetectionHint[] = PROVIDERS.map((provider) => {
	const detection = PROVIDER_METADATA[provider].detection ?? { providerTokens: [], modelTokens: [] };
	return {
		provider,
		providerTokens: detection.providerTokens,
		modelTokens: detection.modelTokens,
	};
});

/**
 * Detect the provider from model metadata.
 */
export function detectProviderFromModel(
	model: { provider?: string; id?: string } | undefined
): ProviderName | undefined {
	if (!model) return undefined;
	const providerValue = model.provider?.toLowerCase() || "";
	const idValue = model.id?.toLowerCase() || "";

	if (providerValue.includes("antigravity") || idValue.includes("antigravity")) {
		return "antigravity";
	}

	for (const hint of PROVIDER_DETECTION_HINTS) {
		if (hint.providerTokens.some((token) => providerValue.includes(token))) {
			return hint.provider;
		}
	}

	for (const hint of PROVIDER_DETECTION_HINTS) {
		if (hint.modelTokens.some((token) => idValue.includes(token))) {
			return hint.provider;
		}
	}

	return undefined;
}
