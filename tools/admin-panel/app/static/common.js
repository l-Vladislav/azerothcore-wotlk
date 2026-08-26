'use strict';

// Shared by every page: the API call, the session, DOM helpers, toasts.
//
// Identity is a session cookie now, set by /login.html and sent automatically.
// The old shared token survives in localStorage as the break-glass: it still
// works as an owner, so a broken session table does not lock you out of your
// own server.

let TOKEN = localStorage.getItem('adminToken') || '';

// The two pages that must work signed out — they are how you sign in.
const OPEN_PAGES = ['/login.html', '/join.html'];
const isOpenPage = () => OPEN_PAGES.includes(location.pathname);

function goToLogin() {
  if (isOpenPage()) return;
  const next = encodeURIComponent(location.pathname + location.search);
  location.href = '/login.html?next=' + next;
}

async function api(path, opts = {}) {
  const headers = Object.assign({}, opts.headers || {});
  if (TOKEN) headers['X-Admin-Token'] = TOKEN;
  if (opts.body) headers['Content-Type'] = 'application/json';
  // credentials: same-origin is the default for fetch, but say it out loud —
  // the whole auth scheme rides on that cookie.
  const res = await fetch(path, Object.assign({ credentials: 'same-origin' },
                                              opts, { headers }));
  if (res.status === 401 && !isOpenPage()) {
    goToLogin();
    throw new Error('Нужен вход');
  }
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (_) { data = text; }
  if (!res.ok) {
    const detail = data && data.detail ? data.detail : text;
    const err = new Error(typeof detail === 'string' ? detail : (detail.detail || 'Ошибка'));
    err.payload = detail;
    err.status = res.status;
    // A refusal by role is not a bug in the page and not something the page
    // author has to handle — say who you are and what it needs, once, here.
    if (res.status === 403) toast(err.message, 'bad');
    throw err;
  }
  return data;
}

// --- the signed-in profile ------------------------------------------------
// Filled by mountSession() before the page script needs it. Role gating is
// enforced by the server on every endpoint; what happens here is only the
// honest labelling of it — the nav hides pages you cannot open, and a refusal
// arrives as a readable toast instead of a silent no-op.

let ME = null;
const RANK = { viewer: 0, editor: 1, owner: 2 };
const ROLE_LABEL = { viewer: 'смотрящий', editor: 'редактор', owner: 'владелец' };

function can(role) { return !!ME && RANK[ME.role] >= RANK[role]; }

async function mountSession() {
  if (isOpenPage()) return null;
  let state;
  try {
    state = await fetch('/api/auth/state', {
      credentials: 'same-origin',
      headers: TOKEN ? { 'X-Admin-Token': TOKEN } : {},
    }).then(r => r.json());
  } catch (_) {
    return null;                       // panel unreachable; pages say so already
  }
  if (!state.signed_in) { goToLogin(); return null; }
  ME = state.actor;
  document.body.dataset.role = ME.role;

  const bar = document.querySelector('.topbar');
  if (!bar) return ME;

  // Owner-only pages are added here rather than written into eight copies of
  // the nav: every page already loads this file.
  const nav = bar.querySelector('.nav');
  if (nav && can('owner')) {
    const api_link = nav.querySelector('a[href="/api/docs"]');
    for (const [href, label] of [['/users.html', 'Люди'],
                                 ['/audit.html', 'Журнал']]) {
      const a = el('a', location.pathname === href ? 'active' : '', label);
      a.href = href;
      nav.insertBefore(a, api_link);
    }
  }

  const chip = el('div', 'me');
  const who = el('button', 'me-name');
  who.innerHTML = '';
  who.appendChild(el('span', '', ME.name));
  who.appendChild(el('span', 'me-role', ROLE_LABEL[ME.role] || ME.role));
  const menu = el('div', 'me-menu hidden');
  const item = (label, fn) => {
    const b = el('button', 'me-item', label);
    b.addEventListener('click', fn);
    menu.appendChild(b);
  };
  if (ME.source === 'session') item('Сменить пароль', changePassword);
  item('Выйти', signOut);
  who.addEventListener('click', ev => {
    ev.stopPropagation();
    menu.classList.toggle('hidden');
  });
  document.addEventListener('click', () => menu.classList.add('hidden'));
  chip.appendChild(who);
  chip.appendChild(menu);
  bar.appendChild(chip);
  return ME;
}

async function signOut() {
  try { await api('/api/auth/logout', { method: 'POST' }); } catch (_) {}
  localStorage.removeItem('adminToken');
  location.href = '/login.html';
}

async function changePassword() {
  const current = prompt('Текущий пароль:');
  if (current === null) return;
  const password = prompt('Новый пароль (минимум 8 символов):');
  if (!password) return;
  try {
    await api('/api/auth/password', {
      method: 'POST',
      body: JSON.stringify({ current, password }),
    });
    toast('Пароль изменён; остальные сессии закрыты.', 'good');
  } catch (e) {
    toast(e.message, 'bad');
  }
}

document.addEventListener('DOMContentLoaded', mountSession);

function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text !== undefined) n.textContent = text;
  return n;
}

// --- help tooltips --------------------------------------------------------
// A "?" badge next to a label. The bubble is one shared node on <body>, placed
// with fixed coordinates: a CSS ::after tooltip would be clipped by the
// editor's own scrolling containers, and there are enough spell fields that
// clipping would happen on every second one.

let tipNode = null;

function tipBubble() {
  if (!tipNode) {
    tipNode = el('div', 'tip hidden');
    document.body.appendChild(tipNode);
  }
  return tipNode;
}

function showTip(text, anchor) {
  const tip = tipBubble();
  tip.textContent = text;
  tip.classList.remove('hidden');
  const box = anchor.getBoundingClientRect();
  const size = tip.getBoundingClientRect();
  const margin = 8;
  let left = box.left;
  if (left + size.width > window.innerWidth - margin) {
    left = window.innerWidth - size.width - margin;
  }
  // Flip above the badge when there is no room below it.
  let top = box.bottom + 6;
  if (top + size.height > window.innerHeight - margin) {
    top = Math.max(margin, box.top - size.height - 6);
  }
  tip.style.left = Math.max(margin, left) + 'px';
  tip.style.top = top + 'px';
}

function hideTip() {
  if (tipNode) tipNode.classList.add('hidden');
}

function helpBadge(text) {
  const badge = el('span', 'help', '?');
  badge.tabIndex = 0;
  badge.setAttribute('role', 'button');
  badge.setAttribute('aria-label', text);
  badge.addEventListener('mouseenter', () => showTip(text, badge));
  badge.addEventListener('mouseleave', hideTip);
  badge.addEventListener('focus', () => showTip(text, badge));
  badge.addEventListener('blur', hideTip);
  // The badge sits inside <label> and inside collapsible <button> headers —
  // without this a hint click would focus the input or fold the group.
  badge.addEventListener('click', ev => {
    ev.preventDefault();
    ev.stopPropagation();
    if (tipNode && !tipNode.classList.contains('hidden')) hideTip();
    else showTip(text, badge);
  });
  return badge;
}

window.addEventListener('scroll', hideTip, true);

// --- searchable dropdown --------------------------------------------------
// Built by hand rather than with <datalist>: a datalist filters its options by
// whatever text is already in the input, so a field holding "6 — Apply aura"
// offers exactly one suggestion — the value it already has. Lists here run to
// 318 auras, so "see everything, then narrow it down" is the whole point.

function comboBox(options, value, onChange) {
  const wrap = el('div', 'combo');
  const input = el('input', 'input');
  const panel = el('div', 'combo-panel hidden');
  const labelOf = o => `${o.id} — ${o.label}`;

  let current = Number(value) || 0;
  let shown = options;
  let active = -1;
  let term = '';               // what the list is currently filtered by

  function display() {
    const hit = options.find(o => o.id === current);
    input.value = hit ? labelOf(hit) : String(current);
  }

  function render() {
    const needle = term.trim().toLowerCase();
    shown = !needle ? options : options.filter(o =>
      labelOf(o).toLowerCase().includes(needle) ||
      (o.const || '').toLowerCase().includes(needle));
    panel.innerHTML = '';
    if (!shown.length) {
      panel.appendChild(el('div', 'combo-empty', 'ничего не найдено'));
      return;
    }
    shown.forEach((option, index) => {
      const row = el('div', 'combo-item'
        + (option.id === current ? ' current' : '')
        + (index === active ? ' active' : ''), labelOf(option));
      if (option.const) row.title = option.const;
      // mousedown, not click: blur fires first and would close the panel.
      row.addEventListener('mousedown', ev => { ev.preventDefault(); pick(option); });
      panel.appendChild(row);
    });
  }

  function open(filter) {
    term = filter || '';
    active = -1;
    render();
    panel.classList.remove('hidden');
  }

  function close() {
    panel.classList.add('hidden');
    active = -1;
    display();
  }

  function pick(option) {
    current = option.id;
    onChange(current);
    close();
  }

  function move(step) {
    if (panel.classList.contains('hidden')) { open(''); return; }
    if (!shown.length) return;
    active = (active + step + shown.length) % shown.length;
    render();
    const node = panel.children[active];
    if (node) node.scrollIntoView({ block: 'nearest' });
  }

  input.addEventListener('focus', () => { input.select(); open(''); });
  input.addEventListener('input', () => open(input.value));
  input.addEventListener('blur', close);
  input.addEventListener('keydown', ev => {
    if (ev.key === 'ArrowDown') { ev.preventDefault(); move(1); }
    else if (ev.key === 'ArrowUp') { ev.preventDefault(); move(-1); }
    else if (ev.key === 'Escape') { ev.preventDefault(); input.blur(); }
    else if (ev.key === 'Enter') {
      ev.preventDefault();
      if (active >= 0 && shown[active]) pick(shown[active]);
      else if (shown.length === 1) pick(shown[0]);
      else {
        // A raw id typed in full is a legitimate answer even when no label
        // matches — enums grow faster than this JSON does.
        const typed = parseInt(input.value, 10);
        if (Number.isFinite(typed)) { current = typed; onChange(typed); }
        close();
      }
    }
  });

  display();
  wrap.appendChild(input);
  wrap.appendChild(panel);
  return wrap;
}

let toastTimer = null;
function toast(msg, kind) {
  let t = document.getElementById('toast');
  if (!t) {
    t = el('div', 'toast hidden');
    t.id = 'toast';
    document.body.appendChild(t);
  }
  t.textContent = msg;
  t.className = 'toast ' + (kind || '');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add('hidden'), 6000);
}
