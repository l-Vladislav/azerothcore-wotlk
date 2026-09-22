const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const ts = require('typescript');

// Exercise the real handlers with deterministic HTTP responses and card geometry.
function fixture() {
  const api = {};
  const signal = (initial) => {
    let value = initial;
    const read = () => value;
    read.set = (next) => {
      value = next;
    };
    read.update = (update) => {
      value = update(value);
    };
    return read;
  };
  function load(file) {
    const filename = path.join(__dirname, '../src/app/features/board', file);
    const code = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
        experimentalDecorators: true,
      },
    }).outputText;
    const exports = {};
    vm.runInNewContext(
      code,
      {
        exports,
        setTimeout,
        clearTimeout,
        require(name) {
          if (name === '@angular/core')
            return { signal, inject: () => api, Component: () => () => {} };
          if (name === 'rxjs') return { firstValueFrom: (value) => value };
          if (name === './board-order') return load('board-order.ts');
          return {};
        },
      },
      { filename },
    );
    return exports;
  }
  const board = new (load('board.page.ts').BoardPage)();
  const card = (id, status = 'todo') => ({ id, status });
  const event = (ids, y) => ({
    preventDefault() {},
    clientY: y,
    currentTarget: {
      querySelectorAll: () =>
        ids.map((id, index) => ({
          dataset: { cardId: String(id) },
          getBoundingClientRect: () => ({ top: index * 100, height: 80 }),
        })),
    },
  });
  return { api, board, card, event };
}

test('moving down excludes the dragged card from the insertion index', async () => {
  const { api, board, card, event } = fixture();
  board.cards.set([card(1), card(2), card(3)]);
  api.move = async (id, status, position) => {
    assert.equal(id, 1);
    assert.equal(position, 1);
    return [card(2), card(1), card(3)];
  };
  board.dragStart(card(1), {});
  await board.drop('todo', event([1, 2, 3], 180));
  assert.deepEqual(
    board.cards().map((card) => card.id),
    [2, 1, 3],
  );
});

test('moving up and moving into an empty column use position zero', async () => {
  for (const ids of [[1, 2, 3], []]) {
    const { api, board, card, event } = fixture();
    board.cards.set([card(1), card(2), card(3)]);
    api.move = async (_id, _status, position) => {
      assert.equal(position, 0);
      return [];
    };
    board.dragStart(card(3), {});
    await board.drop(ids.length ? 'todo' : 'done', event(ids, 0));
  }
});

test('filtered drops anchor to the full column instead of the visible index', async () => {
  const { api, board, card, event } = fixture();
  board.filters.kind = 'bug';
  board.cards.set([card(1, 'doing'), card(3), card(5)]);
  api.cards = async () => [card(2), card(3), card(4), card(5)];
  api.move = async (_id, _status, position) => {
    assert.equal(position, 3);
    return [];
  };
  board.dragStart(card(1, 'doing'), {});
  await board.drop('todo', event([3, 5], 100));
  assert.equal(board.error(), null);
});

test('failed move preserves cards and releases the pending lock', async () => {
  const { api, board, card, event } = fixture();
  const original = [card(1)];
  board.cards.set(original);
  let reject;
  api.move = () =>
    new Promise((_resolve, fail) => {
      reject = fail;
    });
  board.dragStart(card(1), {});
  const pending = board.drop('done', event([], 0));
  assert.equal(board.moving(), true);
  let prevented = false;
  board.dragStart(card(1), {
    preventDefault() {
      prevented = true;
    },
  });
  assert.equal(prevented, true);
  reject(new Error('offline'));
  await pending;
  assert.equal(board.cards(), original);
  assert.equal(board.moving(), false);
  assert.ok(board.error());
});

test('older filter responses cannot overwrite newer results', async () => {
  const { api, board, card } = fixture();
  let resolve;
  api.cards = () =>
    new Promise((done) => {
      resolve = done;
    });
  const first = board.load();
  const oldResponse = resolve;
  const second = board.load();
  resolve([card(2)]);
  await second;
  oldResponse([card(1)]);
  await first;
  assert.equal(board.cards()[0].id, 2);
});
