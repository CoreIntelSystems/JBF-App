// Joins a phone to its organisation's cloud sync when an officer signs in
// with their own app username and password. The password is checked
// against the PBKDF2 hash the main phone uploaded (see
// lib/domain/password_hasher.dart); the database functions handle lockout
// after repeated wrong passwords and give the phone its number series.
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return refuse("Use POST.");
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return refuse("Send JSON.");
  }
  const org = String(body.org ?? "").trim();
  const username = String(body.username ?? "").trim();
  const password = String(body.password ?? "");
  const deviceName = String(body.device_name ?? "").trim();
  if (!org || !username || !password) {
    return refuse("Enter your username and password.");
  }

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const lookup = await db.rpc("sync_sign_in_lookup", {
    org,
    user_name: username,
  });
  if (lookup.error) return refuse(lookup.error.message);
  const u = lookup.data as {
    org_id: string;
    found: boolean;
    active: boolean;
    password_hash: string | null;
    is_admin: boolean;
  };

  const ok = u.found && u.active && u.password_hash != null &&
    await verify(password, u.password_hash);
  const done = await db.rpc("sync_sign_in_complete", {
    org: u.org_id,
    user_name: username,
    ok,
    device_name: deviceName || `${username}'s phone`,
    admin: u.is_admin,
  });
  if (done.error) return refuse(done.error.message);
  if (!ok) {
    return refuse(
      u.found && !u.active
        ? "This login has been switched off. Ask your administrator."
        : "Wrong username or password. Use the login your administrator " +
          "created for you in the app.",
    );
  }
  return reply(done.data);
});
