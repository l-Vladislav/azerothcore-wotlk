import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, ParamMap, RouterLink } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { apiError } from './loot-format';
import { LootNameTagComponent } from './loot-name-tag.component';
import { LootTreeComponent } from './loot-tree.component';
import { CreatureLoot, LootApi, LootMeta } from './loot.api';
import { IconComponent } from '../../shared/ui/icon.component';
import { ToastService } from '../../shared/ui/toast.service';

/**
 * Карточка существа: три вида добычи с деревьями. Список существ переехал на
 * соседнюю страницу (`creature-list.page`) - вместе они были одной страницей,
 * где список ютился в узкой колонке, а дерево делило с ним ширину.
 *
 * Номер существа приходит из АДРЕСА (`/loot/creatures/17`), а не из
 * параметра: карточка - отдельная страница, и ссылка на неё должна открывать
 * её, а не список с выбранной строкой.
 */
@Component({
  providers: [LootApi],
  selector: 'app-creature-loot-page',
  imports: [RouterLink, LootTreeComponent, LootNameTagComponent, IconComponent],
  styleUrl: './creature-loot.page.scss',
  templateUrl: './creature-loot.page.html',
})
export class CreatureLootPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(LootApi);
  private readonly route = inject(ActivatedRoute);
  readonly auth = inject(AuthService);

  private readonly params = toSignal(this.route.paramMap, {
    initialValue: this.route.snapshot.paramMap,
  });
  private lastCreature = '';

  readonly meta = signal<LootMeta | null>(null);
  readonly detail = signal<CreatureLoot | null>(null);
  readonly loadingDetail = signal(false);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);
  readonly selected = signal(0);

  readonly canEditRows = computed(() => this.auth.actor()?.role === 'owner');
  readonly canLabel = computed(() =>
    ['editor', 'owner'].includes(this.auth.actor()?.role ?? 'viewer'),
  );

  constructor() {
    this.toast.announce(this.error, 'error');
    this.toast.announce(this.notice);
    effect(() => {
      const params = this.params();
      untracked(() => this.applyParams(params));
    });
    void this.loadMeta();
  }

  private async loadMeta(): Promise<void> {
    try {
      this.meta.set(await firstValueFrom(this.api.meta()));
    } catch (error) {
      this.error.set(apiError(error, 'Таблиц добычи в этой базе нет.'));
    }
  }

  private applyParams(params: ParamMap): void {
    this.selected.set(Number(params.get('entry')) || 0);
    const creature = String(this.selected());
    if (creature !== this.lastCreature) {
      this.lastCreature = creature;
      void this.loadDetail();
    }
  }

  async loadDetail(): Promise<void> {
    const entry = this.selected();
    if (!entry) {
      this.detail.set(null);
      return;
    }
    this.loadingDetail.set(true);
    try {
      this.detail.set(await firstValueFrom(this.api.creature(entry)));
      this.error.set(null);
    } catch (error) {
      this.detail.set(null);
      this.error.set(apiError(error, `Не удалось прочитать добычу существа ${entry}.`));
    } finally {
      this.loadingDetail.set(false);
    }
  }

  onNotice(message: string): void {
    this.notice.set(message);
  }
}
