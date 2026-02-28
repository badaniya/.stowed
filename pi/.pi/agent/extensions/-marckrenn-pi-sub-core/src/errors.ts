/**
 * Error utilities for the sub-bar extension
 */

import type { UsageError, UsageErrorCode } from "./types.js";

export function createError(code: UsageErrorCode, message: string, httpStatus?: number): UsageError {
	return { code, message, httpStatus };
}

export function noCredentials(): UsageError {
	return createError("NO_CREDENTIALS", "No credentials found");
}

export function noCli(cliName: string): UsageError {
	return createError("NO_CLI", `${cliName} CLI not found`);
}

export function notLoggedIn(): UsageError {
	return createError("NOT_LOGGED_IN", "Not logged in");
}

export function fetchFailed(reason?: string): UsageError {
	return createError("FETCH_FAILED", reason ?? "Fetch failed");
}

export function httpError(status: number): UsageError {
	return createError("HTTP_ERROR", `HTTP ${status}`, status);
}

export function apiError(message: string): UsageError {
	return createError("API_ERROR", message);
}

export function timeout(): UsageError {
	return createError("TIMEOUT", "Request timed out");
}

/**
 * Check if an error should be considered "no data available" vs actual error
 * These are expected states when provider isn't configured
 */
export function isExpectedMissingData(error: UsageError): boolean {
	const ignoreCodes = new Set<UsageErrorCode>(["NO_CREDENTIALS", "NO_CLI", "NOT_LOGGED_IN"]);
	return ignoreCodes.has(error.code);
}

/**
 * Format error for display in the usage widget
 */
export function formatErrorForDisplay(error: UsageError): string {
	switch (error.code) {
		case "NO_CREDENTIALS":
			return "No creds";
		case "NO_CLI":
			return "No CLI";
		case "NOT_LOGGED_IN":
			return "Not logged in";
		case "HTTP_ERROR":
			if (error.httpStatus === 401) {
				return "token no longer valid – please /login again";
			}
			return `${error.httpStatus}`;
		case "FETCH_FAILED":
		case "API_ERROR":
		case "TIMEOUT":
		case "UNKNOWN":
		default:
			return "Fetch failed";
	}
}
