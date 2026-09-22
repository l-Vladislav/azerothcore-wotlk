import {
  Component,
  EventEmitter,
  Input,
  OnChanges,
  OnInit,
  Output,
  SimpleChanges,
  signal,
} from '@angular/core';
import { Cyclone, WeatherZone } from './weather.api';

type MapKey = 'ek' | 'kalimdor';

interface MapZone {
  id: number;
  name: string;
  path: string;
}
interface MapGeometry {
  map: number;
  width: number;
  height: number;
  rect: [number, number, number, number];
  zones: MapZone[];
}

interface MapFront {
  cyclone: Cyclone;
  x: number;
  y: number;
  radius: number;
  eye: number;
  color: string;
}

// Пути БЕЗ ведущей косой черты: адрес считается от `<base href>`, а он у
// собранной панели `/ui/`, а не корень. С корневым путём карта работала на
// dev-сервере и пропадала в контейнере - там `/maps/...` отдаёт 404, файлы
// лежат под `/ui/maps/...` (тот же случай, что был с картинками кита).
const maps: Record<MapKey, { title: string; art: string; geometry: string }> = {
  ek: { title: 'Восточные королевства', art: 'maps/ek.jpg', geometry: 'maps/ek.zones.json' },
  kalimdor: { title: 'Калимдор', art: 'maps/kalimdor.jpg', geometry: 'maps/kalimdor.zones.json' },
};
/** Номер карты мира -> ключ нарисованной карты. Для прочих карт её нет. */
function mapKeyOf(mapId: number): MapKey | null {
  if (mapId === 0) return 'ek';
  if (mapId === 1) return 'kalimdor';
  return null;
}

const colors: Record<string, string> = {
  clear: '#d8c48a',
  rain: '#4aa3ff',
  snow: '#cfe9ff',
  storm: '#d59a4a',
  special: '#c77dff',
};

@Component({
  selector: 'app-weather-map',
  styleUrl: './weather-map.component.scss',
  templateUrl: './weather-map.component.html',
})
export class WeatherMapComponent implements OnInit, OnChanges {
  @Input({ required: true }) zones: readonly WeatherZone[] = [];
  @Input() cyclones: readonly Cyclone[] = [];
  /** Режим постановки: щелчок по карте отдаёт точку в мировых ярдах. */
  @Input() picking = false;
  /**
   * Номер карты, которую надо показать. Ставится, когда выбрали фронт: искать
   * его глазами, переключая континенты руками, - лишняя работа.
   */
  @Input() focusMap: number | null = null;
  @Output() pointPicked = new EventEmitter<{ map: number; x: number; y: number }>();
  @Input() selectedId: number | null = null;
  @Output() readonly zoneSelected = new EventEmitter<number>();
  readonly active = signal<MapKey>('ek');
  readonly geometry = signal<MapGeometry | null>(null);
  readonly error = signal<string | null>(null);
  readonly mapKeys: readonly MapKey[] = ['ek', 'kalimdor'];
  readonly maps = maps;

  async ngOnInit(): Promise<void> {
    await this.load(this.active());
  }
  async ngOnChanges(changes: SimpleChanges): Promise<void> {
    if (changes['focusMap'] && this.focusMap !== null) {
      const key = mapKeyOf(this.focusMap);
      // Карты Запределья и Нордскола в панели нет вовсе - показывать нечего,
      // и переключать тогда не на что.
      if (key && key !== this.active()) await this.load(key);
    }

    if (!changes['selectedId'] || this.selectedId === null) return;
    const zone = this.zones.find((item) => item.zone_id === this.selectedId);
    if (
      zone &&
      (zone.continent === 'ek' || zone.continent === 'kalimdor') &&
      zone.continent !== this.active()
    )
      await this.load(zone.continent);
  }
  async selectMap(key: MapKey): Promise<void> {
    await this.load(key);
  }
  zone(id: number): WeatherZone | undefined {
    return this.zones.find((zone) => zone.zone_id === id);
  }
  fill(id: number): string {
    const zone = this.zone(id);
    if (!zone || !zone.known) return 'rgba(157, 151, 135, .12)';
    const color = colors[zone.state_group] ?? colors['clear'];
    if (zone.state_group === 'clear') return 'rgba(216, 196, 138, .16)';
    return this.rgba(
      color,
      0.28 + Math.min(0.42, Math.max(0, zone.grade) * 0.0042) + (this.selectedId === id ? 0.22 : 0),
    );
  }
  stroke(id: number): string {
    return this.selectedId === id ? '#ffe382' : 'rgba(14, 14, 12, .24)';
  }
  label(id: number): string {
    const zone = this.zone(id);
    return zone
      ? `${zone.name}: ${zone.state_label}${zone.state ? ` · ${zone.grade}%` : ''}`
      : 'Зона вне управления';
  }
  fronts(): MapFront[] {
    const geometry = this.geometry();
    if (!geometry) return [];

    const gridSize = 533.3333;
    const cellsPerGrid = 16;
    const yardsPerCell = gridSize / cellsPerGrid;
    const cellOf = (coordinate: number) => cellsPerGrid * (32 - coordinate / gridSize);
    const originColumn = Math.round(cellOf(geometry.rect[0]));
    const originRow = Math.round(cellOf(geometry.rect[2]));

    return this.cyclones
      .filter((cyclone) => cyclone.map === geometry.map && cyclone.radius > 0)
      .map((cyclone) => ({
        cyclone,
        x: cellOf(cyclone.y) - originColumn,
        y: cellOf(cyclone.x) - originRow,
        radius: cyclone.radius / yardsPerCell,
        eye: cyclone.eye / yardsPerCell,
        color: colors[cyclone.family_group] ?? colors['clear'],
      }));
  }
  /**
   * Точка щелчка в мировых ярдах - обратное преобразование к тому, которым
   * `fronts()` кладёт фронты на карту. Считается через матрицу самой SVG
   * (`getScreenCTM`), а не по размерам картинки: карта тянется по месту, и
   * своя арифметика масштаба разошлась бы с браузером на первой же ширине.
   */
  pick(event: MouseEvent): void {
    const geometry = this.geometry();
    const target = event.currentTarget as SVGSVGElement | null;
    if (!this.picking || !geometry || !target) return;

    const matrix = target.getScreenCTM();
    if (!matrix) return;

    const point = target.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    const local = point.matrixTransform(matrix.inverse());

    const gridSize = 533.3333;
    const cellsPerGrid = 16;
    const cellOf = (coordinate: number) => cellsPerGrid * (32 - coordinate / gridSize);
    const originColumn = Math.round(cellOf(geometry.rect[0]));
    const originRow = Math.round(cellOf(geometry.rect[2]));

    this.pointPicked.emit({
      map: geometry.map,
      // Оси на карте переставлены: по горизонтали идёт мировая Y, по
      // вертикали - мировая X. Так их кладёт `fronts()`, так и снимаем.
      x: Math.round(gridSize * (32 - (local.y + originRow) / cellsPerGrid)),
      y: Math.round(gridSize * (32 - (local.x + originColumn) / cellsPerGrid)),
    });
  }

  frontArrow(front: MapFront): string {
    const radians = (front.cyclone.heading * Math.PI) / 180;
    const dx = Math.cos(radians);
    const dy = Math.sin(radians);
    const length = Math.min(front.radius * 0.72, 46);
    const endX = front.x - dy * length;
    const endY = front.y - dx * length;
    const wing = 7;
    const perpendicularX = -dx;
    const perpendicularY = dy;

    return [
      `M${front.x.toFixed(1)} ${front.y.toFixed(1)} L${endX.toFixed(1)} ${endY.toFixed(1)}`,
      `M${endX.toFixed(1)} ${endY.toFixed(1)} l${(dy * wing + perpendicularX * wing * 0.6).toFixed(1)} ${(dx * wing + perpendicularY * wing * 0.6).toFixed(1)}`,
      `M${endX.toFixed(1)} ${endY.toFixed(1)} l${(dy * wing - perpendicularX * wing * 0.6).toFixed(1)} ${(dx * wing - perpendicularY * wing * 0.6).toFixed(1)}`,
    ].join(' ');
  }
  /**
   * Где писать подпись фронта. Обычно над кругом; у верхнего края карты она
   * уезжала за холст и просто не показывалась - тогда пишем под кругом.
   */
  frontLabelY(front: MapFront): number {
    const above = front.y - front.radius - 6;
    return above > 12 ? above : front.y + front.radius + 16;
  }

  frontTransform(front: MapFront): string {
    return `rotate(${-front.cyclone.spin} ${front.x.toFixed(1)} ${front.y.toFixed(1)})`;
  }
  private async load(key: MapKey): Promise<void> {
    this.active.set(key);
    this.geometry.set(null);
    try {
      const response = await fetch(maps[key].geometry);
      if (!response.ok) throw new Error(String(response.status));
      this.geometry.set((await response.json()) as MapGeometry);
      this.error.set(null);
    } catch {
      this.error.set('Файлы карты не найдены. Соберите их через build-map-assets.ps1.');
    }
  }
  private rgba(hex: string, alpha: number): string {
    const value = Number.parseInt(hex.slice(1), 16);
    return `rgba(${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255}, ${Math.min(alpha, 0.95).toFixed(2)})`;
  }
}
