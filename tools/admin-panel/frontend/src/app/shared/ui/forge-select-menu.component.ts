import { Component, ElementRef, computed, inject, output, signal } from '@angular/core';

export interface ForgeSelectOption {
  index: number;
  label: string;
  disabled: boolean;
}

/** На столько меню отступает от поля, чтобы не наезжать на его кромку. */
const gap = 4;
/** Высота строки вместе с кромкой; нужна только чтобы выбрать сторону. */
const rowHeight = 50;
/** Пока меню не измерено, считаем его шириной поля - оно не уже. */
const unmeasured = 0;
/** Выше меню не растёт: дальше это уже не список, а простыня. */
const maxMenuHeight = 360;

/**
 * Строка меню НЕ забирает фокус (`mousedown` гасится): фокус обязан остаться
 * на самом `<select>`. Иначе он теряет фокус ещё до `click`, директива ловит
 * `blur`, закрывает меню - и щелчок по строке приземляться уже некуда, выбор
 * не доходит.
 *
 * Само меню раскрывающегося списка - то, что рисуется вместо браузерного
 * окна. Ставит его `ForgeSelectDirective`, прямо в `<body>`; здесь только вид,
 * клавиатура и выбор.
 */
@Component({
  selector: 'app-forge-select-menu',
  styleUrl: './forge-select-menu.component.scss',
  host: {
    '(document:mousedown)': 'outside($event)',
    '(window:resize)': 'dismissed.emit()',
    '(document:scroll)': 'dismissed.emit()',
  },
  template: `
    <div
      class="menu"
      role="listbox"
      [style.left.px]="box().left"
      [style.top.px]="box().top"
      [style.min-width.px]="box().width"
      [style.max-height.px]="box().maxHeight"
    >
      @for (option of options(); track option.index) {
        <button
          type="button"
          class="row"
          role="option"
          [attr.aria-selected]="option.index === current()"
          [class.is-current]="option.index === current()"
          [class.is-active]="option.index === active()"
          [disabled]="option.disabled"
          (mousedown)="$event.preventDefault()"
          (mouseenter)="active.set(option.index)"
          (click)="picked.emit(option.index)"
        >
          {{ option.label }}
        </button>
      }
    </div>
  `,
})
export class ForgeSelectMenuComponent {
  private readonly el = inject<ElementRef<HTMLElement>>(ElementRef);

  /**
   * Ширина меню ПОСЛЕ отрисовки. Считать её заранее нельзя: она зависит от
   * самой длинной строки, а строка одета в кромку набора. Без этого меню у
   * правого края экрана оставалось шириной с поле, и длинные пункты в нём
   * обрывались, хотя места на экране хватало.
   */
  private readonly measured = signal(unmeasured);

  readonly options = signal<readonly ForgeSelectOption[]>([]);
  readonly current = signal(0);
  readonly anchor = signal<DOMRect | null>(null);
  /** Само поле: клик по нему не считается кликом «мимо». */
  readonly anchorEl = signal<HTMLElement | null>(null);
  readonly active = signal(0);

  readonly picked = output<number>();
  readonly dismissed = output<void>();

  /**
   * Где раскрыться. Вниз, если там есть место, иначе вверх: список у нижнего
   * края экрана иначе уезжает за него и половина строк недоступна.
   */
  readonly box = computed(() => {
    const rect = this.anchor();
    if (!rect) return { left: 0, top: 0, width: 160, maxHeight: 320 };
    const wanted = Math.min(this.options().length * rowHeight + 30, maxMenuHeight);
    const below = window.innerHeight - rect.bottom - gap - 8;
    const above = rect.top - gap - 8;
    const down = below >= Math.min(wanted, 160) || below >= above;
    // Потолок, а не рост: высоту меню задаёт содержимое. Считать её по числу
    // строк нельзя - строка одета в кромку набора, и её настоящий рост
    // зависит от неё, а не от кегля.
    const maxHeight = Math.max(140, Math.min(maxMenuHeight, down ? below : above));
    // Ширину для расчёта берём измеренную: меню шире поля, и упереться в край
    // экрана оно должно своим краем, а не полевым.
    const width = Math.max(this.measured(), rect.width);
    return {
      left: Math.max(8, Math.min(rect.left, window.innerWidth - width - 8)),
      top: down ? rect.bottom + gap : rect.top - gap - maxHeight,
      width: rect.width,
      maxHeight,
    };
  });

  constructor() {
    queueMicrotask(() => {
      this.active.set(this.current());
      this.scrollToActive();
      this.remeasure();
    });
  }

  /** Померить отрисованное меню и, если оно не влезло, сдвинуть его влево. */
  private remeasure(): void {
    // Через кадр, а не сразу: ширину задаёт разложенный текст, а он к этому
    // моменту ещё не разложен.
    requestAnimationFrame(() => {
      const menu = this.el.nativeElement.querySelector<HTMLElement>('.menu');
      if (menu) this.measured.set(Math.ceil(menu.getBoundingClientRect().width));
    });
  }

  handleKey(event: KeyboardEvent): void {
    const options = this.options();
    if (!options.length) return;
    switch (event.key) {
      case 'Escape':
        event.preventDefault();
        this.dismissed.emit();
        return;
      case 'Enter':
      case ' ':
        event.preventDefault();
        this.picked.emit(this.active());
        return;
      case 'ArrowDown':
      case 'ArrowUp': {
        event.preventDefault();
        this.step(event.key === 'ArrowDown' ? 1 : -1);
        return;
      }
      case 'Home':
      case 'End': {
        event.preventDefault();
        this.active.set(event.key === 'Home' ? 0 : options.length - 1);
        this.scrollToActive();
        return;
      }
      default:
        return;
    }
  }

  /**
   * Клик мимо меню закрывает его. Поле-хозяин из «мимо» исключено намеренно:
   * тот же самый `mousedown`, которым меню открыли, продолжает всплывать до
   * документа уже ПОСЛЕ того, как меню появилось, и без этой проверки закрывал
   * бы его в тот же миг - меню не успевало показаться вовсе.
   */
  outside(event: MouseEvent): void {
    const target = event.target as Node;
    if (this.el.nativeElement.contains(target)) return;
    if (this.anchorEl()?.contains(target)) return;
    this.dismissed.emit();
  }

  /** Шаг по списку через недоступные строки: вставать на них незачем. */
  private step(delta: number): void {
    const options = this.options();
    let next = this.active();
    for (let i = 0; i < options.length; i += 1) {
      next = (next + delta + options.length) % options.length;
      if (!options[next].disabled) break;
    }
    this.active.set(next);
    this.scrollToActive();
  }

  private scrollToActive(): void {
    const rows = this.el.nativeElement.querySelectorAll<HTMLElement>('.row');
    rows[this.active()]?.scrollIntoView({ block: 'nearest' });
  }
}
