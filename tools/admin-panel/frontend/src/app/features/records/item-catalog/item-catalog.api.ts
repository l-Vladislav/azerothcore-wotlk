import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../../core/api.service';
import { CatalogPage } from '../../../shared/data/readonly-catalog';

export type ItemFieldValue = string | number | null;
export type ItemFields = Record<string, ItemFieldValue>;

export interface ItemBlock {
  id: string;
  name: string;
  summary: string;
  lo: number;
  hi: number;
  used: number;
  free: number;
  next: number | null;
}

export interface ItemField {
  col: string;
  kind: 'text' | 'int' | 'float' | 'enum';
  label: string;
  hint?: string;
  options?: string;
  width?: 'wide';
}

export interface ItemFieldGroup {
  id: string;
  name: string;
  rows: Array<{ label: string; fields: ItemField[] }>;
}

export interface ItemMeta {
  blocks: ItemBlock[];
  groups: ItemFieldGroup[];
  enums: Record<string, Array<{ value: number; label: string }>>;
  icons_available: boolean;
  icon_base_url?: string;
}

export interface ItemResult {
  entry: number;
  name: string;
  name_ru: string;
  quality: number;
  item_level: number;
  required_level: number;
  /** Класс, подкласс и слот сервер шлёт давно - таблице они и нужны. */
  class: number;
  subclass: number;
  inventory_type: number;
  icon?: string;
  block?: string | null;
}

/** One Item.dbc line: the client half of an item, for copying into the MPQ. */
export interface ClientRow {
  entry: number;
  header: string;
  line: string;
}

export interface ItemDetail {
  entry: number;
  block?: string | null;
  source?: number;
  icon?: string;
  fields: ItemFields;
}

@Injectable()
export class ItemCatalogApi {
  private readonly api = inject(ApiService);

  meta(): Observable<ItemMeta> {
    return this.api.get<ItemMeta>('/items/meta');
  }

  search(query: {
    q: string;
    block: string;
    quality: string;
    itemClass: string;
    inventoryType: string;
    itemLevelMin: string;
    itemLevelMax: string;
    requiredLevelMin: string;
    requiredLevelMax: string;
    offset: number;
    limit: number;
  }): Observable<CatalogPage<ItemResult>> {
    const params = new URLSearchParams({
      q: query.q,
      offset: String(query.offset),
      limit: String(query.limit),
    });
    const filters: Record<string, string> = {
      block: query.block,
      quality: query.quality,
      item_class: query.itemClass,
      inventory_type: query.inventoryType,
      item_level_min: query.itemLevelMin,
      item_level_max: query.itemLevelMax,
      required_level_min: query.requiredLevelMin,
      required_level_max: query.requiredLevelMax,
    };
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== '') params.set(key, value);
    });
    return this.api.get<CatalogPage<ItemResult>>(`/items?${params}`);
  }

  detail(entry: number): Observable<ItemDetail> {
    return this.api.get<ItemDetail>(`/items/${entry}`);
  }

  clientRow(entry: number): Observable<ClientRow> {
    return this.api.get<ClientRow>(`/items/${entry}/client-row`);
  }

  clone(entry: number, block: string): Observable<ItemDetail> {
    return this.api.get<ItemDetail>(`/items/clone/${entry}?block=${encodeURIComponent(block)}`);
  }

  save(entry: number, fields: ItemFields): Observable<ItemDetail> {
    return this.api.put<ItemDetail>(`/items/${entry}`, { fields });
  }

  delete(entry: number): Observable<{ ok: boolean }> {
    return this.api.delete<{ ok: boolean }>(`/items/${entry}`);
  }
}
