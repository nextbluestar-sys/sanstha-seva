# Sanstha Seva — shared database and secure sign-in starter

This version connects the existing Sanstha Seva website to **Supabase Auth + PostgreSQL**. It is designed for GitHub Pages and the Android WebView package. The browser receives only a Supabase **publishable** key; database Row Level Security (RLS) policies enforce which rows each signed-in user can read or change.

## What is included

- Email/password sign-in and account creation.
- Shared `members`, `donations`, `profiles`, and `announcements` tables.
- New accounts always start with the `member` role. Only an existing administrator can promote users.
- Staff/admin can add members, record donations, and publish announcements.
- Members can read only the members and donation records for the family assigned to their profile.
- SQL migration with RLS policies and a trigger that creates a profile on signup.
- GitHub Pages deployment and Android APK build workflows.

## Updating an existing GitHub Pages repository

To replace the old demo website with this version, upload/replace the contents of this project into the repository root (keep `.github/workflows/` and `web/`), then commit the changes. The deployment workflow publishes `web/`. The secure login screen appears after the Supabase URL and publishable key are configured. After signing in, one **Log out** control is available in the top-right header. The login gate is a full-screen layer, so it cannot sit beside or overlap the dashboard. The service-worker cache version is bumped to help existing installs receive the layout fix.

## Setup (one-time)

### 1. Create a Supabase project

1. Open [Supabase Dashboard](https://supabase.com/dashboard) and create a project.
2. Wait for the database to finish provisioning.
3. Open **SQL Editor → New query**.
4. Open `supabase/migrations/202610250001_secure_shared_database.sql` from this project, copy all of it into the SQL editor, and click **Run**.
5. In **Project Settings → API Keys** (or the project's **Connect** dialog), copy the **Project URL** and the **publishable key**. The publishable key commonly begins `sb_publishable_`. Older projects may show an `anon` key, which is also a public client key.

### 2. Add the public connection settings

1. In your GitHub repository, open `web/supabase-config.js` and click Edit.
2. Replace the two empty strings with your project values, for example:

   ```js
   window.SANSTHA_CONFIG = {
     supabaseUrl: "https://YOUR-PROJECT-REF.supabase.co",
     supabasePublishableKey: "sb_publishable_YOUR_PUBLIC_KEY"
   };
   ```

3. Commit the change. GitHub Actions should redeploy the website.

**Never paste a Supabase secret key or legacy `service_role` key into this file, the browser, Android assets, GitHub, or a chat.** The publishable key is intended for the client; RLS is what protects the data.

### 3. Create the first administrator

1. Open the deployed Sanstha Seva website and choose **Create account** with an email you control.
2. If email confirmation is enabled, open the confirmation email and confirm the account.
3. In Supabase **SQL Editor**, run this query after replacing the email with the same email used above:

   ```sql
   update public.profiles
   set role = 'admin'
   where id = (select id from auth.users where email = 'YOUR_ADMIN_EMAIL');
   ```

4. Sign in again on the website. The account should show the `ADMIN` role and can add members, donations, and announcements.

### 4. Assign a member login to a family

For each member account, the user must first create an account on the website and confirm their email (if required). An administrator then assigns the profile to the correct family/member record in the SQL Editor. Replace the email and IDs with actual values:

```sql
update public.profiles
set family_id = 'FS-1001', member_id = 'MEM-12345678'
where id = (select id from auth.users where email = 'member@example.com');
```

The family ID must match the `family_id` on the `members` rows. Family users then see only that family's member and donation records. Do not assign a family ID until you have verified the person's identity.

## Roles and permissions

- **Admin:** staff-level access plus ability to update profiles/assign roles.
- **Staff:** manage member, donation, and announcement records.
- **Member:** read-only access to their assigned family records and published announcements.

New accounts are members by default. Do not grant staff/admin roles to ordinary members. RLS policies protect database rows even if someone modifies the page in their browser.

## Deploy / update

- The website workflow deploys `web/` to GitHub Pages.
- If you are using the Android project, copy the updated contents of `web/` into `android/app/src/main/assets/` before building the APK. The included GitHub Actions workflow can build a debug APK.
- The website needs internet access for Supabase authentication and shared data. The PWA shell may load offline, but sign-in and database actions require connectivity.

## Before using real donor records

This is a security-oriented starter, not a completed audited financial platform. Test all role scenarios using separate accounts before adding real donor data. Enable Supabase email confirmation, configure password/reset and recovery procedures, set up database backups, monitor Supabase Security Advisor, and keep organization access limited. Donation receipts currently reflect records entered by staff; this does not verify actual bank/UPI settlement. Payment gateway webhooks, audit trails, SMS reminders, and production-grade account administration are not implemented here.

Useful official references:
- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [Secure your data](https://supabase.com/docs/guides/database/secure-data)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)


## Username/password login for village members (no email required)

This upgrade changes the website login to a username field. Internally, Supabase Auth uses a reserved synthetic address like `username@members.sanstha.invalid`; members do not need an email inbox. Password recovery by email is therefore unavailable: the administrator must create a replacement account or use a carefully planned reset process.

### Apply the upgrade safely

1. Back up your GitHub repository first.
2. Upload/replace the `web/` and `android/app/src/main/assets/` files from this package in your repository and commit them. Keep the current `web/supabase-config.js` project URL and publishable key values when copying files; do not overwrite them with the blank sample values in this package.
3. In Supabase SQL Editor, run `supabase/migrations/202610250002_username_login.sql` after your original database setup.
4. Deploy the Edge Function at `supabase/functions/create-member-login/index.ts` named `create-member-login`. In Supabase Dashboard use Edge Functions → Deploy new function / editor, or deploy with Supabase CLI. The function uses the project's server-side `SUPABASE_SERVICE_ROLE_KEY` secret; never put this key in website JavaScript or GitHub.
5. Create the FIRST admin account from Supabase Dashboard → Authentication → Users → Add user. Use an internal email like `admin@members.sanstha.invalid`, set a strong password, and mark email confirmed. This is an internal login alias, not an actual mailbox.
6. In SQL Editor, promote that user and assign username `admin` (change email if you used another alias):

   ```sql
   update public.profiles
   set role = 'admin', username = 'admin', display_name = 'Sanstha Seva Administrator'
   where id = (select id from auth.users where lower(email) = 'admin@members.sanstha.invalid');
   ```

   Confirm exactly one row was updated. Then sign in to the website with username `admin` and the password you set in Supabase.
7. In Admin Panel, create member accounts. Give each member their username and temporary password privately. Ask them not to share passwords.

### Important security notes

- The Edge Function is deliberately admin-only; staff can manage records but cannot create login accounts.
- The first admin must be created manually in Supabase because no admin exists yet to authorize account creation.
- Use a different username for every person. Do not use phone numbers or public member IDs as passwords.
- The Edge Function must be deployed and the SQL migration applied before username login works. This ZIP alone does not change the live GitHub Pages site.
