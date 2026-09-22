import { FeedItem } from './cdn.api';

/** Сколько строк ленты помещается в окне лаунчера (MainWindow: NewsRowLimit). */
export const NEWS_SHOWN = 5;

/**
 * Дата новости в том же виде, в каком её разбирает лаунчер: сперва
 * по-машинному, потом по-местному. Всё остальное - не дата.
 */
export function parseNewsDate(text: string): number | null {
  const machine = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text ?? '');
  if (machine) return Date.UTC(+machine[1], +machine[2] - 1, +machine[3]);
  const local = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(text ?? '');
  if (local) return Date.UTC(+local[3], +local[2] - 1, +local[1]);
  return null;
}

export function allDated(items: readonly FeedItem[]): boolean {
  return items.every((item) => parseNewsDate(item.date) !== null);
}

/**
 * Что игрок увидит в окне.
 *
 * Правило лаунчера повторено здесь нарочно: порядок в файле ручной, и
 * дописанная в конец новость иначе никогда бы не показалась - но сортируется
 * лента, ТОЛЬКО когда дата разобралась у всех строк. Перетасовать всю ленту
 * из-за одной кривой даты хуже, чем оставить порядок как есть.
 */
export function orderNews(items: readonly FeedItem[], limit = NEWS_SHOWN): FeedItem[] {
  const ordered = allDated(items)
    ? [...items].sort((left, right) => parseNewsDate(right.date)! - parseNewsDate(left.date)!)
    : [...items];
  return ordered.slice(0, limit);
}
