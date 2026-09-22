import { LootItem, LootLabel } from './loot.api';

export const BLANK_ICON =
  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

export function qualityClass(quality: number | undefined): string {
  return `q${quality ?? 0}`;
}

export function itemName(item: LootItem | null | undefined): string {
  if (!item) return '—';
  return item.name_ru || item.name || `предмет ${item.entry}`;
}

/** A full 100% reads as a word: "100.0000" makes the eye stumble. */
export function chanceText(value: number | undefined): string {
  const chance = Number(value) || 0;
  if (chance >= 100) return 'всегда';
  if (chance === 0) return '0 %';
  if (chance < 0.01) return '<0.01 %';
  return `${chance < 1 ? chance.toFixed(2) : chance.toFixed(chance < 10 ? 1 : 0)} %`;
}

/**
 * Width of the chance bar. Rare drops are the interesting ones, and on a
 * linear scale every one of them is an invisible hairline, so the scale is
 * a square root: 1% still shows, 100% still fills. The number beside it
 * stays the authority — the bar only ranks rows by eye.
 */
export function chanceWidth(value: number | undefined): number {
  const chance = Math.min(100, Math.max(0, Number(value) || 0));
  if (!chance) return 0;
  return Math.max(3, Math.round(Math.sqrt(chance / 100) * 100));
}

export function labelText(label: LootLabel | undefined, fallback: string): string {
  return label?.name || label?.auto || fallback;
}

export function apiError(error: unknown, fallback: string): string {
  if (typeof error === 'object' && error && 'error' in error) {
    const detail = (error as { error?: { detail?: unknown } }).error?.detail;
    if (typeof detail === 'string') return detail;
  }
  return fallback;
}
