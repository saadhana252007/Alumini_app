# IIT (ISM) Dhanbad - Institutional Admin App (Phase 1: EDC accommodation)

Flutter + Dart + Supabase, **MVVM** (Models -> Repositories/Services -> ViewModels (Riverpod) -> Views), GoRouter navigation.
Three permission-controlled roles: **EDC Admin**, **Dean Admin**, **Super Admin**. All data is real Supabase data; nothing is hardcoded.

> **Status / honesty note.** This code was written without a Flutter SDK in the build environment, so
> `flutter analyze` and `flutter test` have **not been run**. Expect to fix a few small compile or lint issues on first run
> (package-version drift is the most likely cause). Steps 3-4 below tell you exactly what to run.

## 1. Set up Supabase
1. Create a Supabase project. In **Authentication -> Providers -> Email**, turn **off "Allow new users to sign up"** (no public registration).
2. Apply the migrations in order (`supabase db push`, or paste each file into the SQL editor):
   `supabase/migrations/0001_schema.sql` ... `0005_storage.sql`.
3. Deploy the Edge Functions:
   ```
   supabase functions deploy send-notification
   supabase functions deploy admin-create-user
   # optional - real e-mail via Resend; without these, e-mails are logged as SIMULATED
   supabase secrets set RESEND_API_KEY=... EMAIL_FROM="IIT (ISM) EDC <noreply@your-domain>"
   ```
4. Create the first Super Admin (and optional demo admins). Credentials come from your environment - never from the repo:
   ```
   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<service-role> \
   ADMIN_EMAIL=you@iitism.ac.in ADMIN_NAME="Your Name" ADMIN_ROLE=super_admin \
   ADMIN_PASSWORD='at-least-12-characters' node scripts/create_admin.mjs
   ```
   Repeat with `ADMIN_ROLE=edc_admin` / `dean_admin` for demo accounts (or add them from **Administration -> Accounts** after signing in).
   The service-role key is used only by this script and the Edge Functions - **never in Flutter**.

## 2. Create platform folders (this zip contains Dart sources only)
```
flutter create . --project-name ism_edc_admin --platforms=web,android,ios,windows
flutter pub get
```
- Android release builds: add `<uses-permission android:name="android.permission.INTERNET"/>` to `android/app/src/main/AndroidManifest.xml`.
- iOS: add `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist` (notice image picker).
- Logo: put the **official, authorised** logo at `assets/branding/logo.png`. Until then a neutral "ISM" monogram is shown.

## 3. Run
```
cp env.example.json env.json      # fill SUPABASE_URL and SUPABASE_ANON_KEY (anon key only)
flutter run -d chrome --dart-define-from-file=env.json
```

## 4. Check
```
flutter analyze
flutter test
```
Tests cover tariff calculation (incl. "missing policy is never invented"), booking rules (24 h notice, 2 persons/room,
3-day personal stay, DSW forwarding, Category E), status transitions, and ODS/XLSX/PDF generation.

## What is implemented
| Area | Where |
|---|---|
| Auth, no public admin registration, role/permission session | `viewmodels/session_viewmodel.dart`, RLS `profiles` (no INSERT policy), `admin-create-user` |
| Adaptive navigation (bottom bar / rail / sidebar + top bar) | `views/shell/admin_shell.dart` |
| Role-aware dashboard (live counts, notices, arrivals, activity, quick actions) | `views/dashboard`, `dashboard_stats()` |
| Notices: image upload (private bucket + signed URLs), draft/publish/unpublish/archive, expiry, filters, see other admins' notices | `views/notices`, `0005_storage.sql` |
| Requisition form per EDC-Form.pdf (visitor fields only) | `views/requests/request_form_view.dart` |
| Office-use + approval separated from visitor fields | `request_detail_view.dart`, `decide_request()` |
| Configurable multi-stage approval, per Suite / Standard Room | `approval_workflows`, Administration -> Approval workflow |
| Duplicate-approval and invalid-transition prevention, backend permission checks | row lock + guard trigger + RPCs (`0001`, `0003`) |
| Approval history + audit logs | `approval_steps`, `audit_logs` |
| E-mail on submission and final decision (real via Resend, else labelled SIMULATED) | `send-notification`, `notification_logs` |
| PDF booking receipt after final approval | `data/services/receipt_pdf_service.dart` |
| Tariffs from the form, GST setting, duration-based calculation | `tariff_rules`, `calculate_charges()`, `views/tariffs` |
| Simulated payment (stored, labelled, one success per booking) | `simulate_payment()`, `payments.is_simulated` |
| Booking history: search, status/category/room filters, date range | `views/requests/history_view.dart` |
| Reports + XLSX / ODS / PDF export (server-checked, minimal columns) | `views/reports`, `export_booking_register()` |
| Super Admin: accounts, role permissions, workflow, tariffs, audit log | `views/admin` |

## Needs institutional confirmation (nothing was invented)
1. **GST rate** - the form says "plus admissible GST" with no number. Stored as a setting, **starts at 0%**; set it under Tariffs.
2. **Who approves what.** The form is inconsistent: Section I says Suites -> Director/Dy Director and other rooms -> Dean (Administration)/Assoc. Dean;
   Section 5 of the form lists Dean (R&D) for EDP participants and Dy. Director for institute guests. The app has no Director role, so the seed workflow is
   *Stage 1 EDC Admin (office verification: availability + room no.) -> Stage 2 Dean Admin* for both room types, with the suite stage clearly labelled a **placeholder**.
   Change it in Administration -> Approval workflow. Dean Admin therefore also holds `request.decide` (the brief listed Dean as view/manage-notices only) - revoke it under Permissions if not wanted.
3. **Category E(a) standard room** - no rate is given; the app shows "to be determined" instead of guessing. **E(c)** is "as applicable license fee" (no amount).
4. **Monthly rates (E(b))** - charged per started 30-day month; the form does not define proration. Prototype assumption, flagged on receipts.
5. **Category sub-type for B/C/D** - rates are identical across the sub-items, so only Category E asks for a sub-type.
6. Official **logo/crest** must be supplied by the institute (`assets/branding/logo.png`).
7. Children below 12 are excluded from the 2-persons-per-room limit, as the form's note says.
8. Online payment gateway: out of scope; the Simulate Payment action is a labelled prototype.

## Security notes
- RLS is enabled on every table; the anon role has no table access. Approval state can change only through `decide_request` / `set_request_status`.
- Exports go through security-definer functions that re-check `report.export` and omit phone, e-mail and address.
- Rotate any key that was ever shared in chat or committed. Only the **anon** key belongs in `env.json` (git-ignored).
