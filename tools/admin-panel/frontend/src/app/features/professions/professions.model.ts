import { DictRow, ItemBrief, ProfessionsMeta } from './professions.api';

export const BLANK_ICON =
  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

/** Роль двоичная: «только для сочетаний» отменена 2026-09-07 (DESIGN §2.5). */
export const ROLES: Record<string, string> = { base: 'на основу', insert: 'вставка' };

/**
 * Способ получения основы. Низ куётся, верх выбивается: профессия становится
 * способом ДОВЕСТИ добытое, а не заменить его (DESIGN §2.5).
 */
export const ACQUIRE: Record<string, string> = { forge: 'куётся', drop: 'только добыча' };

export function iconUrl(texture: string | undefined | null, base: string | undefined): string {
  return texture && base ? `${base}/${texture}.jpg` : BLANK_ICON;
}

export function useBlankIcon(event: Event): void {
  (event.target as HTMLImageElement).src = BLANK_ICON;
}

export function statName(meta: ProfessionsMeta | null, id: number): string {
  return meta?.stats?.[id] ?? `стат ${id}`;
}

export function qualityName(meta: ProfessionsMeta | null, quality: number): string {
  return meta?.qualities?.find((tier) => tier.quality === quality)?.name_ru ?? String(quality);
}

export function itemName(item: ItemBrief | null | undefined, entry: number): string {
  return item?.name || `предмет ${entry}`;
}

/**
 * Варианты для списка: только включённые строки, плюс та, что уже стоит у
 * записи. Выключенную не прячем, если она выбрана, - иначе список молча
 * подменил бы её первой попавшейся.
 */
export function dictOptions(rows: readonly DictRow[], current: number): DictRow[] {
  return rows.filter((row) => row.enabled || row.id === current);
}

export function dictName(rows: readonly DictRow[], id: number): string {
  const row = rows.find((item) => item.id === id);
  if (row) return row.enabled ? row.name_ru : `${row.name_ru} (выкл)`;
  return id ? `строка ${id}` : '—';
}

/**
 * Первая включённая строка справочника: ею заполняется признак, когда роль
 * материала переключили и прежний признак стал не тем.
 */
export function firstDictId(rows: readonly DictRow[]): number {
  return rows.find((row) => row.enabled)?.id ?? 0;
}

/** Подклассы зависят от класса: у брони свой список, у оружия свой. */
export function subclassOptions(
  meta: ProfessionsMeta | null,
  itemClass: number,
): [string, string][] {
  const map = itemClass === 4 ? meta?.armor_subclasses : meta?.weapon_subclasses;
  return Object.entries(map ?? {});
}

/** Отказ модуля - это сообщение человеку (409 с текстом), а не пятисотая. */
export function apiError(error: unknown, fallback: string): string {
  if (typeof error === 'object' && error && 'error' in error) {
    const detail = (error as { error?: { detail?: unknown } }).error?.detail;
    if (typeof detail === 'string') return detail;
  }
  return fallback;
}
