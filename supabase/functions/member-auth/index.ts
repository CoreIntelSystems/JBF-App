// Member sign-in for the app. Every member signs in with their member ID
// and a password. The first time, they activate by proving the phone
// number the association has for them and choosing a password. People
// with an executive role get a synced phone (scoped to their role); others
// get a member session that reads only their own statement and the
// public lists. Hashes use the same PBKDF2 format as
// lib/domain/password_hasher.dart.
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

function toBase64(b: Uint8Array): string {
  return btoa(String.fromCharCode(...b));
}

function fromBase64(s: string): Uint8Array {
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

// Stored format: pbkdf2-sha256$<iterations>$<salt b64>$<hash b64>
async function verify(password: string, stored: string): Promise<boolean> {
  const parts = stored.split("$");
  if (parts.length !== 4 || parts[0] !== "pbkdf2-sha256") return false;
  const iterations = Number(parts[1]);
  if (!Number.isInteger(iterations) || iterations < 1 || iterations > 1000000) {
    return false;
  }
  const salt = fromBase64(parts[2]);
  const expected = fromBase64(parts[3]);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "PBKDF2", hash: "SHA-256", salt, iterations },
      key,
      expected.length * 8,
    ),
  );
  let diff = bits.length ^ expected.length;
  for (let i = 0; i < Math.min(bits.length, expected.length); i++) {
    diff |= bits[i] ^ expected[i];
  }
  return diff === 0;
}

const ITERATIONS = 60000;

async function hash(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "PBKDF2", hash: "SHA-256", salt, iterations: ITERATIONS },
      key,
      256,
    ),
  );
  return `pbkdf2-sha256$${ITERATIONS}$${toBase64(salt)}$${toBase64(bits)}`;
}

type Lookup = {
  org_id: string;
  found: boolean;
  phone_ok: boolean;
  activated: boolean;
  password_hash: string | null;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return refuse("Use POST.");
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return refuse("Send JSON.");
  }
  const action = String(body.action ?? "sign_in");
  const org = String(body.org ?? "").trim();
  const memberNo = String(body.member_no ?? "").trim();
  const password = String(body.password ?? "");
  const newPassword = String(body.new_password ?? "");
  const phone = String(body.phone ?? "");
  const deviceName = String(body.device_name ?? "").trim();
  const checkOnly = body.check === true;
  // The member web app has no synced phone: executives get a member session.
  const web = body.web === true;
  if (!org || !memberNo) return refuse("Enter your member ID.");

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const lookup = await db.rpc("member_auth_lookup", {
    org,
    member_no: memberNo,
    phone,
  });
  if (lookup.error) return refuse(lookup.error.message);
  const m = lookup.data as Lookup;

  let ok = false;
  let newHash: string | null = null;
  let message = "Wrong member ID or password.";
  if (action === "activate") {
    message = "Member ID and phone number do not match our records.";
    if (m.found && m.activated) {
      return refuse(
        "This account is already active. Sign in with your password, or " +
          "ask your Zone Secretary or Zone Mayor to reset it.",
      );
    }
    if (newPassword.length < 6) {
      return refuse("Choose a password of at least 6 characters.");
    }
    ok = m.found && m.phone_ok;
    if (ok) newHash = await hash(newPassword);
  } else if (
    action === "sign_in" || action === "change_password" || action === "delete_account"
  ) {
    if (m.found && !m.activated) {
      return refuse(
        "Activate your account first with your member ID and phone number.",
      );
    }
    ok = m.found && m.password_hash != null &&
      await verify(password, m.password_hash);
    if (ok && action === "change_password") {
      if (newPassword.length < 6) {
        return refuse("Choose a password of at least 6 characters.");
      }
      newHash = await hash(newPassword);
    }
  } else {
    return refuse("Unknown action.");
  }
  const done = await db.rpc(web ? "member_auth_complete_web" : "member_auth_complete", {
    org: m.org_id,
    member_no: memberNo,
    ok,
    new_hash: newHash,
    device_name: deviceName || null,
    check_only: checkOnly || action === "change_password" || action === "delete_account",
  });
  if (done.error) return refuse(done.error.message);
  if (!ok) return refuse(message);
  if (action === "delete_account") {
    const gone = await db.rpc("member_erase", { org: m.org_id, member_no: memberNo });
    if (gone.error) return refuse(gone.error.message);
    return reply({ kind: "deleted" });
  }
  return reply(done.data);
});
