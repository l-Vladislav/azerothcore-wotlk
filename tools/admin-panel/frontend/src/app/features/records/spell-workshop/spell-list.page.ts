import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth.service';
import { TablePagerComponent } from '../../../shared/data/table-pager.component';
import { ForgeSelectDirective } from '../../../shared/ui/forge-select.directive';
import { GameIconComponent } from '../../../shared/ui/game-icon.component';
import { ToastService } from '../../../shared/ui/toast.service';
import { SpellCatalogApi } from '../spell-catalog/spell-catalog.api';
import { PendingRestart, SpellWorkshopApi, WorkshopMeta } from './spell-workshop.api';

const PAGE_SIZES = [10, 25, 50, 100];
const DEFAULT_PER_PAGE = 10;

/** Пустая локаль в spell_dbc хранится нулём - именем это не считается. */
const text = (value?: string | null): string => (value && value !== '0' ? value : '');

/** Строка таблицы: у своих и у клиентских заклинаний общий вид. */
interface SpellRow {
  id: number;
  title: string;
  subtitle: string;
  /** Пул и модуль у своих, источник - у клиентских. */
  from: string;
  /** Что заклинание делает (свои) или его школы (клиентские). */
  does: string;
  /** Прок у своих, уровень у клиентских: числовая колонка в хвосте. */
  tail: string;
  icon: string;
}

/**
 * Все заклинания таблицей: и свои, и весь список клиента.
 *
 * Прежде они жили узкой колонкой слева от редактора, и в строке помещались
 * только имя с номером - а что заклинание делает, из какого оно пула и с
 * каким шансом срабатывает, приходилось открывать по одному.
 *
 * «Свои» и «Все в клиенте» - это два РАЗНЫХ источника, и знают они о строке
 * разное: у своих есть эффекты и прок, у клиентских - школа и уровень.
 * Поэтому две последние колонки меняются вместе с выбором, а не заполняются
 * прочерками.
 */
@Component({
  providers: [SpellWorkshopApi, SpellCatalogApi],
  imports: [FormsModule, ForgeSelectDirective, TablePagerComponent, GameIconComponent],
  selector: 'app-spell-list-page',
  styleUrl: './spell-list.page.scss',
  templateUrl: './spell-list.page.html',
})
export class SpellListPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(SpellWorkshopApi);
  private readonly dex = inject(SpellCatalogApi);
  private readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private readonly params = toSignal(this.route.queryParamMap, {
    initialValue: this.route.snapshot.queryParamMap,
  });
  private searchTimer: ReturnType<typeof setTimeout> | null = null;
  private lastSearch = '';
  private requestId = 0;

  readonly meta = signal<WorkshopMeta | null>(null);
  readonly rows = signal<SpellRow[]>([]);
  readonly total = signal(0);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly pending = signal<PendingRestart | null>(null);
  /** Откуда берутся картинки иконок: адрес знает каталог DBC. */
  readonly iconBase = signal('');

  readonly query = signal('');
  readonly scope = signal<'own' | 'all'>('own');
  readonly block = signal('');
  readonly module = signal('');
  readonly school = signal('');
  readonly effect = signal('');
  readonly aura = signal('');
  readonly procMin = signal('');
  readonly procMax = signal('');
  readonly offset = signal(0);
  readonly perPage = signal(DEFAULT_PER_PAGE);

  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly page = computed(() => Math.floor(this.offset() / this.perPage()) + 1);
  readonly filtersUsed = computed(
    () =>
      !!(
        this.query() ||
        this.block() ||
        this.module() ||
        this.school() ||
        this.effect() ||
        this.aura() ||
        this.procMin() ||
        this.procMax()
      ),
  );

  constructor() {
    this.toast.announce(this.error, 'error');
    effect(() => {
      const params = this.params();
      untracked(() => this.applyParams(params));
    });
    void this.loadMeta();
  }

  private async loadMeta(): Promise<void> {
    try {
      this.meta.set(await firstValueFrom(this.api.catalog()));
    } catch {
      this.error.set('Не удалось загрузить пулы и списки значений мастерской.');
    }
    try {
      const meta = await firstValueFrom(this.dex.meta());
      this.iconBase.set(meta.icon_base_url ?? '');
    } catch {
      // Без адреса иконок страница работает - просто с контурными значками.
      this.iconBase.set('');
    }
    void this.refreshPending();
  }

  async refreshPending(): Promise<void> {
    try {
      this.pending.set(await firstValueFrom(this.api.pendingRestart()));
    } catch {
      this.pending.set({ known: false, count: 0, reason: 'Панель не дозвонилась до PTR.' });
    }
  }

  pendingLabel(): string {
    const state = this.pending();
    if (!state) return '';
    if (!state.known) return 'аптайм PTR неизвестен';
    return state.count ? `ждут рестарта: ${state.count}` : 'всё применено';
  }

  private applyParams(params: ParamMap): void {
    // Старые адреса страницы-редактора ведут на саму карточку: ссылки из
    // заметок не должны упираться в список.
    const open = Number(params.get('open')) || 0;
    if (open) {
      void this.router.navigate(['/catalog/spells', open], { replaceUrl: true });
      return;
    }
    const clone = Number(params.get('clone')) || 0;
    if (clone) {
      void this.router.navigate(['/catalog/spells', 'new'], {
        queryParams: { clone, block: params.get('block') ?? '' },
        replaceUrl: true,
      });
      return;
    }

    this.query.set(params.get('q') ?? '');
    this.scope.set(params.get('scope') === 'all' ? 'all' : 'own');
    this.block.set(params.get('block') ?? '');
    this.module.set(params.get('module') ?? '');
    this.school.set(params.get('school') ?? '');
    this.effect.set(params.get('effect') ?? '');
    this.aura.set(params.get('aura') ?? '');
    this.procMin.set(params.get('procmin') ?? '');
    this.procMax.set(params.get('procmax') ?? '');
    this.offset.set(Math.max(0, Number(params.get('from')) || 0));
    this.perPage.set(
      PAGE_SIZES.includes(Number(params.get('per'))) ? Number(params.get('per')) : DEFAULT_PER_PAGE,
    );

    const key = [
      this.query(),
      this.scope(),
      this.block(),
      this.module(),
      this.school(),
      this.effect(),
      this.aura(),
      this.procMin(),
      this.procMax(),
      this.offset(),
      this.perPage(),
    ].join('|');
    if (key !== this.lastSearch) {
      this.lastSearch = key;
      void this.search();
    }
  }

  /** Отбор живёт в адресе: найденное заклинание - это ссылка, а не состояние. */
  patch(changes: Record<string, string | null>, replaceUrl = false): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: changes,
      queryParamsHandling: 'merge',
      replaceUrl,
    });
  }

  onQuery(value: string): void {
    this.query.set(value);
    if (this.searchTimer) clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.patch({ q: value || null, from: null }, true), 250);
  }

  setScope(scope: 'own' | 'all'): void {
    if (this.scope() === scope) return;
    this.patch({ scope: scope === 'own' ? null : 'all', from: null });
  }

  onProc(from: string, to: string): void {
    this.patch({ procmin: from || null, procmax: to || null, from: null });
  }

  onPerPage(value: string | number): void {
    const per = String(value);
    this.patch({ per: Number(per) === DEFAULT_PER_PAGE ? null : per, from: null });
  }

  goToPage(page: number): void {
    const next = Math.max(0, (page - 1) * this.perPage());
    this.patch({ from: next ? String(next) : null });
  }

  resetFilters(): void {
    this.patch({
      q: null,
      block: null,
      module: null,
      school: null,
      effect: null,
      aura: null,
      procmin: null,
      procmax: null,
      from: null,
    });
  }

  open(id: number): void {
    void this.router.navigate(['/catalog/spells', id]);
  }

  /** Новое заклинание заводится в выбранном пуле - в нём же его и ищут. */
  create(): void {
    if (!this.canEdit()) return;
    const meta = this.meta();
    const block = meta?.blocks.find((item) => item.id === this.block()) ?? meta?.blocks[0];
    if (!block) {
      this.error.set('В мастерской нет доступных пулов ID.');
      return;
    }
    void this.router.navigate(['/catalog/spells', 'new'], { queryParams: { block: block.id } });
  }

  enums(name: string): Array<{ id: number; label: string }> {
    return this.meta()?.enums[name] ?? [];
  }

  async search(): Promise<void> {
    const requestId = ++this.requestId;
    this.loading.set(true);
    try {
      const rows = this.scope() === 'all' ? await this.searchClient() : await this.searchOwn();
      if (requestId !== this.requestId) return;
      this.rows.set(rows);
      this.error.set(null);
    } catch {
      if (requestId !== this.requestId) return;
      this.error.set('Поиск заклинаний не ответил.');
      this.rows.set([]);
      this.total.set(0);
    } finally {
      if (requestId === this.requestId) this.loading.set(false);
    }
  }

  private async searchOwn(): Promise<SpellRow[]> {
    const page = await firstValueFrom(
      this.api.search({
        q: this.query(),
        block: this.block(),
        module: this.module(),
        school: this.school(),
        effect: this.effect(),
        aura: this.aura(),
        procMin: this.procMin(),
        procMax: this.procMax(),
        offset: this.offset(),
        limit: this.perPage(),
      }),
    );
    this.total.set(page.total);
    return page.items.map((spell) => ({
      id: spell.id,
      title: text(spell.name_ru) || text(spell.name_en) || 'Без имени',
      subtitle:
        text(spell.name_ru) && text(spell.name_en) !== text(spell.name_ru)
          ? text(spell.name_en)
          : '',
      from: spell.module || spell.block_name || 'свой пул',
      does: spell.effects.join(' · '),
      tail: spell.proc_chance ? `${spell.proc_chance}%` : '—',
      icon: spell.icon_texture ?? '',
    }));
  }

  private async searchClient(): Promise<SpellRow[]> {
    const page = await firstValueFrom(
      this.dex.search({
        q: this.query(),
        source: '',
        school: this.school(),
        family: '',
        effect: this.effect(),
        aura: this.aura(),
        module: this.module(),
        block: this.block(),
        levelMin: '',
        levelMax: '',
        offset: this.offset(),
        limit: this.perPage(),
      }),
    );
    this.total.set(page.total);
    const sources: Record<string, string> = {
      dbc: 'клиент',
      override: 'правка поверх клиента',
      custom: 'своё',
    };
    return page.items.map((spell) => ({
      id: spell.id,
      title: spell.name || 'Без имени',
      subtitle: spell.rank ?? '',
      from: sources[spell.source] ?? spell.source,
      does: spell.schools.join(', '),
      tail: spell.level ? String(spell.level) : '—',
      icon: spell.icon ?? '',
    }));
  }
}
