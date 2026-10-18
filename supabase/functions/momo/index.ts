// Pay by MTN Mobile Money (MTN MoMo Collection API, "request to pay").
//
//   { action: "enabled" }                       -> { enabled }
//   { action: "start", token, type_id, period, amount, phone }
//                                               -> { id, status }
//   { action: "status", token, id }             -> { status, receipt_no, reason }
//   POST ?cb=<payment id> (MTN's callback)      -> 200
//
// Nothing here trusts the phone: a payment only becomes a receipt when MTN
// itself reports SUCCESSFUL for that payment id and the same amount. The
// callback body is ignored; it only prompts us to ask MTN. The database
// functions it calls (momo_prepare, momo_finish, ...) are for the service
// role only.
//
// Secrets (Supabase, Edge Functions): MOMO_SUBSCRIPTION_KEY, MOMO_API_USER,
// MOMO_API_KEY, MOMO_ENV ("sandbox" while testing, "mtnghana" when live).
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, content-type, authorization",
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function refuse(message: string) {
  return reply({ code: "P0001", message }, 400);
}

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const KEY = Deno.env.get("MOMO_SUBSCRIPTION_KEY") ?? "";
const USER = Deno.env.get("MOMO_API_USER") ?? "";
const SECRET = Deno.env.get("MOMO_API_KEY") ?? "";
const ENV = Deno.env.get("MOMO_ENV") ?? "";
const SANDBOX = ENV === "sandbox";
const BASE = SANDBOX
  ? "https://sandbox.momodeveloper.mtn.com"
  : "https://proxy.momoapi.mtn.com";
// MTN's sandbox only accepts EUR; Ghana live uses GHS.
const CURRENCY = Deno.env.get("MOMO_CURRENCY") ?? (SANDBOX ? "EUR" : "GHS");
const configured = () => !!(KEY && USER && SECRET && ENV);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function mtnToken(): Promise<string> {
  const res = await fetch(`${BASE}/collection/token/`, {
    method: "POST",
    headers: {
      Authorization: "Basic " + btoa(`${USER}:${SECRET}`),
      "Ocp-Apim-Subscription-Key": KEY,
    },
  });
  if (!res.ok) throw new Error("token " + res.status);
  return (await res.json()).access_token as string;
}

const mtnHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
  "X-Target-Environment": ENV,
  "Ocp-Apim-Subscription-Key": KEY,
});

// "50" for 5000 pesewas, "12.5" for 1250.
function amountText(pesewas: number): string {
  return String(Number((pesewas / 100).toFixed(2)));
}

type Row = {
  id: string;
  status: string;
  amount: number;
  phone: string;
  receipt_no?: string | null;
  reason?: string | null;
};

// Ask MTN how payment [row] went and record the answer. Returns the row's
// state after that.
async function settle(row: Row): Promise<Record<string, unknown>> {
  if (row.status !== "pending") {
    return { status: row.status, receipt_no: row.receipt_no, reason: row.reason };
  }
  let body: Record<string, unknown>;
  try {
    const token = await mtnToken();
    const res = await fetch(
      `${BASE}/collection/v1_0/requesttopay/${row.id}`,
      { headers: mtnHeaders(token) },
    );
    if (res.status === 404) {
      // MTN does not know it yet; still waiting.
      return { status: "pending" };
    }
    if (!res.ok) return { status: "pending" };
    body = await res.json();
  } catch (_) {
    return { status: "pending" };
  }
  const state = String(body.status ?? "");
  if (state === "PENDING") return { status: "pending" };
  if (state === "SUCCESSFUL") {
    const paid = Math.round(Number(body.amount) * 100);
    const payer = String((body.payer as { partyId?: string } | undefined)?.partyId ?? "");
    if (paid !== Number(row.amount) || (payer && payer !== row.phone)) {
      const { data } = await db.rpc("momo_finish", {
        pid: row.id,
        ok: false,
        reason: "MTN reported a different amount or number. Speak to the Treasurer.",
      });
      return data;
    }
    const { data, error } = await db.rpc("momo_finish", {
      pid: row.id,
      ok: true,
      financial_id: body.financialTransactionId ? String(body.financialTransactionId) : null,
    });
    if (error) return { status: "pending" };
    return data;
  }
  const reasonRaw = body.reason;
  const code = typeof reasonRaw === "string"
    ? reasonRaw
    : String((reasonRaw as { code?: string } | undefined)?.code ?? "");
  const text: Record<string, string> = {
    PAYER_REJECTED: "You declined the payment on your phone.",
    APPROVAL_REJECTED: "You declined the payment on your phone.",
    PAYER_NOT_FOUND: "That number is not registered for MTN Mobile Money.",
    NOT_ENOUGH_FUNDS: "There is not enough money in your Mobile Money wallet.",
    EXPIRED: "The payment request expired before you approved it.",
    PAYER_LIMIT_REACHED: "Your Mobile Money limit has been reached.",
  };
  const { data } = await db.rpc("momo_finish", {
    pid: row.id,
    ok: false,
    reason: text[code] ?? "The payment was not completed. You were not charged.",
  });
  return data;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  const url = new URL(req.url);
  const cb = url.searchParams.get("cb");
  if (cb) {
    // MTN's callback: ignore its body, ask MTN.
    if (UUID.test(cb) && configured()) {
      const { data } = await db.rpc("momo_row", { pid: cb });
      if (data) await settle(data as Row);
    }
    return new Response("ok", { status: 200 });
  }

  if (req.method !== "POST") return refuse("Not supported.");
  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch (_) {
    return refuse("Bad request.");
  }

  if (b.action === "enabled") return reply({ enabled: configured() });
  if (!configured()) return refuse("Paying with MoMo is not switched on yet.");
  const token = String(b.token ?? "");
  if (!token) return refuse("Sign in again to pay.");

  if (b.action === "start") {
    const { data, error } = await db.rpc("momo_prepare", {
      token,
      type_id: String(b.type_id ?? ""),
      period: b.period == null ? null : String(b.period),
      amount: Number(b.amount),
      phone: String(b.phone ?? ""),
    });
    if (error) return refuse(error.message);
    const row = data as { id: string; amount: number; phone: string; title: string };
    try {
      const t = await mtnToken();
      const res = await fetch(`${BASE}/collection/v1_0/requesttopay`, {
        method: "POST",
        headers: {
          ...mtnHeaders(t),
          "X-Reference-Id": row.id,
          "X-Callback-Url": `${Deno.env.get("SUPABASE_URL")}/functions/v1/momo?cb=${row.id}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: amountText(row.amount),
          currency: CURRENCY,
          externalId: row.id,
          payer: { partyIdType: "MSISDN", partyId: row.phone },
          payerMessage: `June Borns Family: ${row.title}`.slice(0, 160),
          payeeNote: row.title.slice(0, 160),
        }),
      });
      if (res.status !== 202) {
        await db.rpc("momo_finish", {
          pid: row.id,
          ok: false,
          reason: "MTN could not start the payment. Try again later.",
        });
        return refuse("MTN could not start the payment. Try again later.");
      }
    } catch (_) {
      await db.rpc("momo_finish", {
        pid: row.id,
        ok: false,
        reason: "Could not reach MTN. Try again later.",
      });
      return refuse("Could not reach MTN. Try again later.");
    }
    return reply({ id: row.id, status: "pending", phone: row.phone });
  }

  if (b.action === "status") {
    const id = String(b.id ?? "");
    if (!UUID.test(id)) return refuse("No such payment.");
    const { data, error } = await db.rpc("momo_get", { token, pid: id });
    if (error) return refuse(error.message);
    return reply(await settle(data as Row));
  }

  return refuse("Not supported.");
});
