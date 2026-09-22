import { Injectable, inject } from '@angular/core';
import { ApiService } from '../../core/api.service';

export interface Problem {
  level: 'error' | 'warning';
  message: string;
}
export interface SaveResult {
  saved: Record<string, unknown>;
  problems: Problem[];
  reloaded: boolean;
  reload_output: string | null;
}
export interface Effect {
  code: string;
  label: string;
  kind: 'flat' | 'pct' | 'proc';
}
export interface Option {
  code: string;
  label: string;
}
export interface Meta {
  installed: boolean;
  max_choices: number;
  quality_names: Record<string, string>;
  item_classes: Record<string, string>;
  armor_subclasses: Record<string, string>;
  weapon_subclasses: Record<string, string>;
  effects: Effect[];
  proc_triggers: Option[];
  proc_effects: Option[];
}
export interface Category {
  code: string;
  name_ru: string;
  comment: string;
  enabled: boolean;
  sort: number;
  choices: number;
  items: number;
}
export interface Rule {
  code: string;
  item_class: number;
  subclass: number;
  inv_type: number;
  quality_min: number;
  quality_max: number;
  entry_lo: number;
  entry_hi: number;
  priority: number;
  comment: string;
}
export interface Choice {
  choice: number;
  name_ru: string;
  desc_ru: string;
  effect: string;
  base: number;
  per_ilvl: number;
  subclass: number;
}
export interface TalentRow {
  row: number;
  name: string;
  roll_count: number;
  quality_enabled: boolean;
  choices: Choice[];
  own?: boolean;
}
export interface TalentItem {
  entry: number;
  name: string;
  name_en: string;
  quality: number;
  ilvl: number;
  class: number;
  subclass: number;
  category: string | null;
  rows_open: number;
  rows: TalentRow[];
  own_choices?: boolean;
}
export interface ItemSummary {
  entry: number;
  name: string;
  name_en: string;
  quality: number;
  ilvl: number;
  own_choices: boolean;
}
export interface Proc {
  trigger_spell: number;
  visible_spell: number;
  trigger_type: string;
  effect_type: string;
  school: number;
  chance: number;
  icd_secs: number;
  coef: number;
  duration_secs: number;
  hp_threshold: number;
  perks: string[];
  trigger_in_dbc: boolean;
  visible_in_dbc: boolean;
}
export interface Curve {
  id: number;
  name: string;
  quality_min: number;
  quality_max: number;
  ilvl_min: number;
  ilvl_max: number;
  lvl1: number;
  lvl2: number;
  lvl3: number;
  lvl4: number;
  lvl5: number;
  priority: number;
}
export interface Perk {
  id: number;
  name_ru: string;
  desc_ru: string;
  effect: string;
  base: number;
  per_ilvl: number;
  tags: string;
}

@Injectable()
export class ItemTalentsApi {
  private readonly api = inject(ApiService);
  meta() {
    return this.api.get<Meta>('/italents/meta');
  }
  categories() {
    return this.api.get<{ categories: Category[]; rules: Rule[] }>('/italents/categories');
  }
  saveCategories(
    categories: Array<Omit<Category, 'choices' | 'items'>>,
    rules: Rule[],
    force = false,
  ) {
    return this.api.put<SaveResult>(`/italents/categories?reload=true&force=${force ? 1 : 0}`, {
      categories,
      rules,
    });
  }
  rows(code: string) {
    return this.api.get<TalentRow[]>(`/italents/categories/${encodeURIComponent(code)}/rows`);
  }
  saveCategoryRow(code: string, row: TalentRow, force = false) {
    return this.api.put<SaveResult>(
      `/italents/categories/${encodeURIComponent(code)}/rows/${row.row}?reload=true&force=${force ? 1 : 0}`,
      row,
    );
  }
  items(query: string, quality: number, itemClass: number, onlyCustom: boolean) {
    return this.api.get<ItemSummary[]>(
      `/italents/items?q=${encodeURIComponent(query)}&quality_min=${quality}&item_class=${itemClass}&only_custom=${onlyCustom}&limit=300`,
    );
  }
  item(entry: number) {
    return this.api.get<TalentItem>(`/italents/items/${entry}`);
  }
  saveItemRow(entry: number, row: TalentRow, force = false) {
    return this.api.put<SaveResult>(
      `/italents/items/${entry}/rows/${row.row}?reload=true&force=${force ? 1 : 0}`,
      row,
    );
  }
  procs() {
    return this.api.get<{ procs: Proc[]; spells: { range: [number, number]; free: number[] } }>(
      '/italents/procs',
    );
  }
  saveProcs(rows: Proc[], force = false) {
    return this.api.put<SaveResult>(`/italents/procs?reload=true&force=${force ? 1 : 0}`, rows);
  }
  curves() {
    return this.api.get<Curve[]>('/italents/curves');
  }
  saveCurves(rows: Curve[], force = false) {
    return this.api.put<SaveResult>(`/italents/curves?reload=true&force=${force ? 1 : 0}`, rows);
  }
  library() {
    return this.api.get<Perk[]>('/italents/library');
  }
  saveLibrary(rows: Perk[]) {
    return this.api.put<unknown>('/italents/library', rows);
  }
}
