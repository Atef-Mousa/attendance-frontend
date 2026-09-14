# Attendance System — Frontend (Flutter Web)

A Flutter Web app for the OTP-based attendance system. Instructors
manage courses and lecture sessions; students log in and submit an OTP
to mark themselves present in real time.

## Tech Stack
- **Framework:** Flutter (Web target)
- **HTTP:** `http` package
- **Local storage:** `shared_preferences` (stores the JWT token and
  last-known OTP per course)
- **Deployment:** [Cloudflare Pages](https://pages.cloudflare.com)

## Live Deployment
- App URL: `https://your-project.pages.dev`
- Depends on the backend API deployed separately (see `config.dart`).

## Project Structure
```
lib/
├── main.dart              Login screen, JWT parsing, route table,
│                          redirect-if-already-logged-in logic
├── admin.dart             Instructor dashboard: course list, start/stop
│                          session, view saved OTP
├── active_student.dart    Student screen: OTP submission, logout
├── register_student.dart  Student self-registration form
├── route_guard.dart       Role-based route protection + session-expiry
│                          watcher (auto-redirects on token expiry)
├── create_course.dart     Instructor: create a new course
└── config.dart            Single source of truth for the backend base URL
```

## Configuration
Before building, set the backend URL in `lib/config.dart`:
```dart
const String baseUrl = 'https://attendance-backend-6zpt.onrender.com';
```
For local development against a local backend, change this to
`http://127.0.0.1:8000`.

## Running Locally
```bash
flutter pub get
flutter run -d chrome
```

## Building for Production
```bash
flutter build web --release
```
Output is written to `build/web`. A `_redirects` file lives in the
`web/` source folder (`web/_redirects`) so client-side routes survive
a browser refresh when deployed:
```
/*    /index.html   200
```

## Deployment (Cloudflare Pages)
- **Build command:**
  ```
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 && export PATH="$PATH:`pwd`/flutter/bin" && flutter pub get && flutter build web --release
  ```
- **Build output directory:** `build/web`

Cloudflare Pages rebuilds automatically on every push to `main`.

## Roles & Screens
| Role | Route | Notes |
|---|---|---|
| Instructor | `/activate_teacher` | Course list, start/stop sessions, view OTP |
| Student | `/activate_student` | Submit OTP, logout |
| Anyone | `/register_student` | Self-registration (students only) |

Instructor accounts are currently created manually (directly in the
database), not through the app.

## Known Limitations
- Flutter Web's default renderer (CanvasKit) fetches its rendering
  engine from Google's CDN at runtime — this requires an internet
  connection even when testing "locally," but is not an issue for real
  deployed users, who already need internet to load the app itself.
- Login/logout for students is blocked while any instructor has an
  active lecture session running anywhere in the system (see backend
  README for details on this limitation).

## Related Repo
Backend (FastAPI): see the companion `attendance-backend` repository.
