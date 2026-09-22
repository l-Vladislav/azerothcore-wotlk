import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router, RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth.service';
import { CollapsibleSectionComponent } from '../../../shared/data/collapsible-section.component';
import { EditLockComponent } from '../../../shared/ui/edit-lock.component';
import { ForgeSelectDirective } from '../../../shared/ui/forge-select.directive';
import { GameIconComponent } from '../../../shared/ui/game-icon.component';
import { IconComponent } from '../../../shared/ui/icon.component';
import { IconPickerComponent } from '../../../shared/ui/icon-picker.component';
import { ToastService } from '../../../shared/ui/toast.service';
import { SpellCatalogApi, SpellDetail } from '../spell-catalog/spell-catalog.api';
import {
  PendingRestart,
  SpellFields,
  SpellWorkshopApi,
  WorkshopDetail,
  WorkshopField,
  WorkshopMeta,
} from './spell-workshop.api';

/**
 * Карточка одного заклинания: своё открывается редактором, клиентское -
 * справкой с кнопкой «создать копию».
 *
 * Какое из двух - решает сам сервер: своих заклинаний в `spell_dbc` всего
 * несколько сотен, и спрашивать о них первым дешевле, чем тянуть карточку из
 * каталога на пятьдесят тысяч строк ради одного признака.
 *
 * Черновик живёт в АДРЕСЕ (`/catalog/spells/new?clone=17962&block=...`), а не
 * в памяти страницы: иначе обновление вкладки теряло бы заготовку.
 */
@Component({
  providers: [SpellWorkshopApi, SpellCatalogApi],
  imports: [
    FormsModule,
    RouterLink,
    IconComponent,
    GameIconComponent,
    IconPickerComponent,
    EditLockComponent,
    CollapsibleSectionComponent,
    ForgeSelectDirective,
  ],
  selector: 'app-spell-card-page',
  styleUrl: './spell-card.page.scss',
  templateUrl: './spell-card.page.html',
})
export class SpellCardPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(SpellWorkshopApi);
  private readonly dex = inject(SpellCatalogApi);
  private readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  private readonly params = toSignal(this.route.paramMap, {
    initialValue: this.route.snapshot.paramMap,
  });

  readonly meta = signal<WorkshopMeta | null>(null);
  readonly spell = signal<WorkshopDetail | null>(null);
  readonly foreign = signal<SpellDetail | null>(null);
  readonly pending = signal<PendingRestart | null>(null);
  readonly iconBase = signal('');
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly locked = signal(true);
  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');
  readonly showLock = computed(() => this.canEdit() && !this.draft && !!this.spell());
  readonly canEditNow = computed(() => this.canEdit() && (this.draft || !this.locked()));
  readonly title = computed(() => {
    const alien = this.foreign();
    if (alien) return [alien.name, alien.rank].filter(Boolean).join(' — ') || 'Заклинание';
    const own = this.spell();
    if (!own) return 'Заклинание';
    // Пустая локаль в spell_dbc хранится нулём - именем это не считается.
    const text = (value: unknown): string =>
      typeof value === 'string' && value && value !== '0' ? value : '';
    return (
      text(this.fields['Name_Lang_ruRU']) || text(this.fields['Name_Lang_enUS']) || `#${own.id}`
    );
  });

  fields: SpellFields = {};
  module = '';
  iconTexture = '';
  notes = '';
  draft = false;

  constructor() {
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
    effect(() => {
      const params = this.params();
      untracked(() => void this.load(params));
    });
  }

  private async load(params: ParamMap): Promise<void> {
    this.loading.set(true);
    try {
      if (!this.meta()) this.meta.set(await firstValueFrom(this.api.catalog()));
      if (!this.iconBase()) void this.loadIconBase();
      void this.refreshPending();

      const raw = params.get('id') ?? '';
      const query = this.route.snapshot.queryParamMap;
      const clone = Number(query.get('clone')) || 0;
      const block = query.get('block') ?? '';

      if (raw === 'new') {
        await (clone ? this.startClone(clone, block) : this.startBlank(block));
        return;
      }

      const id = Number(raw);
      if (!Number.isSafeInteger(id) || id <= 0) {
        this.spell.set(null);
        this.foreign.set(null);
        return;
      }
      await this.openExisting(id);
    } catch {
      this.spell.set(null);
      this.foreign.set(null);
      this.error.set('Не удалось открыть заклинание.');
    } finally {
      this.loading.set(false);
    }
  }

  /** Сначала спрашиваем мастерскую: своё - правится, чужое - только читается. */
  private async openExisting(id: number): Promise<void> {
    try {
      this.apply(await firstValueFrom(this.api.detail(id)), false);
    } catch {
      this.spell.set(null);
      this.foreign.set(await firstValueFrom(this.dex.detail(id)));
    }
  }

  private async startClone(source: number, block: string): Promise<void> {
    const target = block || this.meta()?.blocks[0]?.id || '';
    this.apply(await firstValueFrom(this.api.clone(source, target)), true);
    this.notice.set(`Черновик копии #${source} с новым номером #${this.spell()?.id}.`);
  }

  private async startBlank(block: string): Promise<void> {
    const meta = this.meta();
    const pool = meta?.blocks.find((item) => item.id === block) ?? meta?.blocks[0];
    if (!pool) throw new Error('нет пулов');
    const next = await firstValueFrom(this.api.nextId(pool.id));
    this.apply(
      {
        id: next.id,
        block: pool.id,
        module: pool.module,
        icon_texture: '',
        notes: '',
        fields: this.emptyFields(),
      },
      true,
    );
    this.notice.set(`Черновик заклинания #${next.id}. Заполните поля и сохраните его.`);
  }

  private apply(detail: WorkshopDetail, draft: boolean): void {
    this.foreign.set(null);
    this.spell.set(detail);
    // Открытая карточка заперта; черновик копии правят сразу.
    this.locked.set(!draft);
    this.fields = { ...detail.fields };
    this.module = detail.module;
    this.iconTexture = detail.icon_texture;
    this.notes = detail.notes;
    this.draft = draft;
    this.error.set(null);
  }

  private async loadIconBase(): Promise<void> {
    try {
      const meta = await firstValueFrom(this.dex.meta());
      this.iconBase.set(meta.icon_base_url ?? '');
    } catch {
      // Без адреса иконок карточка работает - просто с контурным значком.
      this.iconBase.set('');
    }
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

  /** Копия - это новый адрес: черновик должен переживать обновление вкладки. */
  clone(block: string): void {
    const id = this.spell()?.id ?? this.foreign()?.id;
    if (!id || !this.canEdit()) return;
    void this.router.navigate(['/catalog/spells', 'new'], { queryParams: { clone: id, block } });
  }

  async save(): Promise<void> {
    const spell = this.spell();
    if (!spell || !this.canEdit()) return;
    const payload = {
      block: spell.block ?? '',
      module: this.module,
      icon_texture: this.iconTexture,
      notes: this.notes,
      fields: this.fields,
    };
    try {
      const saved = this.draft
        ? await firstValueFrom(this.api.create({ id: spell.id, ...payload }))
        : await firstValueFrom(this.api.save(spell.id, payload));
      const wasDraft = this.draft;
      this.draft = false;
      this.notice.set(
        saved.problems.length
          ? `Заклинание сохранено с предупреждениями: ${saved.problems.map((item) => item.text).join('; ')}`
          : 'Заклинание сохранено. Для применения на PTR потребуется перезапуск.',
      );
      void this.refreshPending();
      // Черновик стал записью - адрес должен говорить о ней, а не о заготовке.
      if (wasDraft) {
        void this.router.navigate(['/catalog/spells', saved.id], { replaceUrl: true });
        return;
      }
      this.apply(await firstValueFrom(this.api.detail(saved.id)), false);
    } catch {
      this.error.set('Не удалось сохранить заклинание. Проверьте обязательные поля.');
    }
  }

  async deleteSpell(): Promise<void> {
    const spell = this.spell();
    if (!spell || this.draft || !this.canEdit()) return;
    if (!confirm(`Удалить заклинание #${spell.id}?`)) return;
    try {
      await firstValueFrom(this.api.delete(spell.id));
      this.notice.set(`Заклинание #${spell.id} удалено.`);
      void this.router.navigate(['/catalog/spells']);
    } catch {
      this.error.set('Не удалось удалить заклинание.');
    }
  }

  options(field: WorkshopField): Array<{ id: number; label: string }> {
    const meta = this.meta();
    if (!meta) return [];
    return field.kind === 'ref'
      ? (meta.refs[field.ref ?? ''] ?? [])
      : (meta.enums[field.enum ?? ''] ?? []);
  }

  /**
   * Что показать в кружке. Выбранная в панели текстура главнее, но если её не
   * выбирали - берём ту, что рисует клиент, иначе у всего, что пришло из
   * модулей, карточка пустая, хотя в списке картинка есть.
   *
   * Метод, а не `computed`: `iconTexture` - обычное поле под `ngModel`, и
   * сигнальный кэш не увидел бы, как его правят в поле ввода.
   */
  iconPreview(): string {
    return this.iconTexture || this.spell()?.icon_resolved || '';
  }

  effectColumn(field: WorkshopField, index: number): string {
    return field.col.replace('%d', String(index));
  }

  blockName(id?: string | null): string {
    if (!id) return 'вне пулов';
    return this.meta()?.blocks.find((block) => block.id === id)?.name ?? id;
  }

  private emptyFields(): SpellFields {
    const meta = this.meta();
    if (!meta) return {};
    const fields: SpellFields = {};
    for (const group of meta.groups) {
      for (const field of group.fields) fields[field.col] = field.kind === 'text' ? '' : 0;
    }
    for (const index of [1, 2, 3]) {
      for (const field of meta.effect_fields) {
        fields[this.effectColumn(field, index)] = field.kind === 'text' ? '' : 0;
      }
    }
    return fields;
  }
}
