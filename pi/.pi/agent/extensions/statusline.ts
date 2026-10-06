/**
 * Custom Pi status footer.
 *
 * Installs automatically on session_start (TUI mode only) and restores the
 * built-in footer on session_shutdown. All layout/formatting logic is pure
 * and lives in ./lib/statusline-format.ts (tested there); this file only wires
 * that logic to pi's ExtensionAPI/ExtensionUIContext.
 *
 * First row (wide/"single" layout): model, effort level, context %, token
 * totals, cost, elapsed time, repo path, then " │ " and the LSP/MCP/Langfuse
 * health block. On narrow widths ("stacked" layout) metadata is line 1 and
 * health is line 2. chooseFooterLayout (lib/statusline-format.ts) decides which.
 */

import type { AssistantMessage } from '@earendil-works/pi-ai';
import type {
  ExtensionAPI,
  ExtensionContext,
  SessionShutdownEvent,
  SessionStartEvent,
  Theme,
} from '@earendil-works/pi-coding-agent';
import type { ReadonlyFooterDataProvider } from '@earendil-works/pi-coding-agent';
import type { Component, TUI } from '@earendil-works/pi-tui';
import { truncateToWidth, visibleWidth } from '@earendil-works/pi-tui';
import {
  buildMetadataParts,
  chooseFooterLayout,
  compactStatuses,
  footerGap,
  resolveRepoLabel,
  rightAlignPadding,
  toneToSemanticColor,
  type MetadataPart,
} from './lib/statusline-format.ts';

export default function (pi: ExtensionAPI) {
  pi.on('session_start', (_event: SessionStartEvent, ctx: ExtensionContext) => {
    if (ctx.mode !== 'tui') {
      return;
    }

    // Captured here (inside the event handler), not at module factory time.
    const startedAt = Date.now();

    ctx.ui.setFooter((tui: TUI, theme: Theme, footerData: ReadonlyFooterDataProvider): Component & {
      dispose?(): void;
    } => {
      const unsubscribe = footerData.onBranchChange(() => tui.requestRender());

      const colorize = (part: MetadataPart): string => theme.style(part.text, { fg: part.color });
      const metadataSeparator = (part: MetadataPart, index: number): string => {
        if (index === 0) {
          return '';
        }
        return theme.fg('dim', part.attachToPrevious ? ' ' : ' │ ');
      };

      return {
        dispose: unsubscribe,
        invalidate() {},
        render(width: number): string[] {
          let tokenInput = 0;
          let tokenOutput = 0;
          let cost = 0;
          for (const entry of ctx.sessionManager.getBranch()) {
            if (entry.type === 'message' && entry.message.role === 'assistant') {
              const message = entry.message as AssistantMessage;
              tokenInput += message.usage.input;
              tokenOutput += message.usage.output;
              cost += message.usage.cost.total;
            }
          }

          const repoLabel = resolveRepoLabel(ctx.cwd, footerData.getGitBranch());

          const metadataParts = buildMetadataParts({
            modelId: ctx.model?.id,
            tokenInput,
            tokenOutput,
            cost,
            contextPercent: ctx.getContextUsage()?.percent,
            effort: ctx.thinkingLevel,
            elapsedMs: Date.now() - startedAt,
            repoLabel,
            repoMaxWidth: Math.max(10, Math.floor(width / 3)),
          });

          const healthStatuses = compactStatuses(footerData.getExtensionStatuses());

          const metadataText = metadataParts.map((part, index) => `${metadataSeparator(part, index)}${colorize(part)}`).join('');
          const healthText = healthStatuses
            .map((s) => theme.fg(toneToSemanticColor(s.tone), ` ${s.label}`))
            .join(theme.fg('dim', ' │ '));

          const layout = chooseFooterLayout(width, metadataParts, healthStatuses);

          // Degrade gracefully: if metadata alone already fills the width, drop the
          // health block rather than emit a malformed/truncated " │ " separator.
          if (layout !== 'single' || visibleWidth(metadataText) >= width) {
            const truncatedHealth = truncateToWidth(healthText, width);
            return [
              truncateToWidth(metadataText, width),
              `${rightAlignPadding(width, visibleWidth(truncatedHealth))}${truncatedHealth}`,
            ];
          }

          const line = `${metadataText}${footerGap(width, visibleWidth(metadataText), visibleWidth(healthText))}${theme.fg('dim', ' │ ')}${healthText}`;
          return [truncateToWidth(line, width)];
        },
      };
    });
  });

  pi.on('session_shutdown', (_event: SessionShutdownEvent, ctx: ExtensionContext) => {
    if (ctx.mode !== 'tui') {
      return;
    }
    ctx.ui.setFooter(undefined);
  });
}
