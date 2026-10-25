// Supabase Edge Function: admin-only creation of username/password accounts.
// Deploy this function and keep SUPABASE_SERVICE_ROLE_KEY only in Supabase server secrets.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json" };
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: cors });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") || "";
  if (!authHeader.startsWith("Bearer ")) return reply(401, { error: "Sign in as an administrator first." });
  const callerClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } });
  const { data: callerData, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerData.user) return reply(401, { error: "Your session is invalid. Please sign in again." });
  const adminClient = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await adminClient.from("profiles").select("role").eq("id", callerData.user.id).single();
  if (profileError || profile?.role !== "admin") return reply(403, { error: "Only an administrator can create login accounts." });
  let body: any;
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid request body." }); }
  const username = String(body.username || "").trim().toLowerCase();
  const password = String(body.password || "");
  const displayName = String(body.displayName || "").trim();
  const familyId = String(body.familyId || "").trim();
  const role = body.role === "staff" ? "staff" : "member";
  if (!/^[a-z0-9._-]{3,32}$/.test(username)) return reply(400, { error: "Username must be 3–32 characters: letters, numbers, dot, underscore or hyphen." });
  if (password.length < 8 || password.length > 72) return reply(400, { error: "Password must be 8–72 characters." });
  if (!displayName) return reply(400, { error: "Member full name is required." });
  const email = `${username}@members.sanstha.invalid`;
  const { data, error } = await adminClient.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { username, display_name: displayName, family_id: familyId || null } });
  if (error) return reply(400, { error: error.message.includes("already been registered") ? "That username already exists. Choose another." : error.message });
  if (role === "staff") {
    const { error: roleError } = await adminClient.from("profiles").update({ role: "staff" }).eq("id", data.user.id);
    if (roleError) { await adminClient.auth.admin.deleteUser(data.user.id); return reply(500, { error: "Could not assign staff access. Account creation was rolled back." }); }
  }
  return reply(200, { ok: true, username, role, message: "Account created. Give the username and temporary password to the member privately." });
});
