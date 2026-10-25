# Sanstha Seva — final prototype package

## Included
- Responsive static website in `web/` with a PWA manifest and offline cache.
- Android Studio WebView project in `android/`.
- GitHub Actions workflows:
  - `.github/workflows/deploy-pages.yml` publishes the static website to free GitHub Pages.
  - `.github/workflows/build-android.yml` builds a debug APK and uploads it as an Actions artifact.
- Node/Express starter in `server/` for local testing.

## Publish the website for free
1. Sign in to GitHub and create a **public** repository named `sanstha-seva`.
2. Upload the contents of this ZIP to the repository root (not the ZIP itself). Ensure `.github/workflows/` is included.
3. Open **Settings → Pages** and select **GitHub Actions** as the build/deployment source.
4. Open **Actions**, run **Publish Sanstha Seva website** if it has not run automatically.
5. When complete, open the deployment URL shown in the workflow (usually `https://YOUR-USERNAME.github.io/sanstha-seva/`).
6. On Android Chrome, open that URL and choose **Add to Home screen** / **Install app**.

## Get an APK without installing Android Studio locally
1. Push/upload all project files to GitHub with the `android/` directory and `.github/workflows/build-android.yml`.
2. Open **Actions → Build Sanstha Seva Android APK → Run workflow**.
3. Wait for the workflow to finish successfully.
4. Open its completed run, scroll to **Artifacts**, and download `SansthaSeva-debug-apk`.
5. Extract the artifact ZIP to obtain `app-debug.apk`. Android may ask you to allow installs from that source.

## Important limitations before real public use
This is a prototype, not a production donation/financial system. Demo records are stored in each browser's localStorage and are not securely shared across devices. No real authentication, automated SMS/WhatsApp/email reminders, live Stripe subscription/webhook integration, or hardened central database has been implemented. The Stripe endpoint returns a not-configured response. Do not use real donor/child data or accept live money until a secure backend, access controls, backups, audit logs, privacy notice, and payment verification are implemented and tested.

## Google Play publishing
Google Play developer registration currently costs US$25 once; therefore Google Play publishing is not entirely free. You can share the debug APK privately at no Play Store cost for testing, but a debug build is not the recommended public release. See official Android build guidance and Google Play Console requirements.
