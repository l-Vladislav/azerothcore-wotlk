'use strict';

// People and access. Owner-only: the server refuses every endpoint here to
// anybody else, so this page never has to decide what to hide.

const ROLE_HELP = {
  viewer: 'Читает всё и работает с доской: заводит баги, идеи и задачи, '
        + 'комментирует, двигает карточки. Ничего в модулях не меняет.',
  editor: 'Плюс редакторы модулей: погода, эффекты окружения, таланты '
        + 'предметов. Правки уходят на PTR.',
  owner: 'Плюс то, что тяжело откатить: мастерская спеллов, выгрузки в SQL и '
       + 'в клиент, сброс кэша — и раздача доступа, то есть эта страница.',
};

let STATE = { users: [], invites: [], roles: [] };

function fmtDate(value) {
  return value ? value.slice(0, 16) : '—';
}

function table(node, columns, rows, renderRow) {
  node.innerHTML = '';
  const head = el('thead');
  const hr = el('tr');
  for (const c of columns) hr.appendChild(el('th', '', c));
  head.appendChild(hr);
  node.appendChild(head);
  const body = el('tbody');
  for (const row of rows) body.appendChild(renderRow(row));
  node.appendChild(body);
}

// --- profiles -------------------------------------------------------------

function userRow(u) {
  const tr = el('tr', u.disabled ? 'row-off' : '');

  const who = el('td');
  who.appendChild(el('div', '', u.name || u.login));
  who.appendChild(el('div', 'muted', u.login));
  tr.appendChild(who);

  const roleCell = el('td');
  const sel = el('select', 'sel');
  for (const r of STATE.roles) {
    const opt = el('option', '', r.label);
    opt.value = r.id;
    if (r.id === u.role) opt.selected = true;
    sel.appendChild(opt);
  }
  // Demoting yourself is refused by the server; grey it out rather than let
  // the click look like it might work.
  sel.disabled = ME && u.id === ME.id;
  sel.addEventListener('change', () => patch(u, { role: sel.value }));
  roleCell.appendChild(sel);
  tr.appendChild(roleCell);

  tr.appendChild(el('td', 'muted', u.disabled ? 'отключён' : 'активен'));
  tr.appendChild(el('td', 'muted', fmtDate(u.last_seen)));
  tr.appendChild(el('td', 'muted', String(u.sessions)));
  tr.appendChild(el('td', 'muted', u.invited_by || '—'));

  const actions = el('td', 'row-actions');
  if (!ME || u.id !== ME.id) {
    const toggle = el('button', 'btn tiny ghost',
                      u.disabled ? 'Включить' : 'Отключить');
    toggle.addEventListener('click', () => patch(u, { disabled: !u.disabled }));
    actions.appendChild(toggle);

    if (u.sessions) {
      const kick = el('button', 'btn tiny ghost', 'Закрыть сессии');
      kick.addEventListener('click', async () => {
        await api(`/api/users/${u.id}/sessions/close`, { method: 'POST' });
        toast(`Сессии ${u.login} закрыты.`, 'good');
        load();
      });
      actions.appendChild(kick);
    }

    const del = el('button', 'btn tiny ghost danger', 'Удалить');
    del.addEventListener('click', async () => {
      if (!confirm(`Удалить профиль ${u.login}? Его карточки на доске и строки `
                   + `в журнале останутся — они подписаны именем, не ссылкой.`)) {
        return;
      }
      try {
        await api(`/api/users/${u.id}`, { method: 'DELETE' });
        toast(`Профиль ${u.login} удалён.`, 'good');
        load();
      } catch (e) { toast(e.message, 'bad'); }
    });
    actions.appendChild(del);
  }
  tr.appendChild(actions);
  return tr;
}

async function patch(u, body) {
  try {
    await api(`/api/users/${u.id}`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    });
    toast(`Профиль ${u.login} обновлён.`, 'good');
  } catch (e) {
    toast(e.message, 'bad');
  }
  load();
}

// --- invitations ----------------------------------------------------------

const INVITE_STATE = {
  live: ['можно использовать', 'good'],
  spent: ['использована', 'muted'],
  expired: ['срок истёк', 'muted'],
  revoked: ['отозвана', 'muted'],
};

function inviteRow(inv) {
  const tr = el('tr', inv.state === 'live' ? '' : 'row-off');
  tr.appendChild(el('td', 'muted', '#' + inv.id));
  const role = STATE.roles.find(r => r.id === inv.role);
  tr.appendChild(el('td', '', role ? role.label : inv.role));
  tr.appendChild(el('td', '', inv.note || '—'));
  const [label, cls] = INVITE_STATE[inv.state] || [inv.state, 'muted'];
  tr.appendChild(el('td', cls, label));
  tr.appendChild(el('td', 'muted', `${inv.uses} / ${inv.max_uses}`));
  tr.appendChild(el('td', 'muted', fmtDate(inv.expires_at)));
  tr.appendChild(el('td', 'muted', inv.created_by || '—'));

  const actions = el('td', 'row-actions');
  if (inv.state === 'live') {
    const revoke = el('button', 'btn tiny ghost danger', 'Отозвать');
    revoke.addEventListener('click', async () => {
      await api(`/api/invites/${inv.id}/revoke`, { method: 'POST' });
      toast('Приглашение отозвано.', 'good');
      load();
    });
    actions.appendChild(revoke);
  }
  tr.appendChild(actions);
  return tr;
}

function buildInviteForm() {
  const box = document.getElementById('invite-form');
  box.innerHTML = '';

  const roleField = el('label', 'field');
  roleField.appendChild(el('span', 'field-label', 'Роль'));
  const role = el('select', 'sel');
  role.id = 'inv-role';
  for (const r of STATE.roles) {
    const opt = el('option', '', r.label);
    opt.value = r.id;
    role.appendChild(opt);
  }
  roleField.appendChild(role);
  const help = el('div', 'hint', ROLE_HELP[role.value]);
  role.addEventListener('change', () => { help.textContent = ROLE_HELP[role.value]; });
  roleField.appendChild(help);
  box.appendChild(roleField);

  const note = el('label', 'field');
  note.appendChild(el('span', 'field-label', 'Подпись — для кого'));
  const noteInput = el('input', 'input');
  noteInput.id = 'inv-note';
  noteInput.maxLength = 120;
  noteInput.placeholder = 'например: Дима, погода';
  note.appendChild(noteInput);
  note.appendChild(el('div', 'hint',
    'Видно только тебе в этой таблице и приглашённому на странице входа.'));
  box.appendChild(note);

  const hours = el('label', 'field');
  hours.appendChild(el('span', 'field-label', 'Срок, часов'));
  const hoursInput = el('input', 'input');
  hoursInput.id = 'inv-hours';
  hoursInput.type = 'number';
  hoursInput.min = 1;
  hoursInput.max = 720;
  hoursInput.value = 72;
  hours.appendChild(hoursInput);
  box.appendChild(hours);

  const uses = el('label', 'field');
  uses.appendChild(el('span', 'field-label', 'Сколько раз можно использовать'));
  const usesInput = el('input', 'input');
  usesInput.id = 'inv-uses';
  usesInput.type = 'number';
  usesInput.min = 1;
  usesInput.max = 20;
  usesInput.value = 1;
  uses.appendChild(usesInput);
  uses.appendChild(el('div', 'hint',
    'Больше одного — если зовёшь сразу нескольких на одну роль. Каждый '
    + 'заведёт свой профиль.'));
  box.appendChild(uses);
}

async function createInvite() {
  const btn = document.getElementById('invite-create');
  btn.disabled = true;
  try {
    const invite = await api('/api/invites', {
      method: 'POST',
      body: JSON.stringify({
        role: document.getElementById('inv-role').value,
        note: document.getElementById('inv-note').value.trim(),
        expires_hours: Number(document.getElementById('inv-hours').value) || 72,
        max_uses: Number(document.getElementById('inv-uses').value) || 1,
      }),
    });
    document.getElementById('invite-modal').classList.add('hidden');
    showLink(invite);
    load();
  } catch (e) {
    toast(e.message, 'bad');
  }
  btn.disabled = false;
}

function showLink(invite) {
  const role = STATE.roles.find(r => r.id === invite.role);
  document.getElementById('link-value').value = invite.url;
  document.getElementById('link-meta').textContent =
    `Роль: ${role ? role.label : invite.role}. Годна до `
    + `${fmtDate(invite.expires_at)}, использований: ${invite.max_uses}.`;
  document.getElementById('link-modal').classList.remove('hidden');
  document.getElementById('link-value').select();
}

// --- load -----------------------------------------------------------------

async function load() {
  try {
    const [state, users, invites] = await Promise.all([
      api('/api/auth/state'),
      api('/api/users'),
      api('/api/invites'),
    ]);
    STATE = { roles: state.roles, users, invites };
  } catch (e) {
    document.getElementById('users-hint').textContent = e.message;
    return;
  }

  const legend = document.getElementById('role-legend');
  legend.innerHTML = '';
  for (const r of STATE.roles) {
    const n = STATE.users.filter(u => u.role === r.id && !u.disabled).length;
    const tile = el('div', 'tile');
    tile.appendChild(el('div', 'tile-label', r.label));
    tile.appendChild(el('div', 'tile-value', String(n)));
    tile.appendChild(el('div', 'tile-hint', ROLE_HELP[r.id] || ''));
    legend.appendChild(tile);
  }

  document.getElementById('users-hint').textContent =
    STATE.users.length ? '' : 'Профилей пока нет — выдай первое приглашение.';
  table(document.getElementById('users-table'),
        ['Кто', 'Роль', 'Состояние', 'Был', 'Сессий', 'Позвал', ''],
        STATE.users, userRow);

  const live = STATE.invites.filter(i => i.state === 'live').length;
  document.getElementById('invites-hint').textContent =
    STATE.invites.length ? `Действующих ссылок: ${live}.`
                         : 'Ссылок пока не выдавалось.';
  table(document.getElementById('invites-table'),
        ['#', 'Роль', 'Подпись', 'Состояние', 'Использований', 'Годна до',
         'Выдал', ''],
        STATE.invites, inviteRow);
}

function init() {
  document.getElementById('btn-invite').addEventListener('click', () => {
    buildInviteForm();
    document.getElementById('invite-modal').classList.remove('hidden');
  });
  document.getElementById('invite-close').addEventListener('click', () => {
    document.getElementById('invite-modal').classList.add('hidden');
  });
  document.getElementById('invite-create').addEventListener('click', createInvite);
  document.getElementById('link-close').addEventListener('click', () => {
    document.getElementById('link-modal').classList.add('hidden');
  });
  document.getElementById('link-copy').addEventListener('click', async () => {
    const box = document.getElementById('link-value');
    box.select();
    try {
      await navigator.clipboard.writeText(box.value);
      toast('Ссылка скопирована.', 'good');
    } catch (_) {
      // Clipboard access needs a secure context, and the panel is plain HTTP
      // over the tailnet — leave the text selected so Ctrl+C still works.
      toast('Скопируй вручную: текст выделен.', '');
    }
  });
  load();
}

document.addEventListener('DOMContentLoaded', init);
