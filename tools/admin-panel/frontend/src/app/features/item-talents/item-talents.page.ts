import { CommonModule } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import {
  Category,
  Choice,
  Curve,
  ItemSummary,
  ItemTalentsApi,
  Meta,
  Perk,
  Problem,
  Proc,
  Rule,
  TalentItem,
  TalentRow,
} from './item-talents.api';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { IconComponent } from '../../shared/ui/icon.component';
import { ToastService } from '../../shared/ui/toast.service';

type Tab = 'categories' | 'menus' | 'items' | 'procs' | 'curves' | 'library';

@Component({
  imports: [CommonModule, FormsModule, ForgeSelectDirective, IconComponent],
  providers: [ItemTalentsApi],
  selector: 'app-item-talents-page',
  styleUrl: './item-talents.page.scss',
  templateUrl: './item-talents.page.html',
})
export class ItemTalentsPage implements OnInit {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ItemTalentsApi);
  readonly auth = inject(AuthService);
  readonly tabs: readonly { id: Tab; label: string }[] = [
    { id: 'categories', label: 'Категории' },
    { id: 'menus', label: 'Меню категорий' },
    { id: 'items', label: 'Предметы' },
    { id: 'procs', label: 'Проки ряда 5' },
    { id: 'curves', label: 'Пороги убийств' },
    { id: 'library', label: 'Библиотека перков' },
  ];
  readonly meta = signal<Meta | null>(null);
  readonly tab = signal<Tab>('categories');
  readonly categories = signal<Category[]>([]);
  readonly rules = signal<Rule[]>([]);
  readonly categoryRows = signal<TalentRow[]>([]);
  readonly selectedCode = signal<string | null>(null);
  readonly items = signal<ItemSummary[]>([]);
  readonly selectedItem = signal<TalentItem | null>(null);
  readonly itemQuery = signal('');
  readonly qualityMin = signal(4);
  readonly itemClass = signal(-1);
  readonly onlyCustom = signal(false);
  readonly procs = signal<Proc[]>([]);
  readonly freeProcSpells = signal<number[]>([]);
  readonly curves = signal<Curve[]>([]);
  readonly library = signal<Perk[]>([]);
  readonly problems = signal<Problem[]>([]);
  readonly pending = signal(false);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);
  readonly canEdit = computed(() =>
    ['editor', 'owner'].includes(this.auth.actor()?.role ?? 'viewer'),
  );

  constructor() {
    // Сообщения об удаче и отказе показываются всплывающими
    // плашками: строка наверху страницы сдвигала содержимое и
    // висела до следующего действия.
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
  }

  async ngOnInit(): Promise<void> {
    try {
      const meta = await firstValueFrom(this.api.meta());
      this.meta.set(meta);
      if (!meta.installed) return;
      await this.loadCategories();
      try {
        this.library.set(await firstValueFrom(this.api.library()));
      } catch {
        // The library is a convenience for the row editor; its own tab shows errors on demand.
      }
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось загрузить редактор талантов.'));
    } finally {
      this.loading.set(false);
    }
  }

  async chooseTab(tab: Tab): Promise<void> {
    this.tab.set(tab);
    this.problems.set([]);
    this.error.set(null);
    if (tab === 'categories' && !this.categories().length) await this.loadCategories();
    if (tab === 'menus') await this.loadMenu();
    if (tab === 'items') await this.searchItems();
    if (tab === 'procs') await this.loadProcs();
    if (tab === 'curves') await this.loadCurves();
    if (tab === 'library') await this.loadLibrary();
  }

  addCategory(): void {
    this.categories.update((rows) => [
      ...rows,
      { code: '', name_ru: '', comment: '', enabled: true, sort: 0, choices: 0, items: 0 },
    ]);
  }

  addRule(): void {
    this.rules.update((rows) => [
      ...rows,
      {
        code: this.categories()[0]?.code ?? '',
        item_class: -1,
        subclass: -1,
        inv_type: -1,
        quality_min: 0,
        quality_max: 7,
        entry_lo: 0,
        entry_hi: 0,
        priority: 0,
        comment: '',
      },
    ]);
  }

  removeCategory(index: number): void {
    this.categories.update((rows) => rows.filter((_, row) => row !== index));
  }
  removeRule(index: number): void {
    this.rules.update((rows) => rows.filter((_, row) => row !== index));
  }

  async saveCategories(force = false): Promise<void> {
    await this.save(
      () =>
        this.api.saveCategories(
          this.categories().map(({ choices, items, ...category }) => category),
          this.rules(),
          force,
        ),
      'Категории сохранены и применены.',
      () => this.loadCategories(),
      () => this.saveCategories(true),
    );
  }

  async selectCategory(code: string): Promise<void> {
    this.selectedCode.set(code);
    await this.loadMenu();
  }

  async loadMenu(): Promise<void> {
    if (!this.categories().length) await this.loadCategories();
    const code = this.selectedCode() ?? this.categories()[0]?.code;
    if (!code) return;
    this.selectedCode.set(code);
    try {
      this.categoryRows.set(await firstValueFrom(this.api.rows(code)));
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось загрузить меню категории.'));
    }
  }

  async saveCategoryRow(row: TalentRow, force = false): Promise<void> {
    const code = this.selectedCode();
    if (!code) return;
    await this.save(
      () => this.api.saveCategoryRow(code, this.rowPayload(row, true), force),
      `Ряд ${row.row} сохранён и применён.`,
      () => this.loadMenu(),
      () => this.saveCategoryRow(row, true),
    );
  }

  async searchItems(): Promise<void> {
    if (!this.meta()?.installed) return;
    try {
      this.items.set(
        await firstValueFrom(
          this.api.items(this.itemQuery(), this.qualityMin(), this.itemClass(), this.onlyCustom()),
        ),
      );
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось найти предметы.'));
    }
  }

  async selectItem(entry: number): Promise<void> {
    try {
      this.selectedItem.set(await firstValueFrom(this.api.item(entry)));
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось открыть предмет.'));
    }
  }

  async saveItemRow(row: TalentRow, force = false): Promise<void> {
    const item = this.selectedItem();
    if (!item) return;
    await this.save(
      () => this.api.saveItemRow(item.entry, this.rowPayload(row, false), force),
      `Ряд ${row.row} сохранён и применён.`,
      () => this.selectItem(item.entry),
      () => this.saveItemRow(row, true),
    );
  }

  async clearItemRow(row: TalentRow): Promise<void> {
    if (!confirm('Убрать персональный пул этого ряда и вернуть меню категории?')) return;
    const empty = { ...row, roll_count: 3, quality_enabled: true, choices: [] };
    await this.saveItemRow(empty);
  }

  addChoice(row: TalentRow): void {
    const used = new Set(row.choices.map((choice) => choice.choice));
    let choice = 1;
    while (used.has(choice) && choice < (this.meta()?.max_choices ?? 30)) choice += 1;
    row.choices.push({
      choice,
      name_ru: '',
      desc_ru: '',
      effect: 'STAT_STA',
      base: 0,
      per_ilvl: 0,
      subclass: -1,
    });
  }

  addFromLibrary(row: TalentRow, perkId: string): void {
    const perk = this.library().find((candidate) => candidate.id === Number(perkId));
    if (!perk) return;
    const used = new Set(row.choices.map((choice) => choice.choice));
    let choice = 1;
    while (used.has(choice) && choice < (this.meta()?.max_choices ?? 30)) choice += 1;
    row.choices.push({
      choice,
      name_ru: perk.name_ru,
      desc_ru: perk.desc_ru,
      effect: perk.effect,
      base: perk.base,
      per_ilvl: perk.per_ilvl,
      subclass: -1,
    });
  }

  removeChoice(row: TalentRow, index: number): void {
    row.choices.splice(index, 1);
  }

  async loadProcs(): Promise<void> {
    try {
      const data = await firstValueFrom(this.api.procs());
      this.procs.set(data.procs);
      this.freeProcSpells.set(data.spells.free);
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось загрузить проки.'));
    }
  }

  addProc(): void {
    this.procs.update((rows) => [
      ...rows,
      {
        trigger_spell: this.freeProcSpells()[0] ?? 0,
        visible_spell: 0,
        trigger_type: 'MELEE_HIT',
        effect_type: 'DAMAGE',
        school: 0,
        chance: 10,
        icd_secs: 8,
        coef: 1,
        duration_secs: 0,
        hp_threshold: 0,
        perks: [],
        trigger_in_dbc: false,
        visible_in_dbc: false,
      },
    ]);
  }
  removeProc(index: number): void {
    this.procs.update((rows) => rows.filter((_, row) => row !== index));
  }
  async saveProcs(force = false): Promise<void> {
    await this.save(
      () => this.api.saveProcs(this.procs(), force),
      'Проки сохранены и применены.',
      () => this.loadProcs(),
      () => this.saveProcs(true),
    );
  }

  async loadCurves(): Promise<void> {
    try {
      this.curves.set(await firstValueFrom(this.api.curves()));
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось загрузить пороги убийств.'));
    }
  }
  addCurve(): void {
    this.curves.update((rows) => [
      ...rows,
      {
        id: 0,
        name: '',
        quality_min: 0,
        quality_max: 7,
        ilvl_min: 0,
        ilvl_max: 999,
        lvl1: 50,
        lvl2: 150,
        lvl3: 400,
        lvl4: 1000,
        lvl5: 2500,
        priority: 0,
      },
    ]);
  }
  removeCurve(index: number): void {
    this.curves.update((rows) => rows.filter((_, row) => row !== index));
  }
  curveTotal(row: Curve): number {
    return row.lvl1 + row.lvl2 + row.lvl3 + row.lvl4 + row.lvl5;
  }
  async saveCurves(force = false): Promise<void> {
    await this.save(
      () => this.api.saveCurves(this.curves(), force),
      'Пороги сохранены и применены.',
      () => this.loadCurves(),
      () => this.saveCurves(true),
    );
  }

  async loadLibrary(): Promise<void> {
    try {
      this.library.set(await firstValueFrom(this.api.library()));
    } catch (error) {
      this.error.set(this.errorText(error, 'Не удалось загрузить библиотеку перков.'));
    }
  }
  addPerk(): void {
    this.library.update((rows) => [
      ...rows,
      { id: 0, name_ru: '', desc_ru: '', effect: 'STAT_STA', base: 0, per_ilvl: 0, tags: '' },
    ]);
  }
  removePerk(index: number): void {
    this.library.update((rows) => rows.filter((_, row) => row !== index));
  }
  async saveLibrary(): Promise<void> {
    await this.save(
      () => this.api.saveLibrary(this.library()),
      'Библиотека сохранена.',
      () => this.loadLibrary(),
    );
  }

  effectValue(choice: Pick<Choice, 'effect' | 'base' | 'per_ilvl'>, ilvl: number): string {
    const kind = this.meta()?.effects.find((effect) => effect.code === choice.effect)?.kind;
    if (kind === 'pct') return `${Number(choice.base) || 0}%`;
    if (kind === 'proc')
      return Math.ceil((Number(choice.per_ilvl) || 0) * ilvl) > 0
        ? `${Math.ceil((Number(choice.per_ilvl) || 0) * ilvl)} (спелл ${Number(choice.base) || 0})`
        : `спелл ${Number(choice.base) || 0}`;
    return String(
      Math.max(1, Math.ceil((Number(choice.base) || 0) + (Number(choice.per_ilvl) || 0) * ilvl)),
    );
  }

  subclassName(itemClass: number, subclass: number): string {
    if (subclass < 0) return 'любой';
    const names = itemClass === 2 ? this.meta()?.weapon_subclasses : this.meta()?.armor_subclasses;
    return names?.[subclass] ? `${subclass} — ${names[subclass]}` : String(subclass);
  }

  private async loadCategories(): Promise<void> {
    const data = await firstValueFrom(this.api.categories());
    this.categories.set(data.categories);
    this.rules.set(data.rules);
    if (!this.selectedCode() && data.categories.length)
      this.selectedCode.set(data.categories[0].code);
  }

  private rowPayload(row: TalentRow, withSubclass: boolean): TalentRow {
    return {
      ...row,
      roll_count: Number(row.roll_count) || 3,
      quality_enabled: !!row.quality_enabled,
      choices: row.choices.map((choice) => ({
        ...choice,
        choice: Number(choice.choice),
        base: Number(choice.base) || 0,
        per_ilvl: Number(choice.per_ilvl) || 0,
        subclass: withSubclass ? Number(choice.subclass) || -1 : -1,
      })),
    };
  }

  private async save(
    request: () => ReturnType<ItemTalentsApi['saveLibrary']>,
    message: string,
    after: () => Promise<void>,
    retry?: () => Promise<void>,
  ): Promise<void> {
    if (!this.canEdit() || this.pending()) return;
    this.pending.set(true);
    this.error.set(null);
    try {
      const result = await firstValueFrom(request());
      if (typeof result === 'object' && result && 'problems' in result) {
        const reported = (result as { problems?: unknown }).problems;
        this.problems.set(Array.isArray(reported) ? (reported as Problem[]) : []);
      } else {
        this.problems.set([]);
      }
      this.notice.set(message);
      await after();
    } catch (error) {
      const problems = this.problemsFrom(error);
      if (problems.length && retry && confirm('Есть ошибки проверки. Сохранить всё равно?')) {
        this.pending.set(false);
        await retry();
        return;
      }
      this.problems.set(problems);
      this.error.set(
        problems.length
          ? 'Исправьте ошибки проверки или подтвердите принудительное сохранение.'
          : this.errorText(error, 'Не удалось сохранить изменения.'),
      );
    } finally {
      this.pending.set(false);
    }
  }

  private problemsFrom(error: unknown): Problem[] {
    if (typeof error !== 'object' || !error || !('error' in error)) return [];
    const detail = (error as { error?: { detail?: { problems?: unknown } } }).error?.detail;
    return Array.isArray(detail?.problems) ? (detail.problems as Problem[]) : [];
  }
  private errorText(error: unknown, fallback: string): string {
    if (typeof error === 'object' && error && 'error' in error) {
      const detail = (error as { error?: { detail?: unknown } }).error?.detail;
      if (typeof detail === 'string') return detail;
    }
    return fallback;
  }
}
