// June Borns Family member app (installable web app).
// Talks to the same cloud as the Android app: the member-auth function for
// sign-in and the member_* / chat_* functions for everything after.
'use strict';

const CLOUD = 'https://ucheilfvkovukzunkvrl.supabase.co';
const KEY = 'sb_publishable__fqy0XUzs6MG7zkEEWigTQ_Ez15BGoL';
const ORG = 'JBF';
const SESSION_KEY = 'jbf_session';
const HOME_KEY = 'jbf_home';

const app = document.getElementById('app');
const tabsEl = document.getElementById('tabs');

const store = {
  get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch (_) { return null; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) { /* private mode */ } },
  del(k) { try { localStorage.removeItem(k); } catch (_) { /* private mode */ } },
};

let session = store.get(SESSION_KEY);
let home = null;
let tab = 'home';
let pollTimer = null;
let offline = false;

// ---------- helpers ----------
function h(tag, attrs, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === 'class') e.className = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else if (k === 'value') e.value = v;
    else e.setAttribute(k, v === true ? '' : v);
  }
  for (const kid of kids.flat()) {
    if (kid == null || kid === false) continue;
    e.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
  }
  return e;
}

const money = (p) => 'GHS ' + (p / 100).toLocaleString('en-GH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const monthName = (period) => {
  if (!period) return '';
  const [y, m] = period.split('-').map(Number);
  return new Date(y, m - 1, 1).toLocaleDateString('en-GB', { month: 'long', year: 'numeric' });
};
const day = (iso) => iso
  ? new Date(String(iso).slice(0, 10) + 'T12:00:00').toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
  : '';
const methods = { cash: 'Cash', momo: 'Mobile money', bank: 'Bank' };
const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent) ||
  (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const standalone = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

class ApiError extends Error {
  constructor(message, expired) { super(message); this.expired = !!expired; }
}

async function call(path, body) {
  let res;
  try {
    res = await fetch(CLOUD + path, {
      method: 'POST',
      headers: { apikey: KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch (_) {
    throw new ApiError('Connect to the internet and try again.', false);
  }
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    const msg = (data && data.message) || 'Something went wrong. Please try again.';
    throw new ApiError(msg, /sign in again|was reset|activate your account/i.test(msg));
  }
  return data;
}
const rpc = (name, args) => call('/rest/v1/rpc/' + name, args);
const auth = (body) => call('/functions/v1/member-auth', { org: ORG, ...body });

function stopPolling() { if (pollTimer) clearInterval(pollTimer); pollTimer = null; }

function signOutLocal() {
  stopPolling();
  session = null; home = null; tab = 'home';
  store.del(SESSION_KEY); store.del(HOME_KEY);
  renderAuth('signin');
}

// ---------- sign in ----------
function renderAuth(mode, message) {
  stopPolling();
  tabsEl.hidden = true;
  const activating = mode === 'activate';
  const err = h('p', { class: 'error', role: 'alert', hidden: !message }, message || '');
  const idInput = h('input', { id: 'memberNo', placeholder: 'JBF-000123', autocomplete: 'username', autocapitalize: 'characters', required: true });
  const phone = h('input', { id: 'phone', type: 'tel', placeholder: '024 123 4567', autocomplete: 'tel', required: true });
  const pass = h('input', { id: 'pass', type: 'password', autocomplete: activating ? 'new-password' : 'current-password', required: true, minlength: activating ? 6 : 1 });
  const btn = h('button', { type: 'submit' }, activating ? 'Activate and sign in' : 'Sign in');
  const form = h('form', { class: 'card', onsubmit: async (e) => {
    e.preventDefault();
    err.hidden = true;
    btn.disabled = true;
    const label = btn.textContent;
    btn.textContent = 'Please wait...';
    try {
      const r = await auth(activating
        ? { action: 'activate', member_no: idInput.value.trim(), phone: phone.value.trim(), new_password: pass.value, device_name: 'Web app' }
        : { action: 'sign_in', member_no: idInput.value.trim(), password: pass.value, device_name: 'Web app' });
      if (r.kind === 'officer') {
        throw new ApiError('You hold an executive role. Please use the JBF Android app to work with your role.');
      }
      if (r.kind !== 'member') throw new ApiError('Could not sign you in.');
      session = { token: r.token, member_key: r.member_key, member_no: r.member_no, name: r.name, org_name: r.org_name };
      store.set(SESSION_KEY, session);
      await loadHome();
    } catch (ex) {
      err.textContent = ex.message;
      err.hidden = false;
      btn.disabled = false;
      btn.textContent = label;
    }
  } },
    h('h2', null, activating ? 'Activate your account' : 'Sign in'),
    h('p', { class: 'hint' }, activating
      ? 'First time here? Enter your member ID and the phone number the association has for you, then choose a password.'
      : 'Sign in with your member ID and password.'),
    h('label', { for: 'memberNo' }, 'Member ID'), idInput,
    activating ? [h('label', { for: 'phone' }, 'Phone number'), phone] : null,
    h('label', { for: 'pass' }, activating ? 'Choose a password (6 or more characters)' : 'Password'), pass,
    err, btn,
    h('button', { class: 'link', type: 'button', onclick: () => renderAuth(activating ? 'signin' : 'activate') },
      activating ? 'I already have a password' : 'First time? Activate your account'),
  );
  app.replaceChildren(form, installHint());
}

function installHint() {
  if (standalone) return h('span');
  if (isIos) {
    return h('div', { class: 'notice' },
      h('b', null, 'Add this app to your iPhone'), h('br'),
      'In Safari, tap the Share button, then "Add to Home Screen". It will open like an app.');
  }
  return h('div', { class: 'notice' }, 'You can add this app to your home screen from your browser menu.');
}

// ---------- data ----------
async function loadHome() {
  try {
    home = await rpc('member_home', { token: session.token });
    store.set(HOME_KEY, home);
    offline = false;
  } catch (ex) {
    if (ex.expired) { signOutLocal(); renderAuth('signin', ex.message); return; }
    home = store.get(HOME_KEY);
    if (!home) { renderAuth('signin', ex.message); return; }
    offline = true;
  }
  document.getElementById('orgName').textContent = session.org_name || 'June Borns Family';
  renderTabs();
  show('home');
}

const realZones = (m) => (m.zones || []).filter((z) => z !== 'Unassigned');

// ---------- tabs ----------
const TABS = [
  ['home', '🏠', 'Home'],
  ['pay', '🧾', 'Payments'],
  ['community', '👥', 'Community'],
  ['chat', '💬', 'Chats'],
  ['me', '👤', 'Me'],
];

function renderTabs() {
  tabsEl.hidden = false;
  tabsEl.replaceChildren(...TABS.map(([id, icon, label]) =>
    h('button', { class: id === tab ? 'on' : '', onclick: () => show(id) }, h('b', null, icon), label)));
}

function show(id) {
  stopPolling();
  tab = id;
  renderTabs();
  const view = { home: viewHome, pay: viewPay, community: viewCommunity, chat: viewChannels, me: viewMe }[id]();
  app.replaceChildren(...(offline ? [h('div', { class: 'notice' }, 'You are offline. Showing what was saved last time.')] : []), view);
  window.scrollTo(0, 0);
}

function chips(roles) {
  const list = roles && roles.length ? roles : ['Member'];
  return h('div', { class: 'chips' }, list.slice(0, 4).map((r, i) => h('span', { class: 'chip' + (i === 0 ? ' lead' : '') }, r)),
    list.length > 4 ? h('span', { class: 'chip' }, '+' + (list.length - 4) + ' more') : null);
}

function idCard() {
  const m = home.member;
  return h('div', { class: 'idcard card', style: 'padding:0' },
    h('div', { class: 'top' }, h('img', { src: 'logo.png', alt: '' }),
      h('div', null, h('b', null, session.org_name || 'June Borns Family'), h('small', null, 'MEMBERSHIP CARD'))),
    h('div', { class: 'body' },
      h('div', { style: 'font-weight:700;font-size:1.05rem' }, m.name),
      h('div', { class: 'no' }, m.member_no),
      h('div', { class: 'sub' }, 'Zone: ' + (realZones(m).join(', ') || 'Not chosen yet')),
      h('div', { class: 'sub' }, 'Member since ' + day(m.joined)),
      chips(home.roles)));
}

function viewHome() {
  const out = h('div');
  const notes = home.announcements || [];
  for (const a of notes) out.append(h('div', { class: 'notice' }, a));
  for (const w of home.warnings || []) {
    out.append(h('div', { class: 'notice' }, h('b', null, 'Notice from the Disciplinary Committee'), h('br'), w.details,
      h('div', { class: 'sub' }, day(w.at))));
  }
  if (needsZone()) {
    out.append(h('div', { class: 'notice' }, h('b', null, 'Please choose your zone'), h('br'),
      'You can only choose once. Go to Me > My details.',
      h('div', null, h('button', { class: 'small', onclick: () => show('me') }, 'Choose my zone'))));
  }
  out.append(idCard());
  for (const d of home.dues || []) {
    const card = h('div', { class: 'card' }, h('h2', null, d.name));
    if (d.outstanding > 0) {
      card.append(h('div', { class: 'big owed' }, money(d.outstanding)),
        h('p', { class: 'hint' }, `Owed: ${d.months_behind} month${d.months_behind === 1 ? '' : 's'} behind, from ${monthName(d.next_unpaid)}.`));
    } else {
      card.append(h('div', { class: 'big clear' }, 'Up to date'), h('p', { class: 'hint' }, 'Thank you for keeping your dues paid.'));
    }
    for (const [l, v] of [['Monthly amount', money(d.monthly)], ['Months due so far', String(d.months)], ['Expected', money(d.expected)], ['Paid', money(d.paid)]]) {
      card.append(h('div', { class: 'row' }, h('span', null, l), h('span', null, v)));
    }
    out.append(card);
  }
  if (home.updated) out.append(h('p', { class: 'hint' }, 'Records last updated ' + new Date(home.updated).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' }) + '.'));
  return out;
}

// A member from the founding list whose only zone is the holding zone.
function needsZone() {
  return home.self_edit && !home.zones_locked && !(home.zone_ids || []).some((z) => (home.zone_options || []).some((o) => o.id === z));
}

function viewPay() {
  const card = h('div', { class: 'card' }, h('h2', null, 'Payments'));
  const pays = home.payments || [];
  if (!pays.length) card.append(h('p', { class: 'hint' }, 'No payments recorded yet.'));
  for (const p of pays) {
    card.append(h('div', { class: 'pay' },
      h('div', { class: 'top' }, h('span', null, p.type || 'Payment'), h('span', null, money(p.amount))),
      h('div', { class: 'sub' }, [day(p.paid_on), p.period ? 'for ' + monthName(p.period) : '', methods[p.method] || p.method, p.receipt_no].filter(Boolean).join(' · '))));
  }
  return card;
}

function viewCommunity() {
  const out = h('div');
  const events = home.events || [];
  const ev = h('div', { class: 'card' }, h('h2', null, 'Events and meetings'));
  if (!events.length) ev.append(h('p', { class: 'hint' }, 'Nothing coming up.'));
  for (const e of events) {
    ev.append(h('div', { class: 'pay' }, h('div', { class: 'top' }, h('span', null, e.name), h('span', null, day(e.date))),
      h('div', { class: 'sub' }, [e.kind === 'meeting' ? 'Meeting' : 'Event', e.venue].filter(Boolean).join(' · ')),
      e.description ? h('div', { class: 'sub' }, e.description) : null));
  }
  out.append(ev);
  const welfare = home.welfare || [];
  if (welfare.length) {
    const w = h('div', { class: 'card' }, h('h2', null, 'My welfare cases'));
    for (const c of welfare) {
      w.append(h('div', { class: 'pay' }, h('div', { class: 'top' }, h('span', null, c.type || 'Welfare'), h('span', null, money(c.amount))),
        h('div', { class: 'sub' }, [c.case_no, c.status, c.beneficiary, day(c.occurred_on)].filter(Boolean).join(' · '))));
    }
    out.append(w);
  }
  const ex = h('div', { class: 'card' }, h('h2', null, 'Our executives'));
  for (const x of home.executives || []) {
    ex.append(h('div', { class: 'row' }, h('span', null, x.name), h('span', null, [x.position, x.zone].filter(Boolean).join(', '))));
  }
  out.append(ex);
  return out;
}

// ---------- chats ----------
function viewChannels() {
  const box = h('div', null, h('p', { class: 'hint' }, 'Loading chats...'));
  rpc('chat_channels', { token: session.token, as_name: null }).then((chans) => {
    box.replaceChildren(h('h2', null, 'Chats'), ...chans.map((c) =>
      h('button', { class: 'chan', onclick: () => openChat(c) }, h('b', null, c.name), h('div', { class: 'sub' }, c.last || 'No messages yet'))),
      chans.length ? null : h('p', { class: 'hint' }, 'You are not in any chats yet.'));
  }).catch((ex) => {
    if (ex.expired) return signOutLocal();
    box.replaceChildren(h('p', { class: 'error' }, ex.message));
  });
  return box;
}

function openChat(chan) {
  stopPolling();
  const list = h('div', { class: 'msgs' });
  let last = null;
  const seen = new Set();
  const add = (msgs) => {
    for (const m of msgs) {
      if (seen.has(m.id)) continue;
      seen.add(m.id);
      last = m.at;
      list.append(h('div', { class: 'msg' + (m.mine ? ' mine' : '') }, m.mine ? null : h('b', null, m.author), m.body));
    }
    if (msgs.length) window.scrollTo(0, document.body.scrollHeight);
  };
  const load = async () => {
    try { add(await rpc('chat_messages', { token: session.token, channel: chan.id, after: last, as_name: null })); }
    catch (ex) { if (ex.expired) signOutLocal(); }
  };
  const input = h('input', { placeholder: 'Write a message', maxlength: 1000 });
  const send = async (e) => {
    e.preventDefault();
    const body = input.value.trim();
    if (!body) return;
    input.value = '';
    try { await rpc('chat_send', { token: session.token, channel: chan.id, body, as_name: null }); await load(); }
    catch (ex) { input.value = body; alert(ex.message); }
  };
  app.replaceChildren(
    h('button', { class: 'link', onclick: () => show('chat') }, '‹ All chats'),
    h('h2', null, chan.name), list,
    chan.post ? h('form', { class: 'send', onsubmit: send }, input, h('button', { type: 'submit' }, 'Send'))
      : h('p', { class: 'hint' }, 'Only officers can post here.'));
  load();
  pollTimer = setInterval(load, 8000);
}

// ---------- me ----------
const FIELDS = [
  ['full_name', 'Full name', 'text'], ['phone', 'Phone number', 'tel'], ['whatsapp', 'Second or WhatsApp number', 'tel'],
  ['email', 'Email', 'email'], ['occupation', 'Occupation', 'text'], ['location', 'Town or area', 'text'],
  ['address', 'Address', 'text'], ['gps_address', 'GPS address', 'text'],
  ['emergency_name', 'Emergency contact name', 'text'], ['emergency_phone', 'Emergency contact phone', 'tel'],
];

function viewMe() {
  const out = h('div');
  out.append(h('div', { class: 'card' }, h('h2', null, home.member.name),
    h('div', { class: 'row' }, h('span', null, 'Member ID'), h('span', null, home.member.member_no)),
    chips(home.roles)));
  out.append(home.self_edit ? profileForm() : h('p', { class: 'hint' }, 'To correct your details, speak to your Zone Secretary.'));
  out.append(passwordForm());
  out.append(h('button', { class: 'link', onclick: async () => {
    try { await rpc('member_sign_out', { token: session.token }); } catch (_) { /* leave locally anyway */ }
    signOutLocal();
  } }, 'Sign out'));
  out.append(installHint());
  return out;
}

function profileForm() {
  const p = home.profile || {};
  const inputs = {};
  const err = h('p', { class: 'error', role: 'alert', hidden: true });
  const gender = h('select', null, ...[['', 'Not said'], ['Male', 'Male'], ['Female', 'Female']]
    .map(([v, t]) => h('option', { value: v, selected: (p.gender || '') === v }, t)));
  const options = home.zone_options || [];
  const chosen = new Set((home.zone_ids || []).filter((z) => options.some((o) => o.id === z)));
  const locked = !!home.zones_locked;
  const zoneBox = h('div');
  const drawZones = () => {
    zoneBox.replaceChildren(h('h2', null, 'My zone'));
    if (locked) {
      zoneBox.append(h('p', null, options.filter((o) => chosen.has(o.id)).map((o) => o.name).join(', ') || 'Not chosen'),
        h('p', { class: 'hint' }, 'You have already chosen your zone. To change it, speak to your Zone Secretary.'));
      return;
    }
    zoneBox.append(h('p', { class: 'hint' }, 'Choose one zone, or two at most. You can only do this once, so choose carefully.'));
    for (const o of options) {
      zoneBox.append(h('label', { class: 'zone' }, h('input', { type: 'checkbox', checked: chosen.has(o.id), onchange: (e) => {
        if (e.target.checked) {
          if (chosen.size >= 2) { e.target.checked = false; err.textContent = 'A member can belong to at most 2 zones.'; err.hidden = false; return; }
          chosen.add(o.id);
        } else chosen.delete(o.id);
        err.hidden = true;
      } }), o.name));
    }
  };
  drawZones();
  const btn = h('button', { type: 'submit' }, 'Save my details');
  return h('form', { class: 'card', onsubmit: async (e) => {
    e.preventDefault();
    err.hidden = true;
    if (!locked && chosen.size < 1) { err.textContent = 'Choose at least 1 zone.'; err.hidden = false; return; }
    if (!locked && !confirm('You can only choose your zone once. Save these zones?')) return;
    btn.disabled = true;
    const patch = { gender: gender.value || null };
    for (const [k] of FIELDS) patch[k] = inputs[k].value;
    try {
      const ordered = [...(home.zone_ids || []).filter((z) => chosen.has(z)), ...[...chosen].filter((z) => !(home.zone_ids || []).includes(z))];
      await rpc('member_update_profile', { token: session.token, patch, zone_ids: locked ? null : ordered });
      await loadHome();
      show('me');
    } catch (ex) {
      if (ex.expired) return signOutLocal();
      err.textContent = ex.message; err.hidden = false;
      btn.disabled = false;
    }
  } },
    h('h2', null, 'My details'),
    h('p', { class: 'hint' }, 'Please check your name, phone number and zone are right and correct anything that is not.'),
    ...FIELDS.map(([k, label, type]) => {
      inputs[k] = h('input', { type, value: p[k] || '', maxlength: 200 });
      return [h('label', null, label), inputs[k]];
    }),
    h('label', null, 'Gender'), gender,
    zoneBox, err, btn);
}

function passwordForm() {
  const cur = h('input', { type: 'password', autocomplete: 'current-password', required: true });
  const next = h('input', { type: 'password', autocomplete: 'new-password', required: true, minlength: 6 });
  const msg = h('p', { class: 'hint', hidden: true });
  const btn = h('button', { type: 'submit' }, 'Change password');
  return h('form', { class: 'card', onsubmit: async (e) => {
    e.preventDefault();
    btn.disabled = true; msg.hidden = true; msg.className = 'hint';
    try {
      await auth({ action: 'change_password', member_no: home.member.member_no, password: cur.value, new_password: next.value });
      msg.textContent = 'Password changed.';
      cur.value = ''; next.value = '';
    } catch (ex) { msg.textContent = ex.message; msg.className = 'error'; }
    msg.hidden = false; btn.disabled = false;
  } }, h('h2', null, 'Change password'), h('label', null, 'Current password'), cur, h('label', null, 'New password'), next, msg, btn);
}

// ---------- start ----------
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
window.addEventListener('online', () => { if (session && offline) loadHome(); });
if (session) loadHome(); else renderAuth('signin');
