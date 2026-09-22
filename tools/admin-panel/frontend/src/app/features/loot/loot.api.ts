import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../core/api.service';

export interface LootTableInfo {
  id: string;
  name: string;
  table: string;
  owner: string;
  hint: string;
  rows: number;
}

export interface LootMeta {
  tables: LootTableInfo[];
  modes: Record<string, string>;
  ranks: Record<string, string>;
  max_depth: number;
  icon_base_url: string;
}

export interface LootItem {
  entry: number;
  name: string;
  name_ru: string;
  quality: number;
  ilvl?: number;
  req_level?: number;
  class?: number;
  subclass?: number;
  displayid?: number;
  missing: boolean;
}

export interface LootCondition {
  Comment?: string | null;
  ConditionTypeOrReference?: number;
  ConditionValue1?: number;
  ConditionValue2?: number;
  ConditionValue3?: number;
  NegativeCondition?: number;
}

export interface LootLabel {
  name: string;
  note: string;
  auto?: string;
}

export interface LootGroupLabel {
  id: number;
  name: string;
  note: string;
}

export interface LootRow {
  item: LootItem | null;
  reference: number;
  chance: number;
  raw_chance: number;
  group: number;
  quest: boolean;
  mode: number;
  mode_name: string;
  min: number;
  max: number;
  comment: string;
  conditions: LootCondition[];
  child?: LootTree;
  broken?: boolean;
}

export interface LootTree {
  table: string;
  table_name?: string;
  entry: number;
  rows: LootRow[];
  label?: LootLabel;
  groups?: LootGroupLabel[];
  truncated: boolean;
}

export interface CreatureBrief {
  entry: number;
  name: string;
  name_ru: string;
  subname: string;
  level: string;
  rank: number;
  rank_name: string;
  lootid: number;
  pickpocketloot: number;
  skinloot: number;
  kind?: string;
}

export interface CreatureLootPart {
  table: string;
  label: string;
  entry: number;
  own_entry: boolean;
  tree: LootTree;
  shared: CreatureBrief[];
}

export interface CreatureLoot {
  creature: CreatureBrief;
  loot: CreatureLootPart[];
}

export interface LootHop {
  table: string;
  table_name: string;
  entry: number;
  chance: number;
  group: number;
  quest: boolean;
  mode: number;
  mode_name: string;
  min: number;
  max: number;
  comment: string;
  label?: LootLabel;
  conditions?: LootCondition[];
  broken?: boolean;
}

export interface DropPath {
  owner_kind: string;
  owner_entry: number;
  owner_name: string;
  table: string;
  table_name: string;
  entry: number;
  chain: LootHop[];
  chance: number;
}

export interface ItemDrops {
  item: LootItem;
  paths: DropPath[];
  truncated: boolean;
  limit: number;
}

export interface TableEntry {
  entry: number;
  rows: number;
  refs: number;
  grouped: number;
  label: LootLabel;
}

export interface TableEntries {
  table: string;
  name: string;
  hint: string;
  total: number;
  entries: TableEntry[];
  note?: string;
}

export interface LootOwner {
  kind: string;
  entry: number;
  name?: string;
  name_ru?: string;
  level?: string;
  rank_name?: string;
}

export interface TableEntryDetail {
  tree: LootTree;
  owners: LootOwner[];
}

export interface CreatureSearch {
  q: string;
  onlyLoot: boolean;
  rank: string;
  levelMin: string;
  levelMax: string;
  limit?: number;
  offset?: number;
}

/** Страница списка существ: строки и СКОЛЬКО ВСЕГО их нашлось. */
export interface CreaturePage {
  creatures: CreatureBrief[];
  total: number;
  offset: number;
}

/** A loot row is keyed by item, reference and group together. */
export interface RowKey {
  item: number;
  reference: number;
  group: number;
}

export interface RowPayload extends RowKey {
  chance: number;
  quest: boolean;
  mode: number;
  min: number;
  max: number;
  comment: string;
  was_item: number;
  was_reference: number;
  was_group: number;
}

export interface SaveResult {
  ok: boolean;
  note?: string;
}

export interface CollectResult extends SaveResult {
  group: number;
  moved: number;
}

@Injectable()
export class LootApi {
  private readonly api = inject(ApiService);

  meta(): Observable<LootMeta> {
    return this.api.get<LootMeta>('/loot/meta');
  }

  creatures(search: CreatureSearch): Observable<CreaturePage> {
    const params = new URLSearchParams({
      q: search.q,
      only_loot: search.onlyLoot ? 'true' : 'false',
      limit: String(search.limit ?? 80),
    });
    if (search.rank !== '') params.set('rank', search.rank);
    if (search.levelMin) params.set('level_min', search.levelMin);
    if (search.levelMax) params.set('level_max', search.levelMax);
    if (search.offset) params.set('offset', String(search.offset));
    return this.api.get<CreaturePage>(`/loot/creatures?${params}`);
  }

  creature(entry: number): Observable<CreatureLoot> {
    return this.api.get<CreatureLoot>(`/loot/creature/${entry}`);
  }

  itemDrops(entry: number): Observable<ItemDrops> {
    return this.api.get<ItemDrops>(`/loot/item/${entry}`);
  }

  tableEntries(tableId: string, query: string, limit = 200): Observable<TableEntries> {
    const params = new URLSearchParams({ q: query, limit: String(limit) });
    return this.api.get<TableEntries>(`/loot/table/${tableId}?${params}`);
  }

  tableEntry(tableId: string, entry: number): Observable<TableEntryDetail> {
    return this.api.get<TableEntryDetail>(`/loot/table/${tableId}/${entry}`);
  }

  saveLabel(
    tableId: string,
    entry: number,
    payload: { kind: 'entry' | 'group'; group_id: number; name: string; note: string },
  ): Observable<LootLabel> {
    return this.api.put<LootLabel>(`/loot/label/${tableId}/${entry}`, payload);
  }

  saveRow(tableId: string, entry: number, payload: RowPayload): Observable<SaveResult> {
    return this.api.put<SaveResult>(`/loot/row/${tableId}/${entry}`, payload);
  }

  deleteRow(tableId: string, entry: number, key: RowKey): Observable<SaveResult> {
    const params = new URLSearchParams({
      item: String(key.item),
      reference: String(key.reference),
      group: String(key.group),
    });
    return this.api.delete<SaveResult>(`/loot/row/${tableId}/${entry}?${params}`);
  }

  collectRows(
    tableId: string,
    entry: number,
    rows: RowKey[],
    target: number,
    name: string,
  ): Observable<CollectResult> {
    return this.api.post<CollectResult>(`/loot/group/${tableId}/${entry}/collect`, {
      rows,
      target,
      name,
    });
  }

  moveGroup(
    tableId: string,
    entry: number,
    source: number,
    target: number,
  ): Observable<SaveResult> {
    const params = new URLSearchParams({ source: String(source), target: String(target) });
    return this.api.post<SaveResult>(`/loot/group/${tableId}/${entry}?${params}`);
  }
}
