/**
 * Status polling for providers
 */

import type { Dependencies, ProviderName, ProviderStatus, StatusIndicator } from "./types.js";
import type { ProviderStatusConfig } from "./providers/metadata.js";
import { GOOGLE_STATUS_URL, GEMINI_PRODUCT_ID, API_TIMEOUT_MS } from "./config.js";
import { PROVIDER_METADATA } from "./providers/metadata.js";
import { createTimeoutController } from "./utils.js";

type StatusPageStatusConfig = Extract<ProviderStatusConfig, { type: "statuspage" }>;

interface StatusPageSummary {
	status?: {
		indicator?: string;
		description?: string;
	};
	components?: Array<{
		id?: string;
		name?: string;
		status?: string;
	}>;
}

interface StatusPageStatus {
	indicator?: string;
	description?: string;
}

interface StatusPageResponse {
	status?: StatusPageStatus;
}

function toSummaryUrl(url: string): string {
	if (url.endsWith("/summary.json")) return url;
	if (url.endsWith("/status.json")) {
		return `${url.slice(0, -"/status.json".length)}/summary.json`;
	}
	if (!url.endsWith("/")) return `${url}/summary.json`;
	return `${url}summary.json`;
}

function isComponentMatch(component: { id?: string; name?: string }, config?: StatusPageStatusConfig): boolean {
	if (!config?.component) return false;

	if (config.component.id && component.id) {
		return component.id === config.component.id;
	}

	if (config.component.name && component.name) {
		return component.name.trim().toLowerCase() === config.component.name.trim().toLowerCase();
	}

	return false;
}

function mapStatusIndicator(indicator?: string): StatusIndicator {
	switch (indicator) {
		case "none":
			return "none";
		case "minor":
			return "minor";
		case "major":
			return "major";
		case "critical":
			return "critical";
		case "maintenance":
			return "maintenance";
		default:
			return "unknown";
	}
}

function mapComponentStatus(indicator?: string): StatusIndicator {
	switch ((indicator || "").toLowerCase()) {
		case "operational":
			return "none";
		case "under_maintenance":
			return "maintenance";
		case "degraded_performance":
			return "minor";
		case "partial_outage":
			return "major";
		case "major_outage":
			return "critical";
		default:
			return "unknown";
	}
}

function formatComponentLabel(rawStatus?: string): string {
	switch ((rawStatus || "").toLowerCase()) {
		case "operational":
			return "Operational";
		case "under_maintenance":
			return "Under maintenance";
		case "degraded_performance":
			return "Degraded performance";
		case "partial_outage":
			return "Partial outage";
		case "major_outage":
			return "Major outage";
		default:
			return rawStatus ? rawStatus.replace(/_/g, " ") : "Unknown";
	}
}

/**
 * Fetch status from a standard statuspage.io API
 */
async function fetchStatuspageStatus(
	url: string,
	deps: Dependencies,
	config?: StatusPageStatusConfig
): Promise<ProviderStatus> {
	const { controller, clear } = createTimeoutController(API_TIMEOUT_MS);

	try {
		const fetchUrl = config?.component ? toSummaryUrl(url) : url;
		const res = await deps.fetch(fetchUrl, { signal: controller.signal });
		clear();

		if (!res.ok) {
			return { indicator: "unknown" };
		}

		if (!config?.component) {
			const data = (await res.json()) as StatusPageResponse;
			const indicator = mapStatusIndicator(data.status?.indicator);
			return { indicator, description: data.status?.description };
		}

		const data = (await res.json()) as StatusPageSummary;
		const summaryIndicator = mapStatusIndicator(data.status?.indicator);
		const component = (data.components ?? []).find((entry) => isComponentMatch(entry, config));
		if (component) {
			const componentIndicator = mapComponentStatus(component.status);
			const componentDescription =
				componentIndicator === "none"
					? undefined
					: `${component.name ?? "Component"}: ${formatComponentLabel(component.status)}`;
			return {
				indicator: componentIndicator,
				description: componentDescription,
			};
		}

		return {
			indicator: summaryIndicator,
			description: data.status?.description,
		};
	} catch {
		clear();
		return { indicator: "unknown" };
	}
}

/**
 * Fetch Gemini status from Google Workspace status API
 */
async function fetchGeminiStatus(deps: Dependencies): Promise<ProviderStatus> {
	const { controller, clear } = createTimeoutController(API_TIMEOUT_MS);

	try {
		const res = await deps.fetch(GOOGLE_STATUS_URL, { signal: controller.signal });
		clear();

		if (!res.ok) return { indicator: "unknown" };

		const incidents = (await res.json()) as Array<{
			end?: string;
			currently_affected_products?: Array<{ id: string }>;
			affected_products?: Array<{ id: string }>;
			most_recent_update?: { status?: string };
			status_impact?: string;
			external_desc?: string;
		}>;

		const activeIncidents = incidents.filter((inc) => {
			if (inc.end) return false;
			const affected = inc.currently_affected_products || inc.affected_products || [];
			return affected.some((p) => p.id === GEMINI_PRODUCT_ID);
		});

		if (activeIncidents.length === 0) {
			return { indicator: "none" };
		}

		let worstIndicator: StatusIndicator = "minor";
		let description: string | undefined;

		for (const inc of activeIncidents) {
			const status = inc.most_recent_update?.status || inc.status_impact;
			if (status === "SERVICE_OUTAGE") {
				worstIndicator = "critical";
				description = inc.external_desc;
			} else if (status === "SERVICE_DISRUPTION" && worstIndicator !== "critical") {
				worstIndicator = "major";
				description = inc.external_desc;
			}
		}

		return { indicator: worstIndicator, description };
	} catch {
		clear();
		return { indicator: "unknown" };
	}
}

/**
 * Fetch status for a provider
 */
export async function fetchProviderStatus(provider: ProviderName, deps: Dependencies): Promise<ProviderStatus> {
	const statusConfig = PROVIDER_METADATA[provider]?.status;
	if (!statusConfig) {
		return { indicator: "none" };
	}

	if (statusConfig.type === "google-workspace") {
		return fetchGeminiStatus(deps);
	}

	return fetchStatuspageStatus(statusConfig.url, deps, statusConfig);
}

/**
 * Get emoji for a status indicator
 */
export function getStatusEmoji(status?: ProviderStatus): string {
	if (!status) return "";
	switch (status.indicator) {
		case "none":
			return "✅";
		case "minor":
			return "⚠️";
		case "major":
			return "🟠";
		case "critical":
			return "🔴";
		case "maintenance":
			return "🔧";
		default:
			return "";
	}
}
