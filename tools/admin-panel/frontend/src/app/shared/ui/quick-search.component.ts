import { Component, ElementRef, computed, inject, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth.service';
import { FeatureNavigationRegistry } from '../../core/navigation/feature-navigation';
import { IconComponent } from './icon.component';

interface Hit {
  label: string;
  section: string;
  route: string;
  hint: string;
  icon: string;
}

/**
 * Ctrl+K: строка, из которой видно все страницы панели.
 *
 * Берёт тот же список разделов, что верхнее меню и карта, поэтому новая
 * страница появляется здесь сама. Ищет по названию, разделу и подписи -
 * «добыча», «мобы» и «кто что роняет» ведут в одно место.
 */
@Component({
  selector: 'app-quick-search',
  imports: [FormsModule, IconComponent],
  styleUrl: './quick-search.component.scss',
  host: {
    '(document:keydown)': 'onKey($event)',
  },
  template: `
    <dialog #dialog class="forge-dialog" (close)="query.set('')">
      <input
        class="forge-field is-search"
        #field
        type="search"
        [ngModel]="query()"
        (ngModelChange)="onQuery($event)"
        (keydown)="onFieldKey($event)"
        placeholder="Куда идём? Название страницы или что там делают"
        aria-label="Поиск по панели"
      />
      <ul role="listbox">
        @for (hit of hits(); track hit.route; let index = $index) {
          <li
            role="option"
            [attr.aria-selected]="index === cursor()"
            [class.active]="index === cursor()"
            (mouseenter)="cursor.set(index)"
            (click)="go(hit)"
          >
            <span class="icon"><app-icon [name]="hit.icon" /></span>
            <span class="name">
              <b>{{ hit.label }}</b>
              <small
                >{{ hit.section }}
                @if (hit.hint) {
                  · {{ hit.hint }}
                }
              </small>
            </span>
          </li>
        } @empty {
          <li class="empty">Ничего не нашлось.</li>
        }
      </ul>
      <footer>
        <span>↑ ↓ — выбор</span><span>Enter — открыть</span><span>Esc — закрыть</span>
      </footer>
    </dialog>
  `,
})
export class QuickSearchComponent {
  private readonly navigation = inject(FeatureNavigationRegistry);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  private readonly field = viewChild<ElementRef<HTMLInputElement>>('field');

  readonly query = signal('');
  readonly cursor = signal(0);

  private readonly pages = computed<Hit[]>(() =>
    this.navigation
      .all()
      .filter((section) => !section.ownerOnly || this.auth.actor()?.role === 'owner')
      .flatMap((section) =>
        section.items.map((item) => ({
          label: item.label,
          section: section.label,
          route: item.route,
          hint: item.hint ?? '',
          icon: item.icon ?? section.icon ?? 'dot',
        })),
      ),
  );

  readonly hits = computed(() => {
    const needle = this.query().trim().toLocaleLowerCase();
    if (!needle) return this.pages();
    return this.pages().filter((hit) =>
      `${hit.label} ${hit.section} ${hit.hint}`.toLocaleLowerCase().includes(needle),
    );
  });

  onKey(event: KeyboardEvent): void {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      this.open();
    }
  }

  open(): void {
    const dialog = this.dialog().nativeElement;
    if (dialog.open) return;
    this.query.set('');
    this.cursor.set(0);
    dialog.showModal();
    this.field()?.nativeElement.focus();
  }

  onQuery(value: string): void {
    this.query.set(value);
    this.cursor.set(0);
  }

  onFieldKey(event: KeyboardEvent): void {
    const hits = this.hits();
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      this.cursor.update((at) => (hits.length ? (at + 1) % hits.length : 0));
    }
    if (event.key === 'ArrowUp') {
      event.preventDefault();
      this.cursor.update((at) => (hits.length ? (at - 1 + hits.length) % hits.length : 0));
    }
    if (event.key === 'Enter') {
      event.preventDefault();
      const hit = hits[this.cursor()];
      if (hit) this.go(hit);
    }
  }

  go(hit: Hit): void {
    this.dialog().nativeElement.close();
    void this.router.navigateByUrl(hit.route);
  }
}
