'use strict';

// Redeeming an invite link: pick a login and a password, get the role the link
// carries, land signed in.
//
// The secret rides in the URL fragment (`/join.html#<token>`), not the query
// string. A fragment is never sent to the server as part of the request line,
// so the invitation does not end up in access logs or in a Referer header on
// the way to some other page.

const TOKEN_FROM_LINK = decodeURIComponent(location.hash.slice(1));

function showError(msg) {
  const box = document.getElementById('error');
  box.textContent = msg;
  box.classList.toggle('hidden', !msg);
}

function dead(msg) {
  const box = document.getElementById('invite');
  box.className = 'gate-error';
  box.textContent = msg;
}

async function init() {
  if (!TOKEN_FROM_LINK) {
    dead('В ссылке нет приглашения. Скопируй её целиком, вместе с частью '
         + 'после решётки.');
    return;
  }
  let invite;
  try {
    invite = await api('/api/auth/invite?token='
                       + encodeURIComponent(TOKEN_FROM_LINK));
  } catch (e) {
    dead(e.message);
    return;
  }

  const box = document.getElementById('invite');
  box.className = 'banner';
  box.textContent = `Роль по этой ссылке: ${invite.role_label}.`
    + (invite.note ? ` Подпись: «${invite.note}».` : '');
  document.getElementById('form').classList.remove('hidden');

  document.getElementById('form').addEventListener('submit', async ev => {
    ev.preventDefault();
    showError('');
    const password = document.getElementById('password').value;
    if (password !== document.getElementById('password2').value) {
      showError('Пароли не совпадают.');
      return;
    }
    const btn = document.getElementById('submit');
    btn.disabled = true;
    try {
      const out = await api('/api/auth/join', {
        method: 'POST',
        body: JSON.stringify({
          token: TOKEN_FROM_LINK,
          login: document.getElementById('login').value.trim(),
          name: document.getElementById('name').value.trim(),
          password,
        }),
      });
      // Drop the secret out of the address bar before leaving: the tab's
      // history entry would otherwise keep a live invitation in it.
      history.replaceState(null, '', '/join.html');
      toast(`Профиль ${out.actor.login} создан.`, 'good');
      location.href = '/';
    } catch (e) {
      showError(e.message);
      btn.disabled = false;
    }
  });
}

document.addEventListener('DOMContentLoaded', init);
