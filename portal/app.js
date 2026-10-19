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
// The browser's append, prepend and replaceChildren turn a null argument into
// the text "null". Pages pass null for parts that are not shown, so drop those.
for (const method of ['append', 'prepend', 'replaceChildren']) {
  const native = Element.prototype[method];
  Element.prototype[method] = function (...nodes) {
    return native.apply(this, nodes.filter((n) => n != null && n !== false));
  };
}

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
const auth = (body) => call('/functions/v1/member-auth', { org: ORG, web: true, ...body });

// Shows a picture full-screen. The src is set as a property, never as markup.
function lightbox(src) {
  const box = h('div', { style: 'position:fixed;inset:0;z-index:50;background:rgba(0,0,0,.88);display:flex;align-items:center;justify-content:center;padding:12px', onclick: () => box.remove() });
  const img = document.createElement('img');
  img.src = src; img.alt = '';
  img.style.cssText = 'max-width:100%;max-height:100%';
  box.append(img);
  document.body.append(box);
}

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
      ? 'Enter your member ID and registered phone number, then choose a password.'
      : null),
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
      h('b', null, 'Add to Home Screen'), h('br'),
      'In Safari, tap Share, then Add to Home Screen.');
  }
  return h('div', { class: 'notice' }, 'Add to home screen from your browser menu.');
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
  ['home', '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/></svg>', 'Home'],
  ['pay', '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10h18M7 15h4"/></svg>', 'Payments'],
  ['community', '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M3 20c.6-3.6 3-5.2 6-5.2s5.4 1.6 6 5.2"/><circle cx="17" cy="9" r="2.4"/><path d="M17 14.2c2.2.2 3.6 1.6 4 4.3"/></svg>', 'Community'],
  ['chat', '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 01-11.7 7L4 20l1.1-4.6A8 8 0 1121 12z"/></svg>', 'Chats'],
  ['me', '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-5.5 8-5.5s6.5 1.5 8 5.5"/></svg>', 'Me'],
];

// The icons are the fixed SVG strings in TABS above, never user text.
function tabIcon(svg) {
  const b = h('b');
  b.innerHTML = svg;
  return b;
}

function renderTabs() {
  tabsEl.hidden = false;
  tabsEl.replaceChildren(...TABS.map(([id, icon, label]) =>
    h('button', { class: id === tab ? 'on' : '', onclick: () => show(id) }, tabIcon(icon), label)));
}

function show(id) {
  stopPolling();
  tab = id;
  renderTabs();
  const view = { home: viewHome, pay: viewPay, community: viewCommunity, chat: viewChannels, me: viewMe }[id]();
  app.replaceChildren(...(offline ? [h('div', { class: 'notice' }, 'Offline. Showing saved records.')] : []), view);
  window.scrollTo(0, 0);
}

function chips(roles) {
  const list = roles && roles.length ? roles : ['Member'];
  return h('div', { class: 'chips' }, list.slice(0, 4).map((r, i) => h('span', { class: 'chip' + (i === 0 ? ' lead' : '') }, r)),
    list.length > 4 ? h('span', { class: 'chip' }, '+' + (list.length - 4) + ' more') : null);
}

const initialsOf = (name) => String(name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('');

function idCard() {
  const m = home.member;
  const photo = h('div', { class: 'ph' }, initialsOf(m.name));
  rpc('avatar_get', { token: session.token, as_name: null }).then((r) => {
    if (r && r.photo) photo.replaceChildren(h('img', { src: r.photo, alt: '' }));
  }).catch(() => {});
  return h('div', { class: 'idcard card', style: 'padding:0' },
    h('div', { class: 'top' }, h('img', { src: 'logo.png', alt: '' }),
      h('div', null, h('b', null, session.org_name || 'June Borns Family'), h('small', null, 'MEMBERSHIP CARD')),
      h('span', { class: 'st' }, 'Active')),
    h('div', { class: 'body' },
      h('div', { class: 'who' },
        h('div', { class: 'nm' }, m.name),
        home.whatsapp_name ? h('div', { class: 'sub' }, '(' + home.whatsapp_name + ')') : null,
        h('div', { class: 'no' }, m.member_no),
        h('div', { class: 'sub' }, 'Zone: ' + (realZones(m).join(', ') || 'Not chosen yet'))),
      photo,
      chips(home.roles)),
    h('div', { class: 'ft' }, h('span', null, 'Member since ' + day(m.joined)), h('span', null, 'Official ID')));
}

const ACT_ICON = {
  pay: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10h18M7 15h4"/></svg>',
  chat: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 01-11.7 7L4 20l1.1-4.6A8 8 0 1121 12z"/></svg>',
  vote: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V6l4-3 4 3v5M10 15h4"/></svg>',
  people: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M3 20c.6-3.6 3-5.2 6-5.2s5.4 1.6 6 5.2"/><circle cx="17" cy="9" r="2.4"/><path d="M17 14.2c2.2.2 3.6 1.6 4 4.3"/></svg>',
};

// The icons are the fixed SVG strings above, never user text.
function actButton(icon, label, fn) {
  const b = h('button', { class: 'act', onclick: fn });
  b.innerHTML = ACT_ICON[icon];
  b.append(label);
  return b;
}

function duesCard(d) {
  const card = h('div', { class: 'card dues' });
  const owes = d.outstanding > 0;
  card.append(h('div', { class: 'row2' }, h('span', { class: 'cap' }, d.name),
    h('span', { class: 'pill' + (owes ? ' w' : '') }, owes ? `${d.months_behind} month${d.months_behind === 1 ? '' : 's'} behind` : 'Up to date')));
  card.append(h('div', { class: 'big ' + (owes ? 'owed' : 'clear') }, owes ? money(d.outstanding) : 'All clear'));
  if (owes) card.append(h('div', { class: 'sub' }, 'Owed since ' + monthName(d.next_unpaid)));
  const pct = d.expected > 0 ? Math.max(0, Math.min(100, Math.round((d.paid / d.expected) * 100))) : 100;
  card.append(h('div', { class: 'bar' }, h('i', { style: 'width:' + pct + '%' })),
    h('div', { class: 'two' }, h('span', null, 'Paid ', h('b', null, money(d.paid))), h('span', null, 'Expected ', h('b', null, money(d.expected)))));
  return card;
}

function viewHome() {
  const out = h('div');
  out.append(idCard());
  for (const d of home.dues || []) out.append(duesCard(d));
  out.append(h('div', { class: 'acts' },
    actButton('pay', 'Pay', () => show('pay')),
    actButton('chat', 'Chats', () => show('chat')),
    actButton('people', 'Community', () => show('community')),
    actButton('vote', 'Elections', openElections)));
  if (needsZone()) {
    out.append(h('div', { class: 'notice' }, h('b', null, 'Choose your zone'), h('br'),
      'This can be done once, under Me.',
      h('div', null, h('button', { class: 'small', onclick: () => show('me') }, 'Choose my zone'))));
  }
  if (!offline) out.append(payReminder());
  for (const w of home.warnings || []) {
    out.append(h('div', { class: 'notice' }, h('b', null, 'Notice from the Disciplinary Committee'), h('br'), w.details,
      h('div', { class: 'sub' }, day(w.at))));
  }
  const notes = home.announcements || [];
  const officer = home.officer || (home.roles || []).length;
  if (notes.length || officer) {
    const box = h('div', { class: 'card notes' }, h('div', { class: 'cap' }, 'Notices'));
    for (const a of notes) box.append(h('div', { class: 'note' }, h('span', { class: 'dot' }), h('div', null, a)));
    if (officer) {
      box.append(h('div', { class: 'note' }, h('span', { class: 'dot' }),
        h('div', null, 'Executive tools are in the ', h('a', { href: 'https://jbf-app.onrender.com', target: '_blank', rel: 'noopener' }, 'full app'), '.')));
    }
    out.append(box);
  }
  if (home.updated) out.append(h('p', { class: 'hint' }, 'Updated ' + new Date(home.updated).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' })));
  return out;
}

// A member from the founding list whose only zone is the holding zone.
function needsZone() {
  return home.self_edit && !home.zones_locked && !(home.zone_ids || []).some((z) => (home.zone_options || []).some((o) => o.id === z));
}

// ---------- payment requests ----------
// The Treasury or the Welfare Committee asks members to pay; the member
// says how they paid and a treasurer confirms it, which writes a receipt.
const officeName = (o) => (o === 'welfare' ? 'Welfare Committee' : 'Treasury');

function askLine(r) {
  return [r.amount != null ? money(r.amount) : r.minimum != null ? 'from ' + money(r.minimum) : '', r.type, r.period ? monthName(r.period) : '',
    r.due_on ? 'due ' + day(r.due_on) : ''].filter(Boolean).join(' · ');
}

// Home: a reminder when something asked of the member is not yet reported.
function payReminder() {
  const box = h('div');
  rpc('pay_requests_mine', { token: session.token }).then((list) => {
    const open = list.filter((r) => !r.closed && (!r.mine || r.mine.status === 'rejected'));
    if (!open.length) return;
    box.append(h('div', { class: 'notice' }, h('b', null, open.length === 1 ? open[0].title : open.length + ' payments asked of you'), h('br'),
      'Pay, then report it.',
      h('div', null, h('button', { class: 'small', onclick: () => show('pay') }, 'Open'))));
  }).catch(() => {});
  return box;
}

function payRequests() {
  const box = h('div');
  const load = () => rpc('pay_requests_mine', { token: session.token }).then((list) => {
    box.replaceChildren(...(list.length ? [h('h2', null, 'Payments asked of me')] : []), ...list.map((r) => requestCard(r, load)));
  }).catch((ex) => { if (ex.expired) signOutLocal(); });
  load();
  return box;
}

function requestCard(r, reload) {
  const mine = r.mine;
  const card = h('div', { class: 'card' },
    h('div', { class: 'top' }, h('b', null, r.title)),
    h('div', { class: 'sub' }, 'From the ' + officeName(r.office)),
    h('p', null, askLine(r)),
    r.details ? h('p', null, r.details) : null,
    r.pay_to ? h('div', { class: 'notice' }, h('b', null, 'How to pay: '), r.pay_to) : null);
  if (mine && mine.status === 'pending') {
    card.append(h('p', { class: 'hint' }, `Reported ${money(mine.amount)}${methods[mine.method] || mine.method ? ' by ' + (methods[mine.method] || mine.method) : ''}. Awaiting confirmation.`));
    return card;
  }
  if (mine && mine.status === 'confirmed') {
    card.append(h('p', { class: 'clear' }, 'Confirmed. Receipt ' + mine.receipt_no));
    return card;
  }
  if (mine && mine.status === 'rejected') {
    card.append(h('p', { class: 'error' }, 'Not accepted: ' + (mine.decision_note || '')));
  }
  if (r.closed) { card.append(h('p', { class: 'hint' }, 'Closed.')); return card; }
  const open = h('button', { onclick: () => { open.replaceWith(paidForm(r, reload)); } }, mine ? 'Report again' : 'I have paid');
  card.append(open);
  return card;
}

function paidForm(r, reload) {
  const amount = h('input', { type: 'text', inputmode: 'decimal', value: r.amount != null ? (r.amount / 100).toFixed(2) : '' });
  const method = h('select', null, ...['momo', 'bank', 'cash'].map((m) => h('option', { value: m }, methods[m])));
  const refLabel = h('label', null, 'Transaction ID (from your Mobile Money or bank message)');
  const ref = h('input', { type: 'text', maxlength: 80 });
  method.addEventListener('change', () => {
    refLabel.textContent = method.value === 'cash' ? 'Who you gave it to (optional)' : 'Transaction ID (from your Mobile Money or bank message)';
  });
  const today = new Date().toISOString().slice(0, 10);
  const paidOn = h('input', { type: 'date', value: today, max: today });
  const note = h('input', { type: 'text', maxlength: 200 });
  const err = h('p', { class: 'error', role: 'alert', hidden: true });
  const btn = h('button', { type: 'submit' }, 'Send');
  return h('form', { onsubmit: async (e) => {
    e.preventDefault();
    err.hidden = true;
    const t = amount.value.trim().replace(/,/g, '');
    const m = /^(\d+)(?:\.(\d{1,2}))?$/.exec(t);
    const pesewas = m ? Number(m[1]) * 100 + Number((m[2] || '').padEnd(2, '0')) : 0;
    if (!pesewas) { err.textContent = 'Enter the amount you paid.'; err.hidden = false; return; }
    if (method.value !== 'cash' && !ref.value.trim()) {
      err.textContent = 'Enter the transaction ID from your Mobile Money or bank message.'; err.hidden = false; return;
    }
    btn.disabled = true;
    try {
      await rpc('pay_claim_submit', { token: session.token, request: r.id, amount: pesewas, method: method.value,
        reference: ref.value.trim() || null, paid_on: paidOn.value || null, note: note.value.trim() || null });
      await reload();
    } catch (ex) {
      if (ex.expired) return signOutLocal();
      err.textContent = ex.message; err.hidden = false; btn.disabled = false;
    }
  } },
    h('label', null, 'Amount paid (GHS)'), amount,
    h('label', null, 'How you paid'), method,
    refLabel, ref,
    h('label', null, 'Date paid'), paidOn,
    h('label', null, 'Note (optional)'), note,
    err, btn);
}

// Pay without being asked: pick what for (and the month), then report the
// payment on the standing request the cloud makes for it.
function selfPay() {
  const box = h('div', { class: 'card' });
  const start = h('button', { onclick: async () => {
    start.disabled = true;
    try {
      const [o, mo] = await Promise.all([
        rpc('pay_self_options', { token: session.token }),
        call('/functions/v1/momo', { action: 'enabled' }).catch(() => ({ enabled: false })),
      ]);
      start.replaceWith(selfPayForm(o, box, !!mo.enabled));
    } catch (ex) {
      if (ex.expired) return signOutLocal();
      start.disabled = false;
      box.append(h('p', { class: 'error' }, ex.message));
    }
  } }, 'Pay my dues');
  box.append(h('h2', null, 'Pay my dues'),
    h('p', { class: 'hint' }, 'Pay by Mobile Money, then report it for confirmation and a receipt.'), start);
  return box;
}

function selfPayForm(o, box, momoOn) {
  const types = o.types || [];
  const type = h('select', null, ...types.map((t) => h('option', { value: t.id }, t.name)));
  const monthly = types.find((t) => t.frequency === 'monthly');
  if (monthly) type.value = monthly.id;
  const now = new Date();
  const monthOpts = [];
  for (let i = -2; i < 12; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0');
    monthOpts.push(h('option', { value: key }, monthName(key)));
  }
  const month = h('select', null, ...monthOpts);
  month.value = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0');
  const monthLabel = h('label', null, 'Month');
  const sync = () => {
    const t = types.find((x) => x.id === type.value);
    const isMonthly = t && t.frequency === 'monthly';
    month.hidden = !isMonthly; monthLabel.hidden = !isMonthly;
  };
  type.addEventListener('change', sync);
  sync();
  const err = h('p', { class: 'error', role: 'alert', hidden: true });
  const amount = h('input', { type: 'text', inputmode: 'decimal' });
  const phone = h('input', { type: 'tel', placeholder: '024 123 4567', autocomplete: 'tel' });
  const fillAmount = () => {
    const t = types.find((x) => x.id === type.value);
    amount.value = t && t.amount != null ? (t.amount / 100).toFixed(2) : '';
  };
  type.addEventListener('change', fillAmount);
  fillAmount();
  const period = () => {
    const t = types.find((x) => x.id === type.value);
    return t && t.frequency === 'monthly' ? month.value : null;
  };
  const showErr = (m, btns) => { err.textContent = m; err.hidden = false; btns.forEach((b) => { b.disabled = false; }); };

  // Pay by hand, then report it.
  const report = h('button', { type: 'button', class: momoOn ? 'secondary' : '' }, momoOn ? 'Paid already' : 'I have paid');
  report.addEventListener('click', async () => {
    err.hidden = true; report.disabled = true; pay.disabled = true;
    try {
      const r = await rpc('pay_self_request', { token: session.token, type_id: type.value, period: period() });
      const st = r.mine && r.mine.status;
      if (st === 'pending' || st === 'confirmed') {
        return showErr(st === 'pending' ? 'You already told the Treasurer about this one. It is waiting to be confirmed.' : 'This payment is already confirmed.', [report, pay]);
      }
      box.replaceWith(requestCard(r, () => show('pay')));
    } catch (ex) {
      if (ex.expired) return signOutLocal();
      showErr(ex.message, [report, pay]);
    }
  });

  // Pay by MTN MoMo right here: MTN asks for approval on the phone.
  const pay = h('button', { type: 'button' }, 'Pay with MoMo');
  pay.addEventListener('click', async () => {
    err.hidden = true;
    const m = /^(\d+)(?:\.(\d{1,2}))?$/.exec(amount.value.trim().replace(/,/g, ''));
    const pesewas = m ? Number(m[1]) * 100 + Number((m[2] || '').padEnd(2, '0')) : 0;
    if (!pesewas) return showErr('Enter the amount you are paying.', [report, pay]);
    pay.disabled = true; report.disabled = true;
    try {
      const r = await call('/functions/v1/momo', { action: 'start', token: session.token, type_id: type.value,
        period: period(), amount: pesewas, phone: phone.value.trim() });
      waitForMoMo(box, r.id);
    } catch (ex) {
      if (ex.expired) return signOutLocal();
      showErr(ex.message, [report, pay]);
    }
  });

  return h('form', { onsubmit: (e) => e.preventDefault() },
    !momoOn && (o.pay_to ? h('div', { class: 'notice' }, h('b', null, 'Pay to: '), o.pay_to)
      : h('p', { class: 'hint' }, 'The Treasurer has not yet said where to pay. Ask them for the Mobile Money number, pay, then come back to tell them.')),
    h('label', null, 'What are you paying for?'), type, monthLabel, month,
    momoOn ? h('div', null, h('label', null, 'Amount (GHS)'), amount,
      h('label', null, 'Your MTN Mobile Money number'), phone) : null,
    err, momoOn ? pay : null, report);
}

// After MTN was asked: wait for the approval, then show the receipt.
function waitForMoMo(box, id) {
  const card = h('div', { class: 'card' }, h('h2', null, 'Approve on your phone'),
    h('p', null, 'MTN is asking for your approval. Check your phone and enter your Mobile Money PIN to pay.'));
  box.replaceWith(card);
  let polls = 0;
  const finish = (title, text, ok) => {
    clearInterval(timer);
    card.replaceChildren(h('h2', null, title), h('p', { class: ok ? 'clear' : 'error' }, text),
      h('button', { onclick: () => show('pay') }, 'Close'));
    if (ok) rpc('member_home', { token: session.token }).then((x) => { home = x; }).catch(() => {});
  };
  const timer = setInterval(async () => {
    try {
      const r = await call('/functions/v1/momo', { action: 'status', token: session.token, id });
      polls++;
      if (r.status === 'successful') return finish('Payment received', 'Thank you. Your receipt is ' + r.receipt_no + '.', true);
      if (r.status === 'failed') return finish('Not paid', r.reason || 'The payment did not go through.', false);
      if (polls >= 45) finish('Not confirmed yet', 'We have not heard back from MTN yet. If you approved the payment, it will show on your Payments soon.', false);
    } catch (ex) {
      if (ex.expired) { clearInterval(timer); signOutLocal(); }
    }
  }, 4000);
}

function viewPay() {
  const out = h('div', null, selfPay(), payRequests());
  const card = h('div', { class: 'card' }, h('h2', null, 'Payments'));
  out.append(card);
  const pays = home.payments || [];
  if (!pays.length) card.append(h('p', { class: 'hint' }, 'No payments yet.'));
  for (const p of pays) {
    card.append(h('div', { class: 'pay' },
      h('div', { class: 'top' }, h('span', null, p.type || 'Payment'), h('span', null, money(p.amount))),
      h('div', { class: 'sub' }, [day(p.paid_on), p.period ? 'for ' + monthName(p.period) : '', methods[p.method] || p.method, p.receipt_no].filter(Boolean).join(' · '))));
  }
  return out;
}

function viewCommunity() {
  const out = h('div');
  const events = home.events || [];
  const ev = h('div', { class: 'card' }, h('h2', null, 'Events and meetings'));
  if (!events.length) ev.append(h('p', { class: 'hint' }, 'Nothing scheduled.'));
  for (const e of events) {
    ev.append(h('div', { class: 'pay' }, h('div', { class: 'top' }, h('span', null, e.name), h('span', null, day(e.date))),
      h('div', { class: 'sub' }, [e.kind === 'meeting' ? 'Meeting' : 'Event', e.venue].filter(Boolean).join(' · ')),
      e.description ? h('div', { class: 'sub' }, e.description) : null));
  }
  out.append(ev);
  out.append(welfareStandingCard());
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
  out.append(directoryCard());
  return out;
}

// Welfare is by choice: join or leave here, or by paying welfare dues or a
// welfare contribution. Three payments missed in a row end the benefits.
function welfareStandingCard() {
  const w = home.welfare_standing || { status: 'none' };
  const card = h('div', { class: 'card' }, h('h2', null, 'Welfare membership'));
  const err = h('p', { class: 'err', hidden: true });
  let text;
  if (w.status === 'member') {
    text = 'You are a welfare member' + (w.since ? ' since ' + day(w.since) : '') + '. Missing 3 payments in a row ends your welfare benefits.';
    if (w.dues_behind || w.rounds_missed) text += ` Months of dues missed: ${w.dues_behind}. Welfare contributions missed: ${w.rounds_missed}.`;
  } else if (w.status === 'disqualified') {
    text = (w.note || 'You missed 3 payments in a row.') + ' Welfare benefits have stopped. Speak to the Welfare Committee to be reinstated.';
  } else {
    text = 'You are not in welfare. Welfare is by choice: join here, or pay welfare dues or a welfare contribution to be covered.';
  }
  card.append(h('p', null, text), err);
  if (w.status !== 'disqualified') {
    const join = w.status !== 'member';
    const btn = h('button', { class: join ? '' : 'secondary', onclick: async () => {
      btn.disabled = true;
      try {
        await rpc(join ? 'welfare_join' : 'welfare_leave', { token: session.token });
        await loadHome();
      } catch (ex) { err.textContent = ex.message; err.hidden = false; btn.disabled = false; }
    } }, join ? 'Join welfare' : 'Leave welfare');
    card.append(btn);
  }
  return card;
}

// Members can find the people in their own zones by name or username.
function directoryCard() {
  const people = home.directory || [];
  const list = h('div');
  const draw = (q) => {
    q = q.trim().toLowerCase();
    const shown = people.filter((p) => !q || (p.name || '').toLowerCase().includes(q) || (p.whatsapp_name || '').toLowerCase().includes(q));
    list.replaceChildren(...shown.slice(0, 100).map((p) => h('div', { class: 'row' },
      h('span', null, p.name, p.whatsapp_name ? h('div', { class: 'sub' }, '(' + p.whatsapp_name + ')') : null),
      h('span', { class: 'sub' }, realZones(p).join(', ')))),
    shown.length > 100 ? h('p', { class: 'hint' }, `Showing 100 of ${shown.length}. Type more of the name to narrow it down.`) : null,
    shown.length ? null : h('p', { class: 'hint' }, people.length ? 'No member found.' : 'Choose your zone to see its members.'));
  };
  draw('');
  return h('div', { class: 'card' }, h('h2', null, `Members in my zones (${people.length})`),
    h('input', { type: 'search', placeholder: 'Search by name or username', oninput: (e) => draw(e.target.value) }), list);
}

// ---------- chats ----------
function viewChannels() {
  const box = h('div', null, h('p', { class: 'hint' }, 'Loading...'));
  rpc('chat_channels', { token: session.token, as_name: null }).then((chans) => {
    box.replaceChildren(h('h2', null, 'Chats'), ...chans.map((c) =>
      h('button', { class: 'chan', onclick: () => openChat(c) }, h('b', null, c.name || 'Chat'), h('div', { class: 'sub' }, c.last || 'No messages yet'))),
      chans.length ? null : h('p', { class: 'hint' }, 'No chats yet.'));
  }).catch((ex) => {
    if (ex.expired) return signOutLocal();
    box.replaceChildren(h('p', { class: 'error' }, ex.message));
  });
  return box;
}

const STICKERS = ['👍', '🙏', '❤️', '😂', '😍', '😊', '🎉', '👏', '🙌', '💪', '🤝', '😢', '😮', '😎', '🥳', '🔥', '✅', '🙂', '🤗', '😇', '🌹', '🎂', '🕊️', '🇬🇭'];
const MAX_FILE = 3000000;
const NAME_COLORS = ['#1f7a5a', '#b5651d', '#6a4c93', '#c0392b', '#2471a3', '#8e6b00', '#117a65', '#ad1457'];
const nameColor = (n) => NAME_COLORS[[...String(n)].reduce((a, c) => a + c.charCodeAt(0), 0) % NAME_COLORS.length];
const quoteText = (kind, body) => kind === 'image' ? '📷 ' + (body || 'Photo') : kind === 'file' ? '📄 ' + (body || 'Document') : body;
const sizeText = (n) => n >= 1000000 ? (n / 1000000).toFixed(1) + ' MB' : Math.ceil(n / 1000) + ' KB';

// A picture shrunk to [max] pixels, as a data URL.
function shrink(file, max, quality) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      const k = Math.min(1, max / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      resolve(c.toDataURL('image/jpeg', quality));
    };
    img.onerror = () => reject(new Error('That is not a picture.'));
    img.src = url;
  });
}
const readDataUrl = (file) => new Promise((resolve, reject) => {
  const r = new FileReader();
  r.onload = () => resolve(r.result);
  r.onerror = () => reject(new Error('Could not read that file.'));
  r.readAsDataURL(file);
});
const base64Of = (dataUrl) => dataUrl.slice(dataUrl.indexOf(',') + 1);

const ICON = {
  back: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>',
  me: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/></svg>',
  reply: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M9 14L4 9l5-5"/><path d="M4 9h10a6 6 0 016 6v3"/></svg>',
  tick: '<svg class="tick" width="16" height="12" viewBox="0 0 20 12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 6.5l3.5 3.5L11 2"/><path d="M8 8.5l1.5 1.5L16 2"/></svg>',
  smile: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8.5 14.5c1 1.2 2.2 1.8 3.5 1.8s2.5-.6 3.5-1.8"/><path d="M9 9.5h.01M15 9.5h.01" stroke-width="2.6"/></svg>',
  clip: '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11l-8.6 8.6a5 5 0 01-7.1-7.1l9-9a3.4 3.4 0 014.8 4.8l-9 9a1.8 1.8 0 01-2.5-2.5l8.2-8.2"/></svg>',
  photo: '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="3"/><circle cx="9" cy="10.5" r="1.6"/><path d="M21 16l-5-5-8 8"/></svg>',
  send: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M3.4 20.4l17.5-7.5a1 1 0 000-1.8L3.4 3.6a.8.8 0 00-1.1.9L3.5 10l9 2-9 2-1.2 5.5a.8.8 0 001.1.9z"/></svg>',
  down: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v11"/><path d="M7 11l5 5 5-5"/><path d="M5 20h14"/></svg>',
  x: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
};
const raw = (html) => { const t = document.createElement('template'); t.innerHTML = html; return t.content.firstChild; };
const fileKind = (name) => { const e = String(name).split('.').pop().toUpperCase(); return e.length <= 4 ? e : 'FILE'; };
const dayLabel = (iso) => {
  const d = new Date(iso); const t = new Date();
  const same = (a, b) => a.toDateString() === b.toDateString();
  const y = new Date(t); y.setDate(t.getDate() - 1);
  return same(d, t) ? 'Today' : same(d, y) ? 'Yesterday' : d.toLocaleDateString([], { day: 'numeric', month: 'short', year: 'numeric' });
};

function openChat(chan) {
  stopPolling();
  const list = h('div', { class: 'c-msgs' });
  let last = null;
  let replyTo = null;
  let prev = null;
  let prevDay = null;
  let avatars = {};
  const seen = new Set();
  const files = new Map();
  const fetchFile = (f) => {
    if (!files.has(f.id)) {
      files.set(f.id, rpc('chat_file', { token: session.token, channel: chan.id, file_id: f.id, as_name: null })
        .then((r) => {
          if (!/^[A-Za-z0-9+/=\s]*$/.test(r.data || '')) throw new Error('That file is not available.');
          return 'data:' + (r.mime || 'application/octet-stream') + ';base64,' + r.data;
        })
        .catch((ex) => { files.delete(f.id); throw ex; }));
    }
    return files.get(f.id);
  };
  const avatar = (m) => {
    const src = avatars[m.author_key];
    if (src) return h('img', { class: 'c-av', src, alt: '' });
    const letters = String(m.author || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('');
    return h('div', { class: 'c-av', style: '--c:' + nameColor(m.author) }, letters);
  };
  const quoteBlock = (q) => h('div', { class: 'c-q', style: '--c:' + nameColor(q.author) },
    h('b', null, q.author), h('span', null, quoteText(q.kind, q.body)));
  const bar = h('div', { class: 'c-replybar', hidden: true });
  const setReply = (m) => {
    replyTo = m;
    bar.hidden = !m;
    bar.replaceChildren();
    if (!m) return;
    const x = h('button', { type: 'button', class: 'x', 'aria-label': 'Cancel reply', onclick: () => setReply(null) });
    x.append(raw(ICON.x));
    bar.append(quoteBlock({ author: m.mine ? 'You' : m.author, kind: m.kind, body: m.body }), x);
    input.focus();
  };
  const content = (m) => {
    const f = m.file;
    if (m.kind === 'sticker') return h('div', { class: 'c-stk' }, m.body);
    if (m.kind === 'image' && f) {
      const img = h('img', { class: 'c-img', alt: f.name });
      fetchFile(f).then((u) => { img.src = u; img.style.cursor = 'zoom-in'; img.onclick = () => lightbox(u); }).catch(() => img.replaceWith(h('i', null, 'Picture not available')));
      return h('div', null, img, m.body ? h('div', null, m.body) : null);
    }
    if (m.kind === 'file' && f) {
      const dl = h('div', { class: 'dl' }); dl.append(raw(ICON.down));
      return h('div', null, h('button', { type: 'button', class: 'c-file', onclick: async () => {
        try {
          const u = await fetchFile(f);
          const a = h('a', { href: u, download: f.name }); document.body.append(a); a.click(); a.remove();
        } catch (ex) { alert(ex.message); }
      } }, h('div', { class: 'ic' }, fileKind(f.name)), h('div', { class: 'nm' }, h('b', null, f.name), h('span', null, sizeText(f.size))), dl),
      m.body ? h('div', null, m.body) : null);
    }
    return h('div', null, m.body);
  };
  const add = (msgs) => {
    for (const m of msgs) {
      if (seen.has(m.id)) continue;
      seen.add(m.id);
      last = m.at;
      const day = dayLabel(m.at);
      if (day !== prevDay) { list.append(h('div', { class: 'c-day' }, day)); prevDay = day; prev = null; }
      const first = !prev || prev.author_key !== m.author_key || prev.author !== m.author;
      prev = m;
      const col = '--c:' + nameColor(m.author);
      const sticker = m.kind === 'sticker';
      const rep = chan.post ? h('button', { type: 'button', class: 'rep', onclick: () => setReply(m) }) : null;
      if (rep) rep.innerHTML = ICON.reply + 'Reply';
      const foot = h('div', { class: 'c-foot' }, rep, new Date(m.at).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }));
      if (m.mine) foot.append(raw(ICON.tick));
      const who = !m.mine && first ? h('div', { class: 'c-who' }, h('b', null, m.author),
        ...(m.zones || []).map((z) => h('span', { class: 'c-zone' }, z))) : null;
      const bubble = sticker
        ? h('div', null, content(m), h('div', { class: 'c-foot' }, new Date(m.at).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })))
        : h('div', { class: 'c-b' }, who, m.reply ? quoteBlock(m.reply) : null, content(m), foot);
      if (chan.post) {
        let x0 = null;
        bubble.addEventListener('dblclick', () => setReply(m));
        bubble.addEventListener('touchstart', (e) => { x0 = e.touches[0].clientX; }, { passive: true });
        bubble.addEventListener('touchend', (e) => { if (x0 != null && e.changedTouches[0].clientX - x0 > 70) setReply(m); x0 = null; });
      }
      list.append(h('div', { class: 'c-r' + (m.mine ? ' mine' : '') + (first ? ' first' : '') + (sticker ? ' c-stkrow' : ''), style: col },
        m.mine ? null : (first ? avatar(m) : h('div', { class: 'c-av gap' })), bubble));
    }
    if (msgs.length) window.scrollTo(0, document.body.scrollHeight);
  };
  const loadAvatars = async () => {
    try { avatars = await rpc('chat_avatars', { token: session.token, channel: chan.id, as_name: null }); } catch (_) { /* initials show */ }
  };
  const load = async () => {
    try { add(await rpc('chat_messages', { token: session.token, channel: chan.id, after: last, as_name: null })); }
    catch (ex) { if (ex.expired) signOutLocal(); }
  };
  const input = h('input', { placeholder: 'Write a message', maxlength: 1000, autocomplete: 'off' });
  const post = async (extra) => {
    const body = (extra.body !== undefined ? extra.body : input.value.trim());
    if (!body && !extra.file_data) return;
    try {
      await rpc('chat_post', { token: session.token, channel: chan.id, body, reply_to: replyTo ? replyTo.id : null, kind: extra.kind || 'text', file_name: extra.file_name || null, file_mime: extra.file_mime || null, file_data: extra.file_data || null, as_name: null });
      input.value = ''; setReply(null); await load();
    } catch (ex) { alert(ex.message); }
  };
  const send = (e) => { e.preventDefault(); post({}); };
  const picker = (accept, onFile) => h('input', { type: 'file', accept, hidden: true, onchange: async (e) => {
    const f = e.target.files[0]; e.target.value = '';
    if (!f) return;
    try { await onFile(f); } catch (ex) { alert(ex.message); }
  } });
  const photoIn = picker('image/*', async (f) => {
    const u = await shrink(f, 1280, 0.75);
    if (u.length > 4000000) throw new Error('That picture is too big.');
    await post({ kind: 'image', file_name: f.name.replace(/\.\w+$/, '') + '.jpg', file_mime: 'image/jpeg', file_data: base64Of(u), body: input.value.trim() });
  });
  const docIn = picker('', async (f) => {
    if (f.size > MAX_FILE) throw new Error('That file is too big. The most you can send is 3 MB.');
    const u = await readDataUrl(f);
    const mime = f.type || 'application/octet-stream';
    await post({ kind: mime.startsWith('image/') ? 'image' : 'file', file_name: f.name, file_mime: mime, file_data: base64Of(u), body: input.value.trim() });
  });
  const avIn = picker('image/*', async (f) => {
    const u = await shrink(f, 200, 0.7);
    await rpc('avatar_set', { token: session.token, photo: u, as_name: null });
    await loadAvatars(); alert('Done. Your picture will show in the chats.');
  });
  const grid = h('div', { class: 'g' }, STICKERS.map((s) =>
    h('button', { type: 'button', onclick: () => { tray.hidden = true; post({ kind: 'sticker', body: s }); } }, s)));
  const tray = h('div', { class: 'c-tray', hidden: true }, h('h3', null, 'Stickers'), grid);
  const ib = (label, icon, onclick) => { const b = h('button', { type: 'button', class: 'c-ib', 'aria-label': label, onclick }); b.innerHTML = icon; return b; };
  const goBtn = h('button', { type: 'submit', class: 'c-go', 'aria-label': 'Send' }); goBtn.innerHTML = ICON.send;
  const back = h('button', { type: 'button', class: 'back', 'aria-label': 'Back to all chats', onclick: () => show('chat') }); back.innerHTML = ICON.back;
  const meBtn = h('button', { type: 'button', class: 'me', 'aria-label': 'My chat picture', onclick: () => avIn.click() }); meBtn.innerHTML = ICON.me;
  const initials = String(chan.name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('');
  app.replaceChildren(
    h('div', { class: 'c-head' }, back, h('div', { class: 'c-crest' }, initials),
      h('div', { class: 't' }, h('b', null, chan.name), h('span', null, chan.post ? 'Tap and hold to reply' : 'Read only')), meBtn),
    list,
    h('div', { class: 'c-composer' }, chan.post ? [bar, tray, photoIn, docIn, avIn,
      h('form', { class: 'c-bar', onsubmit: send },
        h('div', { class: 'c-field' }, ib('Stickers', ICON.smile, () => { tray.hidden = !tray.hidden; }), input,
          ib('Attach a document', ICON.clip, () => docIn.click()), ib('Send a photo', ICON.photo, () => photoIn.click())), goBtn)]
      : [avIn, h('p', { class: 'hint', style: 'margin:6px 4px' }, 'Only officers can post here.')]));
  loadAvatars().then(load);
  pollTimer = setInterval(load, 8000);
}

// ---------- elections ----------
// Every check (who may vote, one vote each, secrecy, counting) happens in the
// cloud. This page only shows the ballot and sends the choices.
const electionError = (ex) => ex.expired ? 'Please sign in again.' : ex.message;

function photoOrInitials(c, size) {
  if (c.photo) return h('img', { class: 'cphoto', src: c.photo, alt: '', width: size, height: size });
  const letters = String(c.name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('');
  return h('div', { class: 'cphoto init', style: `width:${size}px;height:${size}px` }, letters);
}

async function openElections() {
  stopPolling();
  tabsEl.hidden = false;
  const box = h('div', null, h('button', { class: 'link', onclick: () => show('home') }, '‹ Back'),
    h('h2', null, 'Elections'), h('p', { class: 'hint' }, 'Loading...'));
  app.replaceChildren(box);
  try {
    const [r, notices] = await Promise.all([rpc('election_list', { token: session.token }),
      rpc('office_notices', { token: session.token, committee: 'ec' }).catch(() => [])]);
    box.lastChild.remove();
    for (const n of notices) {
      box.append(h('div', { class: 'notice' }, h('b', null, '📣 ' + (n.title || 'Notice')), h('div', null, n.body),
        h('div', { class: 'sub' }, `From the ${n.from || 'Electoral Commission'} · ` + new Date(n.at).toLocaleDateString('en-GB', { dateStyle: 'medium' }))));
    }
    if (!r.elections.length) box.append(h('p', { class: 'hint' }, 'No elections.'));
    for (const e of r.elections) {
      const state = e.status === 'open' ? (e.voted_all ? 'You have voted' : e.can_vote ? 'Vote now' : 'Open')
        : e.status === 'closed' ? 'See results' : 'View';
      box.append(h('div', { class: 'card' }, h('h2', null, e.title),
        h('div', { class: 'sub' }, e.status === 'open' ? 'Closes ' + new Date(e.closes_at).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' })
          : e.status === 'closed' ? 'Voting closed' : e.status === 'draft' ? 'Being prepared. Voting has not opened.' : 'Cancelled'),
        h('button', { class: 'small', onclick: () => openElection(e.id) }, state)));
    }
    if (r.is_ec) box.append(h('p', { class: 'hint' }, 'Set up and manage elections in the full app.'));
  } catch (ex) { box.lastChild.replaceWith(h('p', { class: 'error' }, electionError(ex))); }
}

async function openElection(id) {
  const back = h('button', { class: 'link', onclick: openElections }, '‹ All elections');
  app.replaceChildren(back, h('p', { class: 'hint' }, 'Loading...'));
  try {
    const e = await rpc('election_get', { token: session.token, eid: id });
    if (e.status === 'closed') return showResults(e, back);
    const posts = e.posts;
    const voted = posts.length && posts.every((p) => p.voted);
    const choices = {};
    const go = h('button', { disabled: true }, 'Review and cast my vote');
    const error = h('p', { class: 'error' });
    const out = h('div', null, back, h('h2', null, e.title), e.notes ? h('p', null, e.notes) : null);
    if (e.status !== 'open') out.append(h('p', { class: 'hint' }, 'Voting has not opened.'));
    else if (voted) out.append(h('div', { class: 'notice' }, 'You have voted. Your vote is secret and cannot be changed.'));
    else if (!e.can_vote) out.append(h('div', { class: 'notice' }, 'You were not on the voters list when this election opened.'));
    const voting = e.status === 'open' && e.can_vote && !voted;
    const refresh = () => { go.disabled = !posts.every((p) => choices[p.id]); };
    for (const p of posts) {
      const card = h('div', { class: 'card' }, h('h2', null, p.title));
      const options = [];
      const pick = (val, el) => { choices[p.id] = val; options.forEach((o) => o.classList.remove('picked')); el.classList.add('picked'); refresh(); };
      for (const c of p.candidates) {
        const el = h('div', { class: 'cand' }, photoOrInitials(c, 72),
          h('div', null, h('b', null, c.name), h('div', { class: 'sub' }, c.member_no || ''), c.manifesto ? h('div', { class: 'sub' }, c.manifesto) : null));
        if (voting) { el.addEventListener('click', () => pick(c.id, el)); options.push(el); }
        card.append(el);
      }
      if (voting) {
        const ab = h('div', { class: 'cand' }, h('div', { class: 'cphoto init', style: 'width:72px;height:72px' }, '—'),
          h('div', null, h('b', null, 'Abstain'), h('div', { class: 'sub' }, 'I do not choose anyone for this post.')));
        ab.addEventListener('click', () => pick('abstain', ab));
        options.push(ab);
        card.append(ab);
      }
      out.append(card);
    }
    if (voting) {
      go.addEventListener('click', async () => {
        const name = (p) => choices[p.id] === 'abstain' ? 'No one (abstain)' : (p.candidates.find((c) => c.id === choices[p.id]) || {}).name;
        const summary = posts.map((p) => `${p.title}: ${name(p)}`).join('\n');
        if (!confirm(`Check your vote\n\n${summary}\n\nYou cannot change your vote after this.`)) return;
        go.disabled = true; error.textContent = '';
        try {
          await rpc('election_vote', { token: session.token, eid: id, choices });
          app.replaceChildren(h('div', { class: 'card' }, h('h2', null, 'Your vote has been recorded.'),
            h('p', null, 'It is secret. Nobody can see how you voted, and it cannot be changed.'),
            h('button', { onclick: openElections }, 'Done')));
        } catch (ex) { error.textContent = electionError(ex); go.disabled = false; }
      });
      out.append(error, go);
    }
    app.replaceChildren(out);
  } catch (ex) { app.replaceChildren(back, h('p', { class: 'error' }, electionError(ex))); }
}

async function showResults(e, back) {
  try {
    const r = await rpc('election_results', { token: session.token, eid: e.id });
    const out = h('div', null, back, h('h2', null, r.title),
      h('p', { class: 'hint' }, r.log_ok ? 'Record verified.' : 'Warning: record verification failed.'));
    for (const p of r.posts) {
      const card = h('div', { class: 'card' }, h('h2', null, p.title));
      const tie = p.candidates.length > p.seats && p.candidates[p.seats - 1].votes === p.candidates[p.seats].votes;
      p.candidates.forEach((c, i) => {
        const pct = p.ballots ? Math.round((c.votes / p.ballots) * 100) : 0;
        card.append(h('div', { class: 'cand' }, photoOrInitials(c, 56),
          h('div', { style: 'flex:1' }, h('b', null, c.name), i < p.seats && !tie && p.ballots > 0 ? ' ✅ Elected' : '',
            h('div', { class: 'bar' }, h('i', { style: `width:${pct}%` }))),
          h('b', null, String(c.votes))));
      });
      card.append(h('div', { class: 'sub' }, `${p.ballots} votes cast out of ${r.voters} members · ${p.abstained} abstained`));
      if (tie) card.append(h('div', { class: 'sub' }, 'There is a tie for the last seat. The Electoral Commission decides how it is settled.'));
      if (p.ballots !== p.voted) card.append(h('p', { class: 'error' }, 'Warning: the number of votes does not match the voted list.'));
      out.append(card);
    }
    app.replaceChildren(out);
  } catch (ex) { app.replaceChildren(back, h('p', { class: 'error' }, electionError(ex))); }
}

// ---------- me ----------
const group = (title, ...rows) => h('div', { class: 'grp' }, h('h3', null, title), ...rows);
const pair = (a, b) => h('div', { class: 'pair' }, a, b);

const FIELDS = [
  ['full_name', 'Full name', 'text'], ['whatsapp_name', 'Username', 'text'], ['phone', 'Phone number', 'tel'], ['whatsapp', 'Second number', 'tel'],
  ['email', 'Email', 'email'], ['occupation', 'Occupation', 'text'], ['location', 'Town or area', 'text'],
  ['address', 'Address', 'text'], ['gps_address', 'GPS address', 'text'],
  ['emergency_name', 'Name', 'text'], ['emergency_phone', 'Phone', 'tel'],
];

function viewMe() {
  const out = h('div');
  out.append(pictureForm());
  if (home.self_edit) out.append(profileForm());
  else out.append(whatsappNameForm(), h('p', { class: 'hint' }, 'For other details, contact your Zone Secretary.'));
  out.append(passwordForm());
  out.append(h('button', { class: 'out', onclick: async () => {
    try { await rpc('member_sign_out', { token: session.token }); } catch (_) { /* leave locally anyway */ }
    signOutLocal();
  } }, 'Sign out'));
  out.append(installHint());
  return out;
}

function pictureForm() {
  const img = h('img', { class: 'c-av big', alt: '', hidden: true });
  const initials = h('div', { class: 'c-av big' }, String(home.member.name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join(''));
  const show = (photo) => { img.hidden = !photo; initials.hidden = !!photo; if (photo) img.src = photo; };
  rpc('avatar_get', { token: session.token, as_name: null }).then((r) => show(r.photo)).catch(() => {});
  const file = h('input', { type: 'file', accept: 'image/*', hidden: true, onchange: async (e) => {
    const f = e.target.files[0]; e.target.value = '';
    if (!f) return;
    try {
      const u = await shrink(f, 200, 0.7);
      await rpc('avatar_set', { token: session.token, photo: u, as_name: null });
      show(u);
    } catch (ex) { alert(ex.message); }
  } });
  return h('div', { class: 'card' },
    h('div', { class: 'c-pic' }, img, initials,
      h('div', null, h('b', { class: 'c-nm' }, home.member.name), h('span', null, home.member.member_no))),
    chips(home.roles), file,
    h('div', { class: 'c-acts' },
      h('button', { type: 'button', class: 'small', onclick: () => file.click() }, 'Change picture'),
      h('button', { type: 'button', class: 'small secondary', onclick: async () => {
        try { await rpc('avatar_set', { token: session.token, photo: null, as_name: null }); show(null); } catch (ex) { alert(ex.message); }
      } }, 'Remove')));
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
        h('p', { class: 'hint' }, 'Zone chosen. To change it, contact your Zone Secretary.'));
      return;
    }
    zoneBox.append(h('p', { class: 'hint' }, 'Choose one zone, or two at most. This cannot be changed later.'));
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
  const fld = (k) => {
    const f = FIELDS.find((x) => x[0] === k);
    inputs[k] = h('input', { type: f[2], value: p[k] || '', maxlength: 200 });
    return h('div', { class: 'fld' }, h('label', null, f[1]), inputs[k]);
  };
  return h('form', { class: 'card form', onsubmit: async (e) => {
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
    h('h2', { style: 'padding:14px 0 0;margin:0' }, 'My details'),
    group('Personal', fld('full_name'), pair(fld('whatsapp_name'), h('div', { class: 'fld' }, h('label', null, 'Gender'), gender))),
    group('Contact', pair(fld('phone'), fld('whatsapp')), fld('email')),
    group('About me', pair(fld('occupation'), fld('location'))),
    group('Address', fld('address'), fld('gps_address')),
    group('Emergency contact', pair(fld('emergency_name'), fld('emergency_phone'))),
    h('div', { class: 'grp' }, zoneBox), err, btn);
}

// Every member may set the username other members see in chats.
function whatsappNameForm() {
  const input = h('input', { type: 'text', value: home.whatsapp_name || '', maxlength: 200 });
  const msg = h('p', { class: 'hint', hidden: true });
  const btn = h('button', { type: 'submit' }, 'Save');
  return h('form', { class: 'card fld', onsubmit: async (e) => {
    e.preventDefault();
    btn.disabled = true; msg.hidden = true; msg.className = 'hint';
    try {
      await rpc('member_update_profile', { token: session.token, patch: { whatsapp_name: input.value }, zone_ids: null });
      await loadHome();
      show('me');
    } catch (ex) {
      if (ex.expired) return signOutLocal();
      msg.textContent = ex.message; msg.className = 'error'; msg.hidden = false;
      btn.disabled = false;
    }
  } }, h('h2', null, 'My username'), h('p', { class: 'hint' }, 'Other members see this in chats instead of your full name.'), input, msg, btn);
}

function passwordForm() {
  const cur = h('input', { type: 'password', autocomplete: 'current-password', required: true });
  const next = h('input', { type: 'password', autocomplete: 'new-password', required: true, minlength: 6 });
  const msg = h('p', { class: 'hint', hidden: true });
  const btn = h('button', { type: 'submit' }, 'Change password');
  const form = h('form', { class: 'inner fld', onsubmit: async (e) => {
    e.preventDefault();
    btn.disabled = true; msg.hidden = true; msg.className = 'hint';
    try {
      await auth({ action: 'change_password', member_no: home.member.member_no, password: cur.value, new_password: next.value });
      msg.textContent = 'Password changed.';
      cur.value = ''; next.value = '';
    } catch (ex) { msg.textContent = ex.message; msg.className = 'error'; }
    msg.hidden = false; btn.disabled = false;
  } }, h('label', null, 'Current password'), cur, h('label', null, 'New password'), next, msg, btn);
  return h('details', { class: 'card fold' }, h('summary', null, 'Change password'), form);
}

// ---------- start ----------
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
window.addEventListener('online', () => { if (session && offline) loadHome(); });
if (session) loadHome(); else renderAuth('signin');
