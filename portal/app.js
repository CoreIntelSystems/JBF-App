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
const auth = (body) => call('/functions/v1/member-auth', { org: ORG, web: true, ...body });

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
      home.whatsapp_name ? h('div', { class: 'sub' }, 'WhatsApp: ' + home.whatsapp_name) : null,
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
  if (home.officer || (home.roles || []).length) {
    out.append(h('div', { class: 'notice' }, h('b', null, 'Executive'), h('br'),
      'Your roles show on your card and in your chats. To record payments, confirm what members paid and manage records, open the full app: ',
      h('a', { href: 'https://jbf-app.onrender.com', target: '_blank' }, 'jbf-app.onrender.com'), '.'));
  }
  if (!offline) out.append(payReminder());
  out.append(h('div', { class: 'card' }, h('div', { class: 'row' }, h('span', null, '🗳 Elections'),
    h('button', { class: 'small', onclick: openElections }, 'Open'))));
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
      'Pay, then tell the Treasurer how you paid.',
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
    card.append(h('p', { class: 'hint' }, `⏳ You reported ${money(mine.amount)} by ${methods[mine.method] || mine.method}. Waiting for the Treasurer to confirm.`));
    return card;
  }
  if (mine && mine.status === 'confirmed') {
    card.append(h('p', { class: 'clear' }, '✅ Confirmed. Receipt ' + mine.receipt_no + '.'));
    return card;
  }
  if (mine && mine.status === 'rejected') {
    card.append(h('p', { class: 'error' }, 'Your report was not accepted: ' + (mine.decision_note || '')));
  }
  if (r.closed) { card.append(h('p', { class: 'hint' }, 'This request is closed.')); return card; }
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
    h('label', null, 'Note for the Treasurer (optional)'), note,
    err, btn);
}

function viewPay() {
  const out = h('div', null, payRequests());
  const card = h('div', { class: 'card' }, h('h2', null, 'Payments'));
  out.append(card);
  const pays = home.payments || [];
  if (!pays.length) card.append(h('p', { class: 'hint' }, 'No payments recorded yet.'));
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
  if (!events.length) ev.append(h('p', { class: 'hint' }, 'Nothing coming up.'));
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

// Members can find each other by name or WhatsApp name.
function directoryCard() {
  const people = home.directory || [];
  const list = h('div');
  const draw = (q) => {
    q = q.trim().toLowerCase();
    const shown = people.filter((p) => !q || (p.name || '').toLowerCase().includes(q) || (p.whatsapp_name || '').toLowerCase().includes(q));
    list.replaceChildren(...shown.slice(0, 100).map((p) => h('div', { class: 'row' },
      h('span', null, p.name, p.whatsapp_name ? h('div', { class: 'sub' }, 'WhatsApp: ' + p.whatsapp_name) : null),
      h('span', { class: 'sub' }, realZones(p).join(', ')))),
    shown.length > 100 ? h('p', { class: 'hint' }, `Showing 100 of ${shown.length}. Type more of the name to narrow it down.`) : null,
    shown.length ? null : h('p', { class: 'hint' }, 'No member found.'));
  };
  draw('');
  return h('div', { class: 'card' }, h('h2', null, `Members (${people.length})`),
    h('input', { type: 'search', placeholder: 'Search by name or WhatsApp name', oninput: (e) => draw(e.target.value) }), list);
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
      list.append(h('div', { class: 'msg' + (m.mine ? ' mine' : '') }, m.mine ? null : h('b', null, m.author, m.author_whatsapp ? ' ~' + m.author_whatsapp : ''), m.body));
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
      box.append(h('div', { class: 'notice' }, h('b', null, '📣 ' + n.title), h('div', null, n.body),
        h('div', { class: 'sub' }, `From the ${n.from || 'Electoral Commission'} · ` + new Date(n.at).toLocaleDateString('en-GB', { dateStyle: 'medium' }))));
    }
    if (!r.elections.length) box.append(h('p', { class: 'hint' }, 'There are no elections yet.'));
    for (const e of r.elections) {
      const state = e.status === 'open' ? (e.voted_all ? 'You have voted' : e.can_vote ? 'Vote now' : 'Open')
        : e.status === 'closed' ? 'See results' : 'View';
      box.append(h('div', { class: 'card' }, h('h2', null, e.title),
        h('div', { class: 'sub' }, e.status === 'open' ? 'Closes ' + new Date(e.closes_at).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' })
          : e.status === 'closed' ? 'Voting closed' : e.status === 'draft' ? 'Being prepared. Voting has not opened.' : 'Cancelled'),
        h('button', { class: 'small', onclick: () => openElection(e.id) }, state)));
    }
    if (r.is_ec) box.append(h('p', { class: 'hint' }, 'To set up, change, cancel or open an election, or to use the Commission office (tasks, minutes, notices, voter roll and chat), use the full app.'));
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
      h('p', { class: 'hint' }, r.log_ok ? 'Record checked: no step of this election was altered.' : 'Warning: the election record does not check out.'));
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
const FIELDS = [
  ['full_name', 'Full name', 'text'], ['whatsapp_name', 'WhatsApp name', 'text'], ['phone', 'Phone number', 'tel'], ['whatsapp', 'Second or WhatsApp number', 'tel'],
  ['email', 'Email', 'email'], ['occupation', 'Occupation', 'text'], ['location', 'Town or area', 'text'],
  ['address', 'Address', 'text'], ['gps_address', 'GPS address', 'text'],
  ['emergency_name', 'Emergency contact name', 'text'], ['emergency_phone', 'Emergency contact phone', 'tel'],
];

function viewMe() {
  const out = h('div');
  out.append(h('div', { class: 'card' }, h('h2', null, home.member.name),
    h('div', { class: 'row' }, h('span', null, 'Member ID'), h('span', null, home.member.member_no)),
    chips(home.roles)));
  if (home.self_edit) out.append(profileForm());
  else out.append(whatsappNameForm(), h('p', { class: 'hint' }, 'To correct your other details, speak to your Zone Secretary.'));
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

// Every member may set the name they use on WhatsApp.
function whatsappNameForm() {
  const input = h('input', { type: 'text', value: home.whatsapp_name || '', maxlength: 200 });
  const msg = h('p', { class: 'hint', hidden: true });
  const btn = h('button', { type: 'submit' }, 'Save');
  return h('form', { class: 'card', onsubmit: async (e) => {
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
  } }, h('h2', null, 'My WhatsApp name'), h('p', { class: 'hint' }, 'The name others see for you on WhatsApp.'), input, msg, btn);
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
