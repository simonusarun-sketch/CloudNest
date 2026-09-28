# ☁️ CloudNest

A simple private cloud for students. Sign up, upload PDFs, images and documents, add a title and notes, then view, download, favorite or delete them.

**Stack:** plain HTML/CSS/JS frontend · Supabase (Postgres, Auth, private Storage) · Vercel hosting

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app (frontend). Supabase URL and public key are set at the top of the script. |
| `schema.sql` | Database tables, security rules (RLS) and the private storage bucket. Run once in Supabase. |
| `vercel.json` | Security headers for Vercel. |

## Setup

### 1. Supabase
1. Create a project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** → **New query**, paste all of `schema.sql`, click **Run**.
3. **Project Settings → API**: copy the Project URL and the publishable (anon) key.
4. **Authentication → Providers → Email**: set minimum password length to **8**.

### 2. Connect the app
Open `index.html` and set the values near the top:

```js
const CFG = { url: "https://YOUR-PROJECT.supabase.co", key: "YOUR_PUBLISHABLE_KEY" };
```

Only use the **publishable/anon** key. Never put a `secret` or `service_role` key in this file.

### 3. Deploy on Vercel
1. Put `index.html` and `vercel.json` in a GitHub repository.
2. At [vercel.com](https://vercel.com): **Add New → Project**, import the repository, click **Deploy**.
3. Optional: add your own domain under **Settings → Domains**.

### 4. Tell Supabase your live link
**Authentication → URL Configuration**:
- **Site URL**: your Vercel link
- **Redirect URLs**: add the same link

Without this, email confirmation and password reset links will not return to your site.

## Test checklist
1. Create an account and log in.
2. Upload a PDF and an image (also try **Take Photo** on a phone).
3. Add a title and notes, then click **Save**.
4. Search, favorite, download, delete, restore from Trash.
5. Log out and confirm `#/dash` redirects to login.
6. Create a second account and confirm it cannot see the first account's files.

## Security notes
- Passwords are hashed by Supabase Auth. The app never stores them.
- Row Level Security limits every table and storage folder to the owner (`auth.uid()`).
- The storage bucket is private. Files open through signed links that expire after 1 hour.
- Server-side limits: 25 MB per file, allowed file types only, 10 GB quota per user.
- Auth attempts are rate-limited by Supabase.
- HTTPS is provided by Vercel. This follows good practice but is not a guarantee. Test with two accounts before real use.

## Troubleshooting
| Problem | Fix |
| --- | --- |
| "Setup needed" screen | The URL or key in `index.html` is still a placeholder. |
| Sign-up says check your email | Confirm the email, or turn off **Confirm email** while testing. |
| Upload rejected | Run `schema.sql` (creates the bucket and policies). Check type and size (25 MB max). |
| Reset or confirm link opens the wrong page | Set **Site URL** and **Redirect URLs** in Supabase. |
| File picker does nothing | Open the site in Chrome or Safari, not inside an app's preview window. |
| PDF preview is blank | Use the **View** button to open it in a new tab. |
