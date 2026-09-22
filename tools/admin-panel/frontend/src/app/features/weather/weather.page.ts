import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { ToastService } from '../../shared/ui/toast.service';
import {
  WeatherApi,
  WeatherLinkDraft,
  WeatherLinks,
  WeatherZoneLink,
  WeatherZone,
  ZoneClimate,
} from './weather.api';
import { WeatherOverviewStore } from './weather-overview.store';
import { IconComponent } from '../../shared/ui/icon.component';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';

const seasonLabels: Record<string, string> = {
  spring: 'весна',
  summer: 'лето',
  fall: 'осень',
  winter: 'зима',
};

@Component({
  imports: [FormsModule, IconComponent, RouterLink, ForgeSelectDirective],
  providers: [WeatherApi, WeatherOverviewStore],
  selector: 'app-weather-page',
  styleUrl: './weather.page.scss',
  templateUrl: './weather.page.html',
})
export class WeatherPage implements OnInit, OnDestroy {
  private readonly api = inject(WeatherApi);
  private readonly route = inject(ActivatedRoute);
  private readonly toast = inject(ToastService);

  // Обзор, выбор зоны и опрос - общие с картой (`WeatherOverviewStore`).
  // Шаблон зовёт их по коротким именам, как звал собственные сигналы.
  readonly store = inject(WeatherOverviewStore);
  readonly overview = this.store.overview;
  readonly selectedId = this.store.selectedId;
  readonly selectedZone = this.store.selectedZone;
  readonly loading = this.store.loading;
  readonly pending = this.store.pending;
  readonly error = this.store.error;
  readonly canEdit = this.store.canEdit;

  // Климат: что пришло с сервера и что правит хозяин. Черновик отдельно -
  // иначе «Отменить правку» нечем было бы отменять.
  readonly climate = signal<ZoneClimate | null>(null);
  readonly climateDraft = signal<Record<string, Record<string, number>>>({});
  readonly seasons = ['spring', 'summer', 'fall', 'winter'];
  readonly kinds = ['rain', 'snow', 'storm'];
  readonly climateDirty = computed(() => {
    const source = this.climate()?.seasons;
    if (!source) return false;
    return this.seasons.some((season) =>
      this.kinds.some((kind) => (source[season]?.[kind] ?? 0) !== this.chance(season, kind)),
    );
  });

  readonly links = signal<WeatherLinks | null>(null);
  readonly linkDraft = signal<WeatherLinkDraft[]>([]);
  readonly linkToAdd = signal<number | null>(null);
  readonly linksLoading = signal(false);
  readonly linksError = signal<string | null>(null);

  constructor() {
    // Сообщения об удаче и отказе показываются всплывающими
    // плашками: строка наверху страницы сдвигала содержимое и
    // висела до следующего действия.
    this.toast.announce(this.error, 'error');
  }

  async ngOnInit(): Promise<void> {
    this.store.onSelect = (zoneId) => {
      this.resetLinks();
      this.climate.set(null);
      this.climateDraft.set({});
      if (zoneId !== null) {
        void this.loadLinks(zoneId);
        void this.loadClimate(zoneId);
      }
    };
    // Зона - из адреса, а не из чужого выбора: `paramMap` переживает и
    // обновление страницы, и приход по ссылке.
    this.route.paramMap.subscribe((params) => {
      const id = Number(params.get('zone'));
      if (Number.isFinite(id) && id > 0) this.store.select(id);
    });
    await this.store.start();
  }

  ngOnDestroy(): void {
    this.store.stop();
  }

  seasonLabel(season: string): string {
    return seasonLabels[season] ?? season;
  }

  availableLinkZones(zone: WeatherZone): WeatherZone[] {
    const taken = new Set(this.linkDraft().map((link) => link.linked_zone));
    return (this.overview()?.zones ?? []).filter(
      (candidate) => candidate.zone_id !== zone.zone_id && !taken.has(candidate.zone_id),
    );
  }

  savedLink(zoneId: number): WeatherZoneLink | null {
    return this.links()?.out.find((link) => link.zone_id === zoneId) ?? null;
  }

  linkName(zoneId: number): string {
    return (
      this.savedLink(zoneId)?.name ??
      this.overview()?.zones.find((zone) => zone.zone_id === zoneId)?.name ??
      `Зона ${zoneId}`
    );
  }

  previewText(zoneId: number): string {
    const preview = this.savedLink(zoneId)?.preview;
    if (!preview) return 'В зоне-источнике сейчас ясно — переносить нечего.';
    return `Сейчас там: ${preview.from_label} → ${preview.label} (${preview.grade}%)${preview.adapted ? ', приведено к климату зоны' : ''}`;
  }

  strengthHint(strength: number): string {
    const level = Math.round((4 * strength) / 100);
    const words = ['ничего', 'морось', 'дождь', 'ливень', 'та же гроза'];
    return `гроза придёт как «${words[level]}»`;
  }

  updateLink(index: number, patch: Partial<WeatherLinkDraft>): void {
    this.linkDraft.update((links) =>
      links.map((link, current) => {
        if (current !== index) return link;
        const next = { ...link, ...patch };
        return { ...next, strength: Math.max(1, Math.min(100, Number(next.strength) || 1)) };
      }),
    );
  }

  addLink(): void {
    const zoneId = this.linkToAdd();
    const selected = this.selectedZone();
    if (
      zoneId === null ||
      !selected ||
      !this.availableLinkZones(selected).some((zone) => zone.zone_id === zoneId)
    )
      return;
    this.linkDraft.update((links) => [
      ...links,
      { linked_zone: zoneId, strength: 49, enabled: true, comment: '', mirror: true },
    ]);
    this.linkToAdd.set(null);
  }

  setLinkToAdd(value: string | number): void {
    const zoneId = Number(value);
    this.linkToAdd.set(Number.isInteger(zoneId) && zoneId > 0 ? zoneId : null);
  }

  removeLink(index: number): void {
    this.linkDraft.update((links) => links.filter((_, current) => current !== index));
  }

  resetLinkDraft(zone: WeatherZone): void {
    this.resetLinks();
    void this.loadLinks(zone.zone_id);
  }

  async saveLinks(zone: WeatherZone): Promise<void> {
    if (!this.canEdit()) return;
    this.pending.set('links');
    this.error.set(null);
    try {
      const saved = await firstValueFrom(this.api.saveLinks(zone.zone_id, this.linkDraft()));
      if (this.selectedId() !== zone.zone_id) return;
      this.setLinks(saved);
      this.toast.show('Связи сохранены и перечитаны сервером.');
      await this.store.load(true);
    } catch (error) {
      this.error.set(this.store.errorText(error, `Не удалось сохранить связи зоны «${zone.name}».`));
    } finally {
      this.pending.set(null);
    }
  }

  chance(season: string, kind: string): number {
    const draft = this.climateDraft()[season]?.[kind];
    if (draft !== undefined) return draft;
    return this.climate()?.seasons[season]?.[kind] ?? 0;
  }

  setChance(season: string, kind: string, value: number): void {
    const clean = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
    this.climateDraft.update((draft) => ({
      ...draft,
      [season]: { ...(draft[season] ?? {}), [kind]: clean },
    }));
  }

  resetClimate(): void {
    this.climateDraft.set({});
  }

  async saveClimate(zone: WeatherZone): Promise<void> {
    if (!this.canEdit() || this.pending()) return;
    this.pending.set('climate');
    this.error.set(null);
    try {
      const seasons: Record<string, Record<string, number>> = {};
      for (const season of this.seasons) {
        seasons[season] = {};
        for (const kind of this.kinds) seasons[season][kind] = this.chance(season, kind);
      }
      this.climate.set(await firstValueFrom(this.api.saveClimate(zone.zone_id, seasons)));
      this.climateDraft.set({});
      this.toast.show('Климат записан. Заработает после перезапуска мира.');
    } catch (error) {
      this.error.set(this.store.errorText(error, 'Не удалось записать климат зоны.'));
    } finally {
      this.pending.set(null);
    }
  }

  private async loadClimate(zoneId: number): Promise<void> {
    try {
      const data = await firstValueFrom(this.api.climate(zoneId));
      if (this.selectedId() === zoneId) this.climate.set(data);
    } catch (error) {
      if (this.selectedId() === zoneId) {
        this.error.set(this.store.errorText(error, 'Не удалось прочитать климат зоны.'));
      }
    }
  }

  private resetLinks(): void {
    this.links.set(null);
    this.linkDraft.set([]);
    this.linkToAdd.set(null);
    this.linksError.set(null);
  }

  private async loadLinks(zoneId: number): Promise<void> {
    this.linksLoading.set(true);
    try {
      const data = await firstValueFrom(this.api.links(zoneId));
      if (this.selectedId() !== zoneId) return;
      this.setLinks(data);
    } catch (error) {
      if (this.selectedId() === zoneId) {
        this.linksError.set(this.store.errorText(error, 'Не удалось получить связи выбранной зоны.'));
      }
    } finally {
      if (this.selectedId() === zoneId) this.linksLoading.set(false);
    }
  }

  private setLinks(data: WeatherLinks): void {
    this.links.set(data);
    this.linkDraft.set(
      data.out.map((link) => ({
        linked_zone: link.zone_id,
        strength: link.strength,
        enabled: link.enabled,
        comment: link.comment,
        mirror: link.mirror,
      })),
    );
    this.linksError.set(null);
  }
}
