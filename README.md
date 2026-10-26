# kognitiv

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Website

The same Flutter app runs in web browsers. On a wide screen it shows as a
phone-width column in the middle of the window.

- **Hosting:** the backend serves the web build itself, at its own address
  (`/` is the website; the API routes are unchanged). The website calls the
  API on whatever server it was loaded from.
- **Deploy:** `scripts/deploy_backend.sh` (if the backend changed), then
  `scripts/deploy_web.sh`, which builds `build/web` and copies it to
  `~/apps/kognitiv/backend/web` on the server. No restart needed.
- **Try it locally:**
  ```sh
  flutter build web --no-web-resources-cdn
  cd backend && KOGNITIV_WEB=../build/web .venv/bin/uvicorn app.main:app --port 8000
  # open http://localhost:8000/
  ```
- **Web-only differences:** browsers can't read Project Gutenberg directly
  (no CORS), so Between the Lines fetches novel slices through the backend
  (`/passages/gutenberg/{id}`); Wikipedia is called directly with `origin=*`.
- Icons, favicon and the loading-screen logo come from
  `scripts/make_app_icons.py`.

## Notifications (daily reminder)

Settings → Daily reminder: a notification at a chosen time on days the
session isn't finished. The backend sends it as Web Push (`backend/app/push/`),
checking every minute; the website shows it with `web/sw.js`.

- Needs the website on **https**. Browsers, and iPhones in particular, only
  allow notifications on secure pages.
- **iPhone (iOS 16.4+):** open the https address in Safari, Share → Add to
  Home Screen, open Kognitiv from the Home Screen, then turn notifications on
  in Settings → Daily reminder. A web app added from another address
  (e.g. the plain-http one) has to be added again.
- The server's signing key (`vapid_private.pem`) is made on first use next to
  the database. Keep it: a new key means every device has to turn
  notifications on again. Set `KOGNITIV_VAPID_SUBJECT` to a `mailto:` address
  you control; push services use it to contact the sender.
- The phone apps don't receive pushes themselves; the screen explains that
  reminders come through the web app.
