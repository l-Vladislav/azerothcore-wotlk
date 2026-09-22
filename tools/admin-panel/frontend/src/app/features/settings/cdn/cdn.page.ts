import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { AuthService } from '../../../core/auth.service';
import { IconComponent } from '../../../shared/ui/icon.component';
import { ToastService } from '../../../shared/ui/toast.service';
import { CdnApi, FeedItem, UiDoc } from './cdn.api';
import { NEWS_SHOWN, allDated, parseNewsDate } from './news-order';

function blankItem(): FeedItem {
  return { date: today(), title: '', body: '', url: '' };
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

@Component({
  providers: [CdnApi],
  selector: 'app-cdn-page',
  imports: [FormsModule, IconComponent],
  styleUrl: './cdn.page.scss',
  templateUrl: './cdn.page.html',
})
export class CdnPage {
  private readonly api = inject(CdnApi);
  private readonly auth = inject(AuthService);
  private readonly toast = inject(ToastService);

  readonly news = signal<FeedItem[]>([]);
  readonly ui = signal<UiDoc>({});
  readonly loading = signal(true);
  readonly savingNews = signal(false);
  readonly savingUi = signal(false);
  readonly canEdit = computed(() => this.auth.actor()?.role === 'owner');

  readonly shownCount = NEWS_SHOWN;

  readonly sorted = computed(() => allDated(this.news()));
  readonly badDates = computed(
    () => this.news().filter((item) => item.date && parseNewsDate(item.date) === null).length,
  );

  constructor() {
    void this.load();
  }

  async load(): Promise<void> {
    this.loading.set(true);
    try {
      const [news, ui] = await Promise.all([
        firstValueFrom(this.api.news()),
        firstValueFrom(this.api.ui()),
      ]);
      this.news.set((news.items ?? []).map((item) => ({ ...blankItem(), ...item })));
      this.ui.set(this.normalize(ui ?? {}));
    } catch (error) {
      this.toast.show(this.text(error, 'Витрина недоступна: сборщик патча не отвечает.'), 'error');
    } finally {
      this.loading.set(false);
    }
  }

  /** Пустые разделы заводим сразу: иначе форму пришлось бы обвешивать «если есть». */
  private normalize(doc: UiDoc): UiDoc {
    return {
      play: { text: '', updateText: '', ...doc.play },
      news: { title: '', moreText: '', moreUrl: '', ...doc.news },
      community: { title: '', moreText: '', moreUrl: '', items: [], ...doc.community },
      header: { text: '', url: '', ...doc.header },
      links: doc.links ?? [],
    };
  }

  addNews(): void {
    this.news.update((items) => [blankItem(), ...items]);
  }

  removeNews(index: number): void {
    this.news.update((items) => items.filter((_, at) => at !== index));
  }

  moveNews(index: number, step: number): void {
    this.news.update((items) => {
      const next = [...items];
      const target = index + step;
      if (target < 0 || target >= next.length) return items;
      [next[index], next[target]] = [next[target], next[index]];
      return next;
    });
  }

  addCommunity(): void {
    this.ui.update((doc) => ({
      ...doc,
      community: { ...doc.community, items: [...(doc.community?.items ?? []), blankItem()] },
    }));
  }

  removeCommunity(index: number): void {
    this.ui.update((doc) => ({
      ...doc,
      community: {
        ...doc.community,
        items: (doc.community?.items ?? []).filter((_, at) => at !== index),
      },
    }));
  }

  addLink(): void {
    this.ui.update((doc) => ({ ...doc, links: [...(doc.links ?? []), { text: '', url: '' }] }));
  }

  removeLink(index: number): void {
    this.ui.update((doc) => ({
      ...doc,
      links: (doc.links ?? []).filter((_, at) => at !== index),
    }));
  }

  async saveNews(): Promise<void> {
    if (!this.canEdit() || this.savingNews()) return;
    const items = this.news().filter((item) => item.title.trim());
    this.savingNews.set(true);
    try {
      await firstValueFrom(this.api.saveNews(items));
      this.news.set(items);
      this.toast.show(
        `Новости записаны: ${items.length}. Игроки увидят их при следующем запуске лаунчера.`,
      );
    } catch (error) {
      this.toast.show(this.text(error, 'Новости записать не удалось.'), 'error');
    } finally {
      this.savingNews.set(false);
    }
  }

  async saveUi(): Promise<void> {
    if (!this.canEdit() || this.savingUi()) return;
    this.savingUi.set(true);
    try {
      await firstValueFrom(this.api.saveUi(this.cleaned()));
      this.toast.show('Подписи окна записаны.');
    } catch (error) {
      this.toast.show(this.text(error, 'Подписи записать не удалось.'), 'error');
    } finally {
      this.savingUi.set(false);
    }
  }

  /** Пустая кнопка на CDN хуже, чем её отсутствие: лаунчер прячет безымянные. */
  private cleaned(): UiDoc {
    const doc = this.ui();
    return {
      ...doc,
      links: (doc.links ?? []).filter((link) => link.text.trim()),
      community: {
        ...doc.community,
        items: (doc.community?.items ?? []).filter((item) => item.title.trim()),
      },
    };
  }

  private text(error: unknown, fallback: string): string {
    const detail = (error as { error?: { detail?: unknown } })?.error?.detail;
    return typeof detail === 'string' ? detail : fallback;
  }
}
