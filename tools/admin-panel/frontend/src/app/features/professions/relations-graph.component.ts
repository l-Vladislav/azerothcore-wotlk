import {
  AfterViewChecked,
  AfterViewInit,
  Component,
  ElementRef,
  OnDestroy,
  computed,
  effect,
  inject,
  input,
  signal,
  viewChild,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { ApiService } from '../../core/api.service';
import {
  ItemType,
  Material,
  ProfessionsMeta,
  Recipe,
  Synergy,
} from './professions.api';
import { iconUrl, qualityName } from './professions.model';

// Геометрия раскладки. Колонки стоят слева направо: тип -> основа -> эскизы.
const COL = { type: 24, base: 330, syn: 730 };
const NODE_W = { type: 250, base: 360, syn: 420 };
const ROW = 20; // шаг строки эскиза
const GAP = 12; // зазор между основами
const CANVAS_H = 620; // высота полотна на странице
const LABEL_AT = 0.42; // с какого масштаба подписи читаемы
const OPEN_W = 520; // ширина раскрытой коробки
const LINE = 16; // высота строки внутри неё

interface GraphLine {
  text: string;
  icon?: string;
  quality?: number;
  head?: boolean;
  dim?: boolean;
  warn?: boolean;
  pad?: boolean;
  link?: string;
  hit?: { x: number; y: number; w: number };
}

interface GraphNode {
  kind: 'type' | 'base' | 'syn';
  id: number;
  route?: string;
  x: number;
  y: number;
  w: number;
  h: number;
  label: string;
  note: string;
  color?: string;
  warn?: boolean;
  off?: boolean;
  lines?: GraphLine[] | null;
}

interface GraphEdge {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}

interface Layout {
  nodes: GraphNode[];
  edges: GraphEdge[];
  width: number;
  height: number;
}

interface Palette {
  line: string;
  text: string;
  muted: string;
  gold: string;
  goldDim: string;
  panel: string;
  panelHi: string;
  quality: string[];
}

/**
 * Диаграмма связей: вся сетка разом, без выбора типа.
 *
 * Рисуется на CANVAS, а не в разметке: узлов под четыре тысячи, и страница
 * «Именные» уже показывала, чем кончается такая россыпь в DOM - четырнадцать
 * секунд на открытие.
 *
 * «Вместить» - по ШИРИНЕ, а не целиком: раскладка высотой под шестьдесят тысяч
 * точек, и попытка уместить её в полотно даёт масштаб в один процент, где узел
 * тоньше волоса. Вся картина разом - это отдельная кнопка «Целиком», и подписи
 * на таком масштабе не рисуются честно.
 */
@Component({
  selector: 'app-relations-graph',
  imports: [FormsModule],
  styleUrl: './relations-graph.component.scss',
  template: `
    <div class="bar">
      @for (mode of shows; track mode[0]) {
        <button
          type="button"
          class="chip"
          [class.is-on]="show() === mode[0]"
          (click)="setShow(mode[0])"
        >
          {{ mode[1] }}
        </button>
      }
      <button type="button" class="chip" [class.is-on]="bad()" (click)="toggleBad()">
        только с замечаниями
      </button>
      <span class="muted">узлов {{ layout().nodes.length }} · связей {{ layout().edges.length }}</span>
      <span class="tools">
        <button type="button" class="forge-btn is-ghost is-compact" (click)="zoomBy(1 / 1.25)">
          −
        </button>
        <button type="button" class="forge-btn is-ghost is-compact" (click)="zoomBy(1.25)">+</button>
        <button type="button" class="forge-btn is-ghost is-compact" (click)="doFit()">
          Вместить
        </button>
        <button type="button" class="forge-btn is-ghost is-compact" (click)="doWhole()">
          Целиком
        </button>
        <span class="muted">{{ percent() }}</span>
      </span>
    </div>

    <div class="filters">
      <span class="muted">Типы:</span>
      <button type="button" class="chip" [class.is-on]="!types().length" (click)="clearPick('types')">
        все
      </button>
      @for (type of allTypes(); track type.id) {
        <button
          type="button"
          class="chip"
          [class.is-on]="types().includes(type.id)"
          (click)="togglePick('types', type.id)"
        >
          {{ type.name_ru }}
        </button>
      }
    </div>

    <div class="filters">
      <span class="muted">Качество:</span>
      <button type="button" class="chip" [class.is-on]="!quals().length" (click)="clearPick('quals')">
        все
      </button>
      @for (tier of tiers(); track tier.quality) {
        <button
          type="button"
          class="chip"
          [class.is-on]="quals().includes(tier.quality)"
          (click)="togglePick('quals', tier.quality)"
        >
          {{ tier.name_ru }}
        </button>
      }
    </div>

    @if (bands().length) {
      <div class="filters">
        <span class="muted">Полоса:</span>
        <button
          type="button"
          class="chip"
          [class.is-on]="!skills().length"
          (click)="clearPick('bands')"
        >
          все
        </button>
        @for (band of bands(); track band.idx) {
          <button
            type="button"
            class="chip"
            [class.is-on]="skills().includes(band.skill)"
            (click)="togglePick('bands', band.skill)"
          >
            {{ band.name_ru }}
          </button>
        }
      </div>
    }

    <div class="filters">
      <span class="muted">Поиск:</span>
      <input
        class="forge-field is-search find"
        type="search"
        placeholder="имя эскиза, основы или типа"
        [ngModel]="find()"
        (ngModelChange)="onFind($event)"
      />
      <button type="button" class="forge-btn is-ghost is-compact" (click)="resetAll()">
        Сбросить всё
      </button>
    </div>

    <div class="wrap">
      <canvas #canvas class="canvas" [class.is-dragging]="dragging()"></canvas>
      @if (tip(); as hint) {
        <div class="tip" [style.left.px]="hint.x" [style.top.px]="hint.y">{{ hint.text }}</div>
      }
    </div>
  `,
})
export class RelationsGraphComponent implements AfterViewInit, AfterViewChecked, OnDestroy {
  private readonly api = inject(ApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly canvas = viewChild.required<ElementRef<HTMLCanvasElement>>('canvas');

  readonly meta = input<ProfessionsMeta | null>(null);
  readonly allTypes = input<readonly ItemType[]>([]);
  readonly recipes = input<readonly Recipe[]>([]);
  readonly synergies = input<readonly Synergy[]>([]);
  readonly materials = input<readonly Material[]>([]);

  readonly shows: readonly (readonly [string, string])[] = [
    ['all', 'Всё'],
    ['forge', 'Ковка'],
    ['drop', 'Добыча'],
  ];

  readonly show = signal('all');
  readonly bad = signal(false);
  readonly types = signal<number[]>([]);
  readonly quals = signal<number[]>([]);
  readonly skills = signal<number[]>([]);
  readonly find = signal('');
  readonly open = signal<{ kind: GraphNode['kind']; id: number } | null>(null);
  readonly openLines = signal<GraphLine[]>([]);
  readonly dragging = signal(false);
  readonly tip = signal<{ x: number; y: number; text: string } | null>(null);
  readonly scale = signal(0);

  private offset = { x: 0, y: 0 };
  private hover: GraphNode | null = null;
  private drag: { x: number; y: number; ox: number; oy: number; moved: number } | null = null;
  private palette: Palette | null = null;
  private readonly itemCache = new Map<number, ItemRow | null>();
  private readonly dropCache = new Map<number, DropReply>();
  private readonly icons = new Map<string, HTMLImageElement>();
  private statNames: { value: number; label: string }[] | null = null;
  private findTimer: ReturnType<typeof setTimeout> | null = null;

  readonly tiers = computed(() =>
    (this.meta()?.qualities ?? []).filter((tier) => tier.quality >= 1 && tier.quality <= 5),
  );

  /**
   * Полосы лестницы. Ключ чипа - НАВЫК полосы, а не её номер: именно им рецепт
   * с ней и связан, своего поля у рецепта нет.
   */
  readonly bands = computed(
    () => (this.meta()?.bands as { idx: number; skill: number; name_ru: string }[] | undefined) ?? [],
  );

  readonly percent = computed(() => `${Math.round(this.scale() * 100)}%`);

  readonly layout = computed<Layout>(() => this.build());

  constructor() {
    this.readUrl();
    // Раскладка меняется - перерисовываем. Отбор, раскрытие и приход данных
    // приходят сюда одним путём, а не тремя вызовами `draw()` вразнобой.
    effect(() => {
      this.layout();
      this.scale();
      queueMicrotask(() => this.draw());
    });
  }

  ngAfterViewInit(): void {
    // До вставки в страницу у полотна нет ширины, и «Вместить» посчитало бы
    // по нулю.
    requestAnimationFrame(() => {
      if (!this.scale()) this.doFit();
      else this.draw();
    });
  }

  ngOnDestroy(): void {
    if (this.findTimer) clearTimeout(this.findTimer);
    // Слушатель висит на окне, а не на полотне: отпустить кнопку можно и за
    // пределами холста, и без снятия он пережил бы саму страницу.
    window.removeEventListener('mouseup', this.onUp);
  }

  // --- отбор ---------------------------------------------------------------

  setShow(value: string): void {
    this.show.set(value);
    this.refit();
  }

  toggleBad(): void {
    this.bad.update((on) => !on);
    this.refit();
  }

  togglePick(key: 'types' | 'quals' | 'bands', id: number): void {
    const target = key === 'types' ? this.types : key === 'quals' ? this.quals : this.skills;
    target.update((list) => (list.includes(id) ? list.filter((x) => x !== id) : [...list, id]));
    this.refit();
  }

  clearPick(key: 'types' | 'quals' | 'bands'): void {
    const target = key === 'types' ? this.types : key === 'quals' ? this.quals : this.skills;
    target.set([]);
    this.refit();
  }

  /** Поиск НЕ подгоняет вид: подгонка на каждой букве дёргала бы масштаб. */
  onFind(value: string): void {
    this.find.set(value);
    if (this.findTimer) clearTimeout(this.findTimer);
    this.findTimer = setTimeout(() => this.writeUrl(), 300);
  }

  resetAll(): void {
    this.show.set('all');
    this.types.set([]);
    this.quals.set([]);
    this.skills.set([]);
    this.find.set('');
    this.bad.set(false);
    this.refit();
  }

  /** Другой отбор - другая высота: вид подгоняем заново. */
  private refit(): void {
    this.writeUrl();
    this.scale.set(0);
    queueMicrotask(() => this.doFit());
  }

  private readUrl(): void {
    const params = this.route.snapshot.queryParamMap;
    const nums = (key: string) =>
      (params.get(key) ?? '')
        .split(',')
        .map(Number)
        .filter((n) => !Number.isNaN(n) && n !== 0);
    if (params.get('s')) this.show.set(params.get('s')!);
    if (params.get('t')) this.types.set(nums('t'));
    if (params.get('q')) this.quals.set(nums('q'));
    if (params.get('b')) this.skills.set(nums('b'));
    if (params.get('f')) this.find.set(params.get('f')!);
    if (params.get('w')) this.bad.set(true);
  }

  /**
   * Отбор из шести рядов чипов и строки поиска руками не пересобрать, а
   * показать коллеге «вот эти сорок узлов» хочется ссылкой. `replaceUrl`, а не
   * шаг истории: «назад» после десяти щелчков по чипам должен уводить со
   * страницы, а не отматывать их.
   */
  private writeUrl(): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      replaceUrl: true,
      queryParamsHandling: 'merge',
      queryParams: {
        s: this.show() === 'all' ? null : this.show(),
        t: this.types().length ? this.types().join(',') : null,
        q: this.quals().length ? this.quals().join(',') : null,
        b: this.skills().length ? this.skills().join(',') : null,
        f: this.find() || null,
        w: this.bad() ? '1' : null,
      },
    });
  }

  // --- раскладка -----------------------------------------------------------

  private build(): Layout {
    const show = this.show();
    const types = this.types();
    const quals = this.quals();
    const bands = this.skills();
    const needle = this.find().trim().toLocaleLowerCase();
    const bad = this.bad();
    const hit = (text: string | undefined) =>
      !needle || String(text ?? '').toLocaleLowerCase().includes(needle);

    const open = this.open();
    const lines = this.openLines();
    const openH = 4 + ROW + lines.length * LINE + 6;
    const isOpen = (kind: GraphNode['kind'], id: number) =>
      !!open && open.kind === kind && open.id === id;
    const boxOf = (kind: GraphNode['kind'], id: number) =>
      isOpen(kind, id) ? { h: openH, w: OPEN_W } : { h: ROW - 4, w: 0 };

    const nodes: GraphNode[] = [];
    const edges: GraphEdge[] = [];
    let y = 20;

    for (const type of this.allTypes()) {
      if (types.length && !types.includes(type.id)) continue;
      const recs = this.recipes()
        .filter(
          (recipe) =>
            recipe.type_id === type.id && (show === 'all' || (recipe.acquire || 'forge') === show),
        )
        .sort(
          (a, b) =>
            (a.acquire === b.acquire ? 0 : a.acquire === 'forge' ? -1 : 1) ||
            a.req_skill - b.req_skill ||
            a.id - b.id,
        );
      if (!recs.length) continue;

      const typeTop = y;
      const baseYs: number[] = [];
      const before = nodes.length;

      for (const rec of recs) {
        // Полоса отсекает основу целиком - вместе со всеми её эскизами: эскиз
        // живёт на своей основе и в чужой полосе смысла не имеет.
        if (bands.length && !bands.includes(Number(rec.req_skill))) continue;

        const syns = this.synergies().filter(
          (syn) =>
            syn.recipe_id === rec.id &&
            (!quals.length || quals.includes(Number(syn.result?.quality))) &&
            (!bad || syn.issues.length) &&
            // Совпало имя основы - показываем все её эскизы: искали основу, а
            // не строку в ней.
            (hit(syn.name_ru) || hit(rec.name_ru) || hit(type.name_ru)),
        );

        const baseFits =
          (!quals.length || rec.results.some((row) => quals.includes(Number(row.quality)))) &&
          (!bad || rec.issues.length) &&
          (hit(rec.name_ru) || hit(type.name_ru));
        if (!baseFits && !syns.length) continue;

        const rowTop = y;
        for (const syn of syns) {
          const item = syn.result;
          const box = boxOf('syn', syn.id);
          nodes.push({
            kind: 'syn',
            id: syn.id,
            route: '/professions/named',
            x: COL.syn,
            y,
            w: box.w || NODE_W.syn,
            h: box.h,
            label: syn.name_ru || `эскиз ${syn.id}`,
            note: `${syn.mats.length} камн.${syn.issues.length ? ' · замечание' : ''}`,
            color: this.qualityColor(item ? item.quality : 0),
            warn: syn.issues.length > 0 || !syn.result_entry,
            lines: isOpen('syn', syn.id) ? lines : null,
          });
          y += Math.max(ROW, box.h + 4);
        }
        // Основа без единого эскиза - законное состояние («сковать можно, а
        // дальше дороги нет»), и на диаграмме она обязана быть видна.
        if (!syns.length) y += ROW;

        const baseBox = boxOf('base', rec.id);
        const baseY = (rowTop + y - ROW) / 2;
        baseYs.push(baseY);
        // Раскрытая основа может оказаться выше своей стопки эскизов - тогда
        // место под неё добирается снизу, чтобы следующая не наехала.
        const overflow = baseY + baseBox.h - y;
        if (overflow > 0) y += overflow;

        nodes.push({
          kind: 'base',
          id: rec.id,
          route: '/professions/recipes',
          x: COL.base,
          y: baseY,
          w: baseBox.w || NODE_W.base,
          h: baseBox.h,
          label: rec.name_ru,
          note: `${rec.acquire === 'drop' ? 'добыча' : `навык ${rec.req_skill}`} · ст. ${rec.results.length} · эск. ${syns.length}`,
          warn: rec.issues.length > 0,
          off: !rec.enabled,
          lines: isOpen('base', rec.id) ? lines : null,
        });

        syns.forEach((_, index) =>
          edges.push({
            x1: COL.base + NODE_W.base,
            y1: baseY + ROW / 2,
            x2: COL.syn,
            y2: rowTop + index * ROW + ROW / 2,
          }),
        );
        y += GAP;
      }

      if (nodes.length === before) {
        // Место, занятое под пустой тип, возвращаем: столбец-одиночка без
        // единой основы читается как «тип есть, но пуст».
        y = typeTop;
        continue;
      }

      const typeBox = boxOf('type', type.id);
      const typeY = (typeTop + y - GAP - ROW) / 2;
      if (typeY + typeBox.h - y > 0) y += typeY + typeBox.h - y;
      nodes.push({
        kind: 'type',
        id: type.id,
        x: COL.type,
        y: typeY,
        w: typeBox.w || NODE_W.type,
        h: typeBox.h,
        label: type.name_ru,
        note: `основ ${recs.length}`,
        lines: isOpen('type', type.id) ? lines : null,
      });
      baseYs.forEach((baseY) =>
        edges.push({
          x1: COL.type + NODE_W.type,
          y1: typeY + ROW / 2,
          x2: COL.base,
          y2: baseY + ROW / 2,
        }),
      );
      y += GAP * 2;
    }

    return { nodes, edges, width: COL.syn + NODE_W.syn + 40, height: Math.max(y + 20, 200) };
  }

  // --- палитра и отрисовка --------------------------------------------------

  /** Цвета берём из темы панели: canvas - такой же элемент страницы. */
  private pal(): Palette {
    if (this.palette) return this.palette;
    const css = getComputedStyle(document.documentElement);
    const pick = (name: string, fallback: string) =>
      (css.getPropertyValue(name) || '').trim() || fallback;
    this.palette = {
      line: pick('--line', '#33302a'),
      text: pick('--text', '#e6e0d4'),
      muted: pick('--muted', '#969184'),
      gold: pick('--gold', '#c8aa6e'),
      goldDim: pick('--gold-dim', '#8b7440'),
      panel: pick('--panel-2', '#1f232c'),
      panelHi: pick('--panel-3', '#262b35'),
      quality: [
        pick('--q-poor', '#9d9d9d'),
        pick('--text', '#e6e0d4'),
        pick('--q-uncommon', '#4ade5a'),
        pick('--q-rare', '#4aa3ff'),
        pick('--q-epic', '#c77dff'),
        pick('--q-legendary', '#ff9a3c'),
      ],
    };
    return this.palette;
  }

  private qualityColor(quality: number): string {
    return this.pal().quality[Math.max(0, Math.min(5, Number(quality) || 0))];
  }

  private nodeAt(x: number, y: number): GraphNode | null {
    const nodes = this.layout().nodes;
    // Узлов тысячи, но проход по плоскому списку на движение мыши дешевле,
    // чем поиск по разметке, - а разметки тут и нет.
    for (let i = nodes.length - 1; i >= 0; i -= 1) {
      const node = nodes[i];
      const h = node.h || ROW - 4;
      if (x >= node.x && x <= node.x + node.w && y >= node.y && y <= node.y + h) return node;
    }
    return null;
  }

  private clip(ctx: CanvasRenderingContext2D, text: string, width: number): string {
    const value = String(text ?? '');
    if (ctx.measureText(value).width <= width) return value;
    let lo = 0;
    let hi = value.length;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (ctx.measureText(`${value.slice(0, mid)}…`).width <= width) lo = mid;
      else hi = mid - 1;
    }
    return `${value.slice(0, lo)}…`;
  }

  private icon(texture: string | undefined): HTMLImageElement | null {
    if (!texture) return null;
    const url = iconUrl(texture, this.meta()?.icon_base_url);
    if (!this.icons.has(url)) {
      const img = new Image();
      img.onload = () => this.draw();
      img.src = url;
      this.icons.set(url, img);
    }
    const img = this.icons.get(url);
    return img && img.complete && img.naturalWidth ? img : null;
  }

  private draw(): void {
    const cv = this.canvas()?.nativeElement;
    const ctx = cv?.getContext('2d');
    if (!cv || !ctx) return;

    const pal = this.pal();
    const ratio = window.devicePixelRatio || 1;
    const cw = cv.clientWidth || 900;
    const ch = cv.clientHeight || CANVAS_H;
    if (cv.width !== Math.round(cw * ratio)) cv.width = Math.round(cw * ratio);
    if (cv.height !== Math.round(ch * ratio)) cv.height = Math.round(ch * ratio);

    const graph = this.layout();
    const scale = this.scale() || 1;

    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    ctx.clearRect(0, 0, cw, ch);
    ctx.save();
    ctx.translate(this.offset.x, this.offset.y);
    ctx.scale(scale, scale);

    // Видимое окно в координатах раскладки: что за ним - не рисуем вовсе.
    const vy1 = -this.offset.y / scale;
    const vy2 = vy1 + ch / scale;

    ctx.lineWidth = 1 / scale;
    ctx.strokeStyle = pal.line;
    ctx.beginPath();
    for (const edge of graph.edges) {
      if (Math.max(edge.y1, edge.y2) < vy1 || Math.min(edge.y1, edge.y2) > vy2) continue;
      const mid = (edge.x1 + edge.x2) / 2;
      ctx.moveTo(edge.x1, edge.y1);
      ctx.bezierCurveTo(mid, edge.y1, mid, edge.y2, edge.x2, edge.y2);
    }
    ctx.stroke();

    const labels = scale >= LABEL_AT;
    ctx.font = '12px "Segoe UI", system-ui, sans-serif';
    ctx.textBaseline = 'middle';

    for (const node of graph.nodes) {
      const h = node.h || ROW - 4;
      if (node.y + h < vy1 || node.y > vy2) continue;
      const hot = this.hover === node;
      const open = !!node.lines;

      ctx.globalAlpha = node.off ? 0.45 : 1;
      ctx.fillStyle = hot || open ? pal.panelHi : pal.panel;
      ctx.strokeStyle = open
        ? pal.gold
        : node.kind === 'type'
          ? pal.gold
          : node.kind === 'base'
            ? node.warn
              ? pal.quality[5]
              : pal.goldDim
            : (node.color ?? pal.muted);
      ctx.lineWidth = (open ? 2 : 1) / scale;
      ctx.beginPath();
      ctx.rect(node.x, node.y, node.w, h);
      ctx.fill();
      ctx.stroke();
      ctx.lineWidth = 1 / scale;

      // Раскрытая коробка показывает содержимое даже на мелком масштабе: её
      // ради содержимого и раскрывали.
      if (labels || open) {
        const cy = node.y + (ROW - 4) / 2;
        ctx.fillStyle =
          node.kind === 'type' ? pal.gold : node.kind === 'syn' ? (node.color ?? pal.text) : pal.text;
        ctx.fillText(this.clip(ctx, node.label, node.w - (open ? 28 : 110)), node.x + 8, cy);
        if (!open) {
          ctx.fillStyle = pal.muted;
          ctx.fillText(this.clip(ctx, node.note, 100), node.x + node.w - 102, cy);
        }
      }

      if (open && node.lines) {
        // Крестик в углу: щелчок по нему закрывает - это ближе, чем искать тот
        // же узел под курсором второй раз.
        ctx.fillStyle = pal.muted;
        ctx.fillText('×', node.x + node.w - 16, node.y + (ROW - 4) / 2);

        let ly = node.y + ROW + LINE / 2;
        for (const line of node.lines) {
          let lx = node.x + 10;
          if (line.icon) {
            const img = this.icon(line.icon);
            if (img) ctx.drawImage(img, lx, ly - 6, 13, 13);
            lx += 17;
          }
          ctx.fillStyle = line.link
            ? pal.gold
            : line.warn
              ? pal.quality[5]
              : line.head
                ? pal.gold
                : line.dim
                  ? pal.muted
                  : line.quality
                    ? pal.quality[Math.min(5, line.quality)]
                    : pal.text;
          const text = this.clip(ctx, line.text, node.w - (lx - node.x) - 12);
          const tx = lx + (line.pad ? 10 : 0);
          ctx.fillText(text, tx, ly);
          // Строка-ссылка подчёркивается и запоминает, куда её нажали: полотно
          // не разметка, попадание по строке считать больше негде.
          if (line.link) {
            const w = ctx.measureText(text).width;
            ctx.fillRect(tx, ly + 7, w, 1);
            line.hit = { x: tx, y: ly, w };
          }
          ly += LINE;
        }
      }
      ctx.globalAlpha = 1;
    }

    ctx.restore();
  }

  // --- вид ------------------------------------------------------------------

  doFit(): void {
    const cv = this.canvas()?.nativeElement;
    const cw = cv?.clientWidth || 900;
    const graph = this.layout();
    const scale = Math.min(cw / graph.width, 1) || 0.05;
    this.offset = { x: (cw - graph.width * scale) / 2, y: 8 };
    this.scale.set(scale);
  }

  /** Вся картина разом: видно форму сетки - где густо, а где пусто. */
  doWhole(): void {
    const cv = this.canvas()?.nativeElement;
    const cw = cv?.clientWidth || 900;
    const graph = this.layout();
    const scale = Math.max(0.02, Math.min(cw / graph.width, CANVAS_H / graph.height));
    this.offset = {
      x: (cw - graph.width * scale) / 2,
      y: (CANVAS_H - graph.height * scale) / 2,
    };
    this.scale.set(scale);
  }

  zoomBy(factor: number): void {
    const cv = this.canvas()?.nativeElement;
    this.zoomAt((cv?.clientWidth || 900) / 2, CANVAS_H / 2, factor);
  }

  private zoomAt(px: number, py: number, factor: number): void {
    const current = this.scale() || 1;
    const next = Math.max(0.02, Math.min(4, current * factor));
    const k = next / current;
    this.offset = { x: px - (px - this.offset.x) * k, y: py - (py - this.offset.y) * k };
    this.scale.set(next);
  }

  // --- мышь -----------------------------------------------------------------

  ngAfterViewChecked(): void {
    // Слушатели вешаются один раз; отдельного места под это в шаблоне нет,
    // потому что canvas у компонента ровно один.
    const cv = this.canvas()?.nativeElement;
    if (!cv || cv.dataset['bound']) return;
    cv.dataset['bound'] = '1';
    cv.addEventListener('wheel', (event) => this.onWheel(event), { passive: false });
    cv.addEventListener('mousedown', (event) => this.onDown(event));
    cv.addEventListener('mousemove', (event) => this.onMove(event));
    cv.addEventListener('mouseleave', () => this.onLeave());
    cv.addEventListener('dblclick', (event) => this.onDoubleClick(event));
    window.addEventListener('mouseup', this.onUp);
  }

  private readonly onUp = (event: MouseEvent): void => {
    const cv = this.canvas()?.nativeElement;
    if (!cv) return;
    // Щелчок и протаскивание начинаются одинаково, поэтому различаем их по
    // пройденному пути: сдвинул полотно - значит не выбирал узел.
    if (this.drag && this.drag.moved < 4) {
      const { x, y } = this.toLayout(event, cv);
      const node = this.nodeAt(x, y);
      const line = node?.lines?.find(
        (row) =>
          row.hit &&
          x >= row.hit.x &&
          x <= row.hit.x + row.hit.w &&
          y >= row.hit.y - 7 &&
          y <= row.hit.y + 8,
      );
      // Ссылка внутри раскрытой коробки старше и крестика, и самого узла: по
      // ней щёлкают нарочно, а закрыть узел можно чем угодно ещё.
      if (line?.link) {
        window.open(line.link, '_blank');
      } else if (node?.lines && x > node.x + node.w - 24 && y < node.y + ROW) {
        this.openNode(null);
      } else if (node) {
        this.openNode(node);
      }
    }
    this.drag = null;
    this.dragging.set(false);
  };

  private toLayout(event: MouseEvent, cv: HTMLCanvasElement): { x: number; y: number } {
    const rect = cv.getBoundingClientRect();
    const scale = this.scale() || 1;
    return {
      x: (event.clientX - rect.left - this.offset.x) / scale,
      y: (event.clientY - rect.top - this.offset.y) / scale,
    };
  }

  private onWheel(event: WheelEvent): void {
    event.preventDefault();
    const cv = this.canvas()!.nativeElement;
    const rect = cv.getBoundingClientRect();
    this.zoomAt(
      event.clientX - rect.left,
      event.clientY - rect.top,
      event.deltaY < 0 ? 1.15 : 1 / 1.15,
    );
  }

  private onDown(event: MouseEvent): void {
    this.drag = {
      x: event.clientX,
      y: event.clientY,
      ox: this.offset.x,
      oy: this.offset.y,
      moved: 0,
    };
    this.dragging.set(true);
  }

  private onMove(event: MouseEvent): void {
    const cv = this.canvas()!.nativeElement;
    const rect = cv.getBoundingClientRect();
    if (this.drag) {
      this.drag.moved = Math.max(
        this.drag.moved,
        Math.abs(event.clientX - this.drag.x) + Math.abs(event.clientY - this.drag.y),
      );
      this.offset = {
        x: this.drag.ox + (event.clientX - this.drag.x),
        y: this.drag.oy + (event.clientY - this.drag.y),
      };
      this.draw();
      return;
    }
    const { x, y } = this.toLayout(event, cv);
    const node = this.nodeAt(x, y);
    if (node !== this.hover) {
      this.hover = node;
      this.draw();
    }
    this.tip.set(
      node
        ? {
            x: Math.min(event.clientX - rect.left + 14, rect.width - 260),
            y: event.clientY - rect.top + 14,
            text: `${node.label} — ${node.note}`,
          }
        : null,
    );
  }

  private onLeave(): void {
    this.tip.set(null);
    this.hover = null;
    this.draw();
  }

  private onDoubleClick(event: MouseEvent): void {
    const cv = this.canvas()!.nativeElement;
    const { x, y } = this.toLayout(event, cv);
    const node = this.nodeAt(x, y);
    // Карта обязана приводить к строке, а не просто открывать раздел.
    if (node?.route) {
      void this.router.navigate([node.route], { queryParams: { focus: node.id } });
    }
  }

  // --- раскрытый узел -------------------------------------------------------

  private openNode(node: GraphNode | null): void {
    if (!node) {
      this.open.set(null);
      this.openLines.set([]);
      return;
    }
    const open = this.open();
    // Тот же узел вторым щелчком - закрыть.
    if (open && open.kind === node.kind && open.id === node.id) {
      this.openNode(null);
      return;
    }
    const asked = { kind: node.kind, id: node.id };
    this.open.set(asked);
    this.openLines.set([{ text: 'читаю…', dim: true }]);
    void this.buildLines(asked).then((lines) => {
      // Пока ходили за предметом, могли раскрыть другой узел.
      const now = this.open();
      if (!now || now.kind !== asked.kind || now.id !== asked.id) return;
      this.openLines.set(lines);
    });
  }

  private async statLabel(type: number): Promise<string> {
    if (!this.statNames) {
      try {
        const meta = await firstValueFrom(
          this.api.get<{ enums?: { statType?: { value: number; label: string }[] } }>('/items/meta'),
        );
        this.statNames = meta.enums?.statType ?? [];
      } catch {
        this.statNames = [];
      }
    }
    return this.statNames.find((row) => Number(row.value) === Number(type))?.label ?? `стат ${type}`;
  }

  /** Полную строку предмета отдаёт общий каталог; ходим по требованию и в кэш. */
  private async itemRow(entry: number): Promise<ItemRow | null> {
    const id = Number(entry) || 0;
    if (!id) return null;
    if (!this.itemCache.has(id)) {
      try {
        this.itemCache.set(id, await firstValueFrom(this.api.get<ItemRow>(`/items/${id}`)));
      } catch {
        this.itemCache.set(id, null);
      }
    }
    return this.itemCache.get(id) ?? null;
  }

  private async drops(entry: number): Promise<DropReply> {
    if (this.dropCache.has(entry)) return this.dropCache.get(entry)!;
    let reply: DropReply;
    try {
      reply = await firstValueFrom(this.api.get<DropReply>(`/loot/item/${entry}`));
    } catch (error) {
      reply = { paths: [], error: String((error as { message?: string })?.message ?? 'нет ответа') };
    }
    this.dropCache.set(entry, reply);
    return reply;
  }

  /** Характеристики строки предмета: пустые поля молчат - «броня 0» у меча шум. */
  private async statLines(row: ItemRow | null): Promise<string[]> {
    if (!row?.fields) return [];
    const num = (name: string) => Number(row.fields?.[name] ?? 0);
    const out: string[] = [];

    const dmgMin = num('dmg_min1');
    const dmgMax = num('dmg_max1');
    const delay = num('delay');
    if (dmgMax > 0) {
      let line = `Урон ${Math.round(dmgMin)}-${Math.round(dmgMax)}`;
      if (delay > 0) {
        line += ` · скорость ${(delay / 1000).toFixed(1)} · ${(
          (dmgMin + dmgMax) /
          2 /
          (delay / 1000)
        ).toFixed(1)} ур/сек`;
      }
      out.push(line);
    }
    if (num('armor')) out.push(`Броня ${num('armor')}`);
    if (num('block')) out.push(`Блок ${num('block')}`);
    if (num('MaxDurability')) out.push(`Прочность ${num('MaxDurability')}`);
    if (num('RequiredLevel')) out.push(`Требует уровень ${num('RequiredLevel')}`);

    const stats: string[] = [];
    for (let i = 1; i <= 10; i += 1) {
      const type = num(`stat_type${i}`);
      const value = num(`stat_value${i}`);
      if (type && value) stats.push(`${await this.statLabel(type)} +${value}`);
    }
    if (stats.length) out.push(stats.join(', '));

    const sockets = [1, 2, 3].map((i) => num(`socketColor_${i}`)).filter(Boolean).length;
    if (sockets) out.push(`Ванильных гнёзд ${sockets}`);
    return out;
  }

  private matLine(entry: number, count: number, prefix = ''): GraphLine {
    const mat = this.materials().find((row) => row.entry === entry);
    const item = mat?.item;
    const name = mat?.name_ru || item?.name || `предмет ${entry}`;
    return {
      text: `${prefix}${name}${count > 1 ? ` x${count}` : ''}`,
      icon: item?.icon,
      quality: item?.quality ?? 0,
    };
  }

  /**
   * Где падает предмет - спрашиваем у страницы добычи её же запросом.
   * Показываем три самых щедрых пути и общий счёт: список из сорока источников
   * в коробке не читается, а вопрос обычно один - «часто ли и с кого».
   */
  private dropLines(drops: DropReply, entry: number): GraphLine[] {
    const lines: GraphLine[] = [];
    if (!drops || drops.error) {
      lines.push({ text: `Добыча: ${drops?.error ?? 'нет ответа'}`, dim: true });
      return lines;
    }
    const paths = drops.paths ?? [];
    if (!paths.length) {
      lines.push({ text: 'Нигде не падает', warn: true });
    } else {
      lines.push({
        text: `Падает: источников ${paths.length}${drops.truncated ? ' (список обрезан)' : ''}`,
        head: true,
      });
      paths.slice(0, 3).forEach((path) =>
        lines.push({
          text: `• ${path.owner_name || '?'} — ${
            path.chance >= 0.01 ? path.chance.toFixed(2) : path.chance
          } %`,
          pad: true,
        }),
      );
      if (paths.length > 3) {
        lines.push({ text: `…и ещё ${paths.length - 3}`, pad: true, dim: true });
      }
    }
    // Адрес строим маршрутизатором и раскрываем относительно <base href>:
    // на dev-сервере панель лежит в корне, а в образе - под /ui/.
    const path = this.router.serializeUrl(
      this.router.createUrlTree(['/loot/items'], { queryParams: { item: entry } }),
    );
    lines.push({
      text: 'Открыть в «Добыче» →',
      link: new URL(path.replace(/^\//, ''), document.baseURI).href,
    });
    return lines;
  }

  private async buildLines(open: { kind: GraphNode['kind']; id: number }): Promise<GraphLine[]> {
    const lines: GraphLine[] = [];
    const tier = (quality: number) => qualityName(this.meta(), quality);

    if (open.kind === 'type') {
      const type = this.allTypes().find((row) => row.id === open.id);
      if (!type) return [{ text: 'тип не найден' }];
      const recs = this.recipes().filter((row) => row.type_id === type.id);
      const syns = this.synergies().filter((syn) => recs.some((row) => row.id === syn.recipe_id));
      lines.push({
        text: `основ ${recs.length} · ковочных ${
          recs.filter((row) => row.acquire !== 'drop').length
        } · добычных ${recs.filter((row) => row.acquire === 'drop').length}`,
      });
      lines.push({ text: `эскизов ${syns.length}` });
      return lines;
    }

    if (open.kind === 'base') {
      const rec = this.recipes().find((row) => row.id === open.id);
      if (!rec) return [{ text: 'основа не найдена' }];
      const type = this.allTypes().find((row) => row.id === rec.type_id);
      lines.push({
        text: `${type ? type.name_ru : 'тип ?'} · ${
          rec.acquire === 'drop' ? 'только добыча' : `навык ${rec.req_skill}`
        } · качество ${tier(rec.quality_min)}-${tier(rec.quality_max)}${
          rec.enabled ? '' : ' · выключен'
        }`,
        dim: true,
      });

      if (rec.acquire === 'drop') {
        lines.push({ text: 'Куётся: нет, эту основу выбивают', dim: true });
      } else {
        lines.push({ text: 'Для ковки:', head: true });
        const cells = rec.cells.filter((cell) => cell.item_entry);
        if (!cells.length) lines.push({ text: 'ячейки пусты', dim: true });
        cells.forEach((cell) => lines.push(this.matLine(cell.item_entry, cell.count)));
      }

      lines.push({ text: 'Ступени:', head: true });
      for (const step of rec.results) {
        const slot = rec.inlay.find((row) => row.quality === step.quality);
        const row = await this.itemRow(step.result_entry);
        const item = step.item;
        lines.push({
          text: `${tier(step.quality)}${slot ? ` · гнёзд ${slot.slots}` : ''} · ${
            item?.name ?? `предмет ${step.result_entry}`
          }${item?.ilvl ? ` · ур. ${item.ilvl}` : ''}`,
          icon: item?.icon,
          quality: item?.quality ?? 0,
        });
        (await this.statLines(row)).forEach((text) => lines.push({ text, pad: true }));
      }

      // Откуда берётся сама основа. Для заготовки это главный вопрос вообще -
      // выковать её нельзя. Берём нижнюю ступень: имя у ступеней общее, а
      // падает именно она.
      const dropStep = rec.results[0];
      if (dropStep?.result_entry) {
        this.dropLines(await this.drops(dropStep.result_entry), dropStep.result_entry).forEach(
          (line) => lines.push(line),
        );
      }

      const syns = this.synergies().filter((syn) => syn.recipe_id === rec.id);
      lines.push({
        text: `Эскизов: ${syns.length}${
          syns.length
            ? ` — ${syns
                .slice(0, 4)
                .map((syn) => syn.name_ru)
                .join(', ')}${syns.length > 4 ? ` и ещё ${syns.length - 4}` : ''}`
            : ''
        }`,
        dim: true,
      });
      rec.issues.forEach((text) => lines.push({ text: `• ${text}`, warn: true }));
      return lines;
    }

    const syn = this.synergies().find((row) => row.id === open.id);
    if (!syn) return [{ text: 'эскиз не найден' }];
    const rec = this.recipes().find((row) => row.id === syn.recipe_id);
    lines.push({
      text: `из основы: ${rec ? rec.name_ru : 'основы нет'}${
        syn.order_matters ? ' · порядок значим' : ''
      }${syn.enabled ? '' : ' · выключен'}`,
      dim: true,
    });

    lines.push({ text: 'Для инкрустации:', head: true });
    syn.mats.forEach((entry, index) => lines.push(this.matLine(entry, 0, `${index + 1}. `)));

    const prize = syn.result;
    lines.push({
      text: `Выходит: ${prize?.name ?? `предмет ${syn.result_entry}`}${
        prize?.ilvl ? ` · ур. ${prize.ilvl}` : ''
      }`,
      icon: prize?.icon,
      quality: prize?.quality ?? 0,
      head: true,
    });
    const stats = await this.statLines(await this.itemRow(syn.result_entry));
    if (stats.length) stats.forEach((text) => lines.push({ text, pad: true }));
    else lines.push({ text: 'характеристик нет', pad: true, dim: true });

    const need = syn.mats.length;
    const fit = (rec?.inlay ?? []).filter((row) => row.slots >= need);
    lines.push({
      text: fit.length
        ? `собирается на ступенях: ${fit.map((row) => tier(row.quality)).join(', ')}`
        : 'ни одна ступень основы не даёт столько гнёзд',
      warn: !fit.length,
      dim: fit.length > 0,
    });

    if (syn.teach_item) {
      const book = await this.itemRow(syn.teach_item);
      lines.push({
        text: `Учит книга: ${book?.fields?.['name_ru'] ?? `предмет ${syn.teach_item}`}`,
        dim: true,
      });
    } else {
      lines.push({ text: 'Книги нет: эскиз только угадывается', dim: true });
    }
    syn.issues.forEach((text) => lines.push({ text: `• ${text}`, warn: true }));
    return lines;
  }
}

interface ItemRow {
  fields?: Record<string, string | number>;
}

interface DropReply {
  paths: { owner_name: string; chance: number }[];
  truncated?: boolean;
  error?: string;
}
