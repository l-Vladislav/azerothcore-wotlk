import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { ToastService } from '../../shared/ui/toast.service';
import {
  ItemType,
  Material,
  MatchResult,
  ProfessionsApi,
  ProfessionsMeta,
  TypePart,
} from './professions.api';
import { apiError, qualityName, statName } from './professions.model';

/**
 * Проверка набора: что выйдет у верстака, не заходя в игру.
 *
 * Ответ считает СЕРВЕР той же ручкой, что и ковка (`/aprof/match`), - иначе
 * страница показывала бы свою версию правил, и расхождение с игрой заметили бы
 * последним.
 */
@Component({
  imports: [FormsModule, ForgeSelectDirective],
  providers: [ProfessionsApi],
  selector: 'app-professions-preview-page',
  styleUrl: './preview.page.scss',
  templateUrl: './preview.page.html',
})
export class ProfessionsPreviewPage {
  private readonly toast = inject(ToastService);
  private readonly api = inject(ProfessionsApi);

  readonly meta = signal<ProfessionsMeta | null>(null);
  readonly types = signal<ItemType[]>([]);
  readonly materials = signal<Material[]>([]);
  readonly parts = signal<TypePart[]>([]);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);

  readonly typeId = signal(0);
  readonly skill = signal(300);
  readonly slots = signal<number[]>([]);
  /** Набор по ячейкам: ключ - номер части, значение - предмет и его расход. */
  readonly partMats = signal<Record<number, number>>({});
  readonly partCounts = signal<Record<number, number>>({});
  readonly result = signal<MatchResult | null>(null);

  readonly inserts = computed(() => this.materials().filter((mat) => mat.role !== 'base'));

  constructor() {
    this.toast.announce(this.error, 'error');
    void this.load();
  }

  async load(): Promise<void> {
    this.loading.set(true);
    try {
      const meta = await firstValueFrom(this.api.meta());
      this.meta.set(meta);
      if (meta.available) {
        this.slots.set(Array.from({ length: meta.max_slots }, () => 0));
        const [types, materials] = await Promise.all([
          firstValueFrom(this.api.types()),
          firstValueFrom(this.api.materials()),
        ]);
        this.types.set(types.types);
        this.materials.set(materials.materials);
        if (types.types.length) await this.onType(types.types[0].id);
      }
    } catch (error) {
      this.error.set(apiError(error, 'Не удалось загрузить справочники.'));
    } finally {
      this.loading.set(false);
    }
  }

  /** Ячейки зависят от типа, поэтому читаются заново при каждой смене. */
  async onType(id: number): Promise<void> {
    this.typeId.set(id);
    this.partMats.set({});
    this.partCounts.set({});
    this.result.set(null);
    try {
      this.parts.set((await firstValueFrom(this.api.parts(id))).parts);
    } catch {
      // У типа может не быть ячеек вовсе - это не отказ, а пустая схема.
      this.parts.set([]);
    }
  }

  matName(mat: Material): string {
    return mat.name_ru || mat.item?.name || String(mat.entry);
  }

  /** Ячейка «лезвие» ждёт металл: ткань в ней сделала бы набор несобираемым. */
  partOptions(kindId: number): Material[] {
    return this.materials().filter((mat) => mat.role === 'base' && mat.part_kind_id === kindId);
  }

  partMat(idx: number): number {
    return this.partMats()[idx] ?? 0;
  }

  partCount(idx: number): number {
    return this.partCounts()[idx] ?? 1;
  }

  setSlot(index: number, entry: number): void {
    this.slots.update((slots) => slots.map((slot, at) => (at === index ? entry : slot)));
  }

  setPartMat(idx: number, entry: number): void {
    this.partMats.update((mats) => ({ ...mats, [idx]: entry }));
  }

  setPartCount(idx: number, count: number): void {
    this.partCounts.update((counts) => ({ ...counts, [idx]: count }));
  }

  tierName(quality: number): string {
    return qualityName(this.meta(), quality);
  }

  statLabel(id: number): string {
    return statName(this.meta(), id);
  }

  spendText(out: MatchResult): string {
    return out.spend.map((row) => `${row.name} ×${row.count}`).join(', ');
  }

  async check(): Promise<void> {
    if (this.busy()) return;
    this.busy.set(true);
    try {
      const parts = this.parts();
      this.result.set(
        await firstValueFrom(
          this.api.match({
            type_id: this.typeId(),
            skill: this.skill(),
            mats: this.slots().filter(Boolean),
            part_mats: parts.map((part) => this.partMat(part.idx)),
            part_counts: parts.map((part) => this.partCount(part.idx)),
          }),
        ),
      );
      this.error.set(null);
    } catch (error) {
      this.result.set(null);
      this.error.set(apiError(error, 'Проверка не ответила.'));
    } finally {
      this.busy.set(false);
    }
  }
}
