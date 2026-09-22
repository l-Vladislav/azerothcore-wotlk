import { Component, OnDestroy, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { boardDropPosition } from './board-order';
import { ForgeSelectDirective } from '../../shared/ui/forge-select.directive';
import { IconComponent, IconName } from '../../shared/ui/icon.component';
import { ToastService } from '../../shared/ui/toast.service';
import {
  BoardApi,
  BoardCard,
  BoardCardInput,
  BoardComment,
  BoardKind,
  BoardModule,
  BoardStatus,
} from './board.api';

interface BoardColumn {
  id: BoardStatus;
  label: string;
}

interface BoardForm extends BoardCardInput {
  id?: number;
  archived: boolean;
  created_at: string;
  updated_at: string;
  comments: BoardComment[];
}

const columns: readonly BoardColumn[] = [
  { id: 'backlog', label: 'Идеи / бэклог' },
  { id: 'todo', label: 'К работе' },
  { id: 'doing', label: 'В работе' },
  { id: 'review', label: 'На проверке' },
  { id: 'done', label: 'Готово' },
];

// Значок - имя из своего набора (`IconComponent`), а не эмодзи: эмодзи
// рисует системный шрифт, и на карточке он лез цветным пятном поперёк скина.
const kinds: ReadonlyArray<{ id: BoardKind; label: string; icon: IconName }> = [
  { id: 'bug', label: 'Баг', icon: 'bug' },
  { id: 'feature', label: 'Идея', icon: 'idea' },
  { id: 'task', label: 'Задача', icon: 'task' },
];

const priorities = [
  { id: 0, label: 'Низкий' },
  { id: 1, label: 'Обычный' },
  { id: 2, label: 'Высокий' },
  { id: 3, label: 'Критичный' },
];

@Component({
  imports: [FormsModule, IconComponent, ForgeSelectDirective],
  providers: [BoardApi],
  selector: 'app-board-page',
  styleUrl: './board.page.scss',
  templateUrl: './board.page.html',
})
export class BoardPage implements OnInit, OnDestroy {
  private readonly api = inject(BoardApi);
  private readonly route = inject(ActivatedRoute);
  private readonly toast = inject(ToastService);
  private searchTimer: ReturnType<typeof setTimeout> | undefined;
  private dragId: number | null = null;
  private loadId = 0;
  readonly moving = signal(false);
  readonly refreshing = signal(false);
  readonly dragging = signal<number | null>(null);
  readonly dropTarget = signal<{ status: BoardStatus; index: number } | null>(null);

  readonly columns = columns;
  readonly kinds = kinds;
  readonly priorities = priorities;
  readonly cards = signal<BoardCard[]>([]);
  readonly modules = signal<BoardModule[]>([]);
  readonly loading = signal(true);
  readonly modalOpen = signal(false);
  readonly saving = signal(false);
  readonly archived = signal(false);

  filters = { q: '', module: '', kind: '' };
  form: BoardForm = this.emptyForm();
  commentText = '';

  async ngOnInit(): Promise<void> {
    const module = this.route.snapshot.queryParamMap.get('module');
    if (module) this.filters.module = module;
    try {
      const meta = await firstValueFrom(this.api.meta());
      this.modules.set(meta.modules);
      await this.load();
    } catch {
      this.toast.show('Не удалось загрузить доску задач.', 'error');
    } finally {
      this.loading.set(false);
    }

    if (this.route.snapshot.queryParamMap.has('new')) this.newCard();
  }

  ngOnDestroy(): void {
    clearTimeout(this.searchTimer);
    ++this.loadId;
  }

  scheduleLoad(): void {
    clearTimeout(this.searchTimer);
    this.refreshing.set(true);
    this.searchTimer = setTimeout(() => void this.load(), 250);
  }

  async load(): Promise<void> {
    clearTimeout(this.searchTimer);
    const requestId = ++this.loadId;
    this.refreshing.set(true);
    try {
      const cards = await firstValueFrom(
        this.api.cards({ ...this.filters, archived: this.archived() }),
      );
      if (requestId !== this.loadId) return;
      this.cards.set(cards);
    } catch {
      if (requestId === this.loadId)
        this.toast.show('Не удалось обновить карточки доски.', 'error');
    } finally {
      if (requestId === this.loadId) this.refreshing.set(false);
    }
  }

  cardsIn(status: BoardStatus): BoardCard[] {
    return this.cards().filter((card) => card.status === status);
  }

  kind(card: { kind: BoardKind }) {
    return this.kinds.find((kind) => kind.id === card.kind) ?? this.kinds[0];
  }

  moduleName(id: string): string {
    return this.modules().find((module) => module.id === id)?.name ?? id;
  }

  toggleArchive(): void {
    this.archived.update((value) => !value);
    void this.load();
  }

  setTags(value: string): void {
    this.form.tags = value
      .split(',')
      .map((tag) => tag.trim())
      .filter(Boolean);
  }

  newCard(status: BoardStatus = 'backlog'): void {
    this.form = this.emptyForm(status);
    this.commentText = '';
    this.modalOpen.set(true);
  }

  async openCard(id: number): Promise<void> {
    if (this.dragId !== null || this.moving()) return;
    try {
      this.form = this.toForm(await firstValueFrom(this.api.card(id)));
      this.commentText = '';
      this.modalOpen.set(true);
    } catch {
      this.toast.show(`Не удалось открыть карточку #${id}.`, 'error');
    }
  }

  closeModal(): void {
    if (!this.saving()) this.modalOpen.set(false);
  }

  async save(): Promise<void> {
    if (!this.form.title.trim() || this.saving()) {
      if (!this.form.title.trim()) this.toast.show('У карточки должен быть заголовок.', 'error');
      return;
    }
    this.saving.set(true);
    const payload = this.payload();
    try {
      const saved = this.form.id
        ? await firstValueFrom(this.api.update(this.form.id, payload))
        : await firstValueFrom(this.api.create(payload));
      this.form = this.toForm(saved);
      this.modalOpen.set(false);
      this.toast.show('Карточка сохранена.');
      await this.load();
    } catch {
      this.toast.show('Не удалось сохранить карточку.', 'error');
    } finally {
      this.saving.set(false);
    }
  }

  async archiveOrRestore(): Promise<void> {
    if (!this.form.id || this.saving()) return;
    this.saving.set(true);
    try {
      if (this.form.archived) await firstValueFrom(this.api.restore(this.form.id));
      else await firstValueFrom(this.api.archive(this.form.id));
      this.modalOpen.set(false);
      this.toast.show(
        this.form.archived ? 'Карточка возвращена на доску.' : 'Карточка перемещена в архив.',
      );
      await this.load();
    } catch {
      this.toast.show('Не удалось изменить состояние карточки.', 'error');
    } finally {
      this.saving.set(false);
    }
  }

  async addComment(): Promise<void> {
    const body = this.commentText.trim();
    if (!this.form.id || !body || this.saving()) return;
    this.saving.set(true);
    try {
      this.form = this.toForm(await firstValueFrom(this.api.addComment(this.form.id, body)));
      this.commentText = '';
      await this.load();
    } catch {
      this.toast.show('Не удалось добавить комментарий.', 'error');
    } finally {
      this.saving.set(false);
    }
  }

  dragStart(card: BoardCard, event: DragEvent): void {
    if (this.archived() || this.moving() || this.refreshing()) {
      event.preventDefault();
      return;
    }
    this.dragId = card.id;
    this.dragging.set(card.id);
    event.dataTransfer?.setData('text/plain', String(card.id));
    if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move';
  }

  dragEnd(): void {
    this.dragId = null;
    this.dragging.set(null);
    this.dropTarget.set(null);
  }

  dragOver(status: BoardStatus, event: DragEvent): void {
    if (this.dragId === null || this.moving() || this.refreshing()) return;
    event.preventDefault();
    if (event.dataTransfer) event.dataTransfer.dropEffect = 'move';
    this.dropTarget.set({
      status,
      index: this.dropIndex(event.currentTarget as HTMLElement, event.clientY),
    });
  }

  dragLeave(event: DragEvent): void {
    const list = event.currentTarget as HTMLElement;
    if (!(event.relatedTarget instanceof Node) || !list.contains(event.relatedTarget)) {
      this.dropTarget.set(null);
    }
  }

  insertionBefore(status: BoardStatus, id: number): boolean {
    const target = this.dropTarget();
    return (
      target?.status === status &&
      this.cardsIn(status).filter((card) => card.id !== this.dragging())[target.index]?.id === id
    );
  }

  insertionAtEnd(status: BoardStatus): boolean {
    const target = this.dropTarget();
    return (
      target?.status === status &&
      target.index === this.cardsIn(status).filter((card) => card.id !== this.dragging()).length
    );
  }

  async drop(status: BoardStatus, event: DragEvent): Promise<void> {
    event.preventDefault();
    const id = this.dragId;
    if (id === null || this.archived() || this.moving() || this.refreshing()) {
      this.dragEnd();
      return;
    }
    const list = event.currentTarget as HTMLElement;
    const index = this.dropIndex(list, event.clientY);
    const visibleIds = this.cardsIn(status)
      .filter((card) => card.id !== id)
      .map((card) => card.id);
    this.dragEnd();
    this.moving.set(true);
    ++this.loadId;
    try {
      const filtered = Boolean(this.filters.q || this.filters.module || this.filters.kind);
      const allCards = filtered ? await firstValueFrom(this.api.cards({})) : this.cards();
      const fullIds = allCards
        .filter((card) => card.status === status && card.id !== id)
        .map((card) => card.id);
      const position = boardDropPosition(fullIds, visibleIds, index);
      const moved = await firstValueFrom(this.api.move(id, status, position));
      if (filtered) await this.load();
      else this.cards.set(moved);
    } catch {
      this.toast.show('Не удалось переместить карточку.', 'error');
    } finally {
      this.moving.set(false);
    }
  }

  private dropIndex(list: HTMLElement, y: number): number {
    let index = 0;
    for (const node of list.querySelectorAll<HTMLElement>('[data-card-id]')) {
      if (Number(node.dataset['cardId']) === this.dragId) continue;
      const box = node.getBoundingClientRect();
      if (y > box.top + box.height / 2) index++;
    }
    return index;
  }

  private payload(): BoardCardInput {
    return {
      kind: this.form.kind,
      status: this.form.status,
      priority: Number(this.form.priority),
      title: this.form.title.trim(),
      body: this.form.body,
      module: this.form.module,
      tags: this.form.tags,
      assignee: this.form.assignee,
    };
  }

  private emptyForm(status: BoardStatus = 'backlog'): BoardForm {
    return {
      kind: 'bug',
      status,
      priority: 1,
      title: '',
      body: '',
      module: this.filters.module,
      tags: [],
      assignee: '',
      archived: false,
      created_at: '',
      updated_at: '',
      comments: [],
    };
  }

  private toForm(card: BoardCard): BoardForm {
    return {
      ...card,
      tags: [...card.tags],
      comments: Array.isArray(card.comments) ? card.comments : [],
    };
  }
}
