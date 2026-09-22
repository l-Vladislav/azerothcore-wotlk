// Правила, которые легко сломать молча: они нигде не падают, просто начинают
// врать. Поэтому у них есть стенд, и он без зависимостей - node --test плюс
// транспиляция, как в board-drag.test.cjs.
//
//   cd tools/admin-panel/frontend && npm test
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const ts = require('typescript');

function load(relative) {
  const filename = path.join(__dirname, '..', 'src', 'app', relative);
  const code = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const exports = {};
  vm.runInNewContext(code, { exports, require: () => ({}), Date, Math, console }, { filename });
  return exports;
}

const loot = load('features/loot/loot-format.ts');
const news = load('features/settings/cdn/news-order.ts');

test('шанс: сотня пишется словом, ноль остаётся нулём', () => {
  assert.equal(loot.chanceText(100), 'всегда');
  assert.equal(loot.chanceText(0), '0 %');
  assert.equal(loot.chanceText(0.004), '<0.01 %');
  assert.equal(loot.chanceText(0.5), '0.50 %');
  assert.equal(loot.chanceText(15), '15 %');
});

test('полоска шанса: редкое видно, гарантированное занимает всё', () => {
  assert.equal(loot.chanceWidth(100), 100);
  assert.equal(loot.chanceWidth(0), 0);
  // Корневая шкала: 1 % даёт десятую часть полосы, а не невидимый волос.
  assert.equal(loot.chanceWidth(1), 10);
  // Даже у самого редкого остаётся видимый след.
  assert.ok(loot.chanceWidth(0.01) >= 3);
  // Шкала не убывает: больше шанс - не уже полоса.
  const widths = [0.1, 1, 5, 25, 50, 100].map(loot.chanceWidth);
  assert.deepEqual(widths, [...widths].sort((a, b) => a - b));
});

test('имя записи: своё важнее посчитанного, номер - на крайний случай', () => {
  assert.equal(loot.labelText({ name: 'Своё', auto: 'Авто' }, '17'), 'Своё');
  assert.equal(loot.labelText({ name: '', auto: 'Авто' }, '17'), 'Авто');
  assert.equal(loot.labelText(undefined, '17'), '17');
});

test('дата новости: обе формы лаунчера и ничего сверх', () => {
  assert.equal(news.parseNewsDate('2026-09-17'), Date.UTC(2026, 8, 17));
  assert.equal(news.parseNewsDate('17.09.2026'), Date.UTC(2026, 8, 17));
  assert.equal(news.parseNewsDate('вчера'), null);
  assert.equal(news.parseNewsDate('2026/09/17'), null);
  assert.equal(news.parseNewsDate(''), null);
});

test('лента: свежие вперёд, но только когда дата есть у всех', () => {
  const dated = [
    { date: '2026-01-01', title: 'старая' },
    { date: '2026-09-17', title: 'свежая' },
  ];
  assert.deepEqual(Array.from(news.orderNews(dated), (item) => item.title), [
    'свежая',
    'старая',
  ]);

  // Одна кривая дата - и порядок остаётся ручным, как в файле.
  const mixed = [
    { date: '2026-01-01', title: 'первая' },
    { date: 'когда-то', title: 'вторая' },
    { date: '2026-09-17', title: 'третья' },
  ];
  assert.deepEqual(Array.from(news.orderNews(mixed), (item) => item.title), [
    'первая',
    'вторая',
    'третья',
  ]);
});

test('лента: в окно уходит не больше пяти строк', () => {
  const many = Array.from({ length: 9 }, (_, index) => ({
    date: `2026-09-0${index + 1}`,
    title: `новость ${index + 1}`,
  }));
  const shown = news.orderNews(many);
  assert.equal(shown.length, news.NEWS_SHOWN);
  assert.equal(shown[0].title, 'новость 9');
});

test('лента: исходный список не переставляется на месте', () => {
  const items = [
    { date: '2026-01-01', title: 'старая' },
    { date: '2026-09-17', title: 'свежая' },
  ];
  news.orderNews(items);
  assert.equal(items[0].title, 'старая');
});
