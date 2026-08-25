'use strict';

// Sign-in. Two doors: a profile (login + password → session cookie) and the
// shared ADMIN_PANEL_TOKEN, which stays as the owner's break-glass and as the
// only way in before the first profile exists.

function nextUrl() {
  const raw = new URLSearchParams(location.search).get('next') || '/';
  // Only ever bounce back inside the panel: an open redirect here would let a
  // crafted link send someone to a copy of this form on another host.
  return raw.startsWith('/') && !raw.startsWith('//') ? raw : '/';
}

function showError(msg) {
  const box = document.getElementById('error');
  box.textContent = msg;
  box.classList.toggle('hidden', !msg);
}

async function init() {
  let state = null;
  try {
    state = await fetch('/api/auth/state', { credentials: 'same-origin' })
      .then(r => r.json());
  } catch (_) {
    showError('Панель недоступна.');
    return;
  }
  if (state.signed_in) { location.href = nextUrl(); return; }
  if (state.bootstrap) {
    document.getElementById('bootstrap').classList.remove('hidden');
    // Nobody can satisfy the login form yet — open the token door instead of
    // making the first owner guess where it is.
    document.querySelector('.gate-alt').open = true;
  }

  document.getElementById('form').addEventListener('submit', async ev => {
    ev.preventDefault();
    showError('');
    const btn = document.getElementById('submit');
    btn.disabled = true;
    try {
      await api('/api/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          login: document.getElementById('login').value.trim(),
          password: document.getElementById('password').value,
        }),
      });
      location.href = nextUrl();
    } catch (e) {
      showError(e.message);
      btn.disabled = false;
    }
  });

  document.getElementById('token-submit').addEventListener('click', async () => {
    showError('');
    const token = document.getElementById('token').value.trim();
    if (!token) return;
    // Store it first: api() reads TOKEN from localStorage at load, and the
    // check below is the same request the rest of the panel will be making.
    localStorage.setItem('adminToken', token);
    TOKEN = token;
    try {
      const state = await fetch('/api/auth/state', {
        credentials: 'same-origin',
        headers: { 'X-Admin-Token': token },
      }).then(r => r.json());
      if (!state.signed_in) throw new Error('Токен не подошёл.');
      location.href = nextUrl();
    } catch (e) {
      localStorage.removeItem('adminToken');
      TOKEN = '';
      showError(e.message);
    }
  });
}

document.addEventListener('DOMContentLoaded', init);
