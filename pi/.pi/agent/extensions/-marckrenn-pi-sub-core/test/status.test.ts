import test from "node:test";
import assert from "node:assert/strict";
import { fetchProviderStatus } from "../src/status.js";
import { createDeps, createJsonResponse } from "./helpers.js";

const STATUS_OPENAI_SUMMARY = "https://status.openai.com/api/v2/summary.json";
const STATUS_GITHUB = "https://www.githubstatus.com/api/v2/status.json";


test("fetchProviderStatus uses component-specific status for codex", async () => {
	const urls: string[] = [];
	const { deps } = createDeps({
		fetch: async (url) => {
			urls.push(url as string);
			return createJsonResponse({
				status: {
					indicator: "none",
					description: "All Systems Operational",
				},
				components: [
					{ id: "other", name: "ChatGPT API", status: "operational" },
					{ id: "01JVCV8YSWZFRSM1G5CVP253SK", name: "Codex", status: "partial_outage" },
				],
			});
		},
	});

	const status = await fetchProviderStatus("codex", deps);
	assert.equal(urls[0], STATUS_OPENAI_SUMMARY);
	assert.equal(status.indicator, "major");
	assert.equal(status.description, "Codex: Partial outage");
});


test("fetchProviderStatus falls back to summary status when component is missing", async () => {
	const urls: string[] = [];
	const { deps } = createDeps({
		fetch: async (url) => {
			urls.push(url as string);
			return createJsonResponse({
				status: {
					indicator: "minor",
					description: "Minor global issue",
				},
				components: [{ id: "other", name: "ChatGPT API", status: "partial_outage" }],
			});
		},
	});

	const status = await fetchProviderStatus("codex", deps);
	assert.equal(urls[0], STATUS_OPENAI_SUMMARY);
	assert.equal(status.indicator, "minor");
	assert.equal(status.description, "Minor global issue");
});


test("fetchProviderStatus uses status endpoint for providers without component filtering", async () => {
	const urls: string[] = [];
	const { deps } = createDeps({
		fetch: async (url) => {
			urls.push(url as string);
			return createJsonResponse({ status: { indicator: "critical", description: "Github outage" } });
		},
	});

	const status = await fetchProviderStatus("copilot", deps);
	assert.equal(urls[0], STATUS_GITHUB);
	assert.equal(status.indicator, "critical");
	assert.equal(status.description, "Github outage");
});
