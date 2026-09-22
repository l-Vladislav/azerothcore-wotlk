import {
  ApplicationRef,
  ComponentRef,
  Directive,
  ElementRef,
  EnvironmentInjector,
  HostListener,
  OnDestroy,
  createComponent,
  inject,
} from '@angular/core';
import { ForgeSelectMenuComponent, ForgeSelectOption } from './forge-select-menu.component';

/**
 * Свой раскрывающийся список вместо браузерного.
 *
 * Зачем. Окно раскрытого `<select>` рисует САМ БРАУЗЕР, поверх страницы и
 * мимо документа: наши рамки, камень и шрифт туда не попадают, и посреди
 * кованой панели раскрывалось белое окно с серыми строчками. Задать ему можно
 * только цвет фона и текста - на панельный вид это не тянет.
 *
 * Как. Сам `<select>` остаётся в разметке и остаётся источником правды: все
 * привязки (`ngModel`, реактивные формы, свои `(change)`) продолжают работать
 * как работали, и на месте вызова меняется только оформление. Директива лишь
 * перехватывает попытку раскрыть родное окно и показывает своё меню, а выбор
 * возвращает обратно в `<select>` и шлёт `change` - так его слышат и Angular,
 * и страница.
 *
 * Меню живёт в `<body>`, а не рядом с полем. Иначе его прячет `overflow`
 * прокручиваемых панелей, а `position: fixed` внутри `.content` считается не
 * от экрана: у него `container-type`, а тот делает блок точкой отсчёта для
 * fixed-потомков.
 */
@Directive({
  selector: 'select.forge-field',
  host: { '[class.is-open]': 'ref !== null' },
})
export class ForgeSelectDirective implements OnDestroy {
  private readonly el = inject<ElementRef<HTMLSelectElement>>(ElementRef);
  private readonly injector = inject(EnvironmentInjector);
  private readonly app = inject(ApplicationRef);
  protected ref: ComponentRef<ForgeSelectMenuComponent> | null = null;

  @HostListener('mousedown', ['$event'])
  onMouseDown(event: MouseEvent): void {
    if (this.el.nativeElement.disabled) return;
    // Без этого браузер успеет раскрыть родное окно поверх нашего.
    event.preventDefault();
    this.el.nativeElement.focus();
    if (this.ref) this.close();
    else this.open();
  }

  @HostListener('keydown', ['$event'])
  onKeyDown(event: KeyboardEvent): void {
    if (this.el.nativeElement.disabled) return;
    if (this.ref) {
      this.ref.instance.handleKey(event);
      return;
    }
    // Те же клавиши, которыми раскрывается родной список.
    if (['Enter', ' ', 'ArrowDown', 'ArrowUp'].includes(event.key)) {
      event.preventDefault();
      this.open();
    }
  }

  @HostListener('blur')
  onBlur(): void {
    this.close();
  }

  ngOnDestroy(): void {
    this.close();
  }

  private open(): void {
    const select = this.el.nativeElement;
    const options: ForgeSelectOption[] = Array.from(select.options).map((option, index) => ({
      index,
      label: option.label || option.text,
      disabled: option.disabled,
    }));
    if (!options.length) return;

    // Меню кладём В ТО ЖЕ ОКНО, если список стоит в модальном `<dialog>`.
    // Модальное окно живёт в верхнем слое браузера, и всё, что осталось в
    // `<body>`, рисуется ПОД ним: меню открывалось, но было не видно и не
    // нажималось - со стороны выглядело как «дропдаун не открывается».
    const host = document.createElement('div');
    (select.closest('dialog[open]') ?? document.body).appendChild(host);
    this.ref = createComponent(ForgeSelectMenuComponent, {
      environmentInjector: this.injector,
      hostElement: host,
    });
    const menu = this.ref.instance;
    menu.options.set(options);
    menu.current.set(select.selectedIndex);
    menu.anchor.set(select.getBoundingClientRect());
    menu.anchorEl.set(select);
    menu.picked.subscribe((index: number) => {
      this.close();
      this.apply(index);
    });
    menu.dismissed.subscribe(() => this.close());
    this.app.attachView(this.ref.hostView);
  }

  private close(): void {
    if (!this.ref) return;
    const host = this.ref.location.nativeElement as HTMLElement;
    this.app.detachView(this.ref.hostView);
    this.ref.destroy();
    host.remove();
    this.ref = null;
  }

  /**
   * Выбор возвращается в сам `<select>`. `change` обязателен: именно его
   * слушает Angular (и `ngModel`, и реактивные формы), а `input` добавлен для
   * страниц, которые подписаны на него.
   */
  private apply(index: number): void {
    const select = this.el.nativeElement;
    if (index === select.selectedIndex) return;
    select.selectedIndex = index;
    select.dispatchEvent(new Event('input', { bubbles: true }));
    select.dispatchEvent(new Event('change', { bubbles: true }));
  }
}
