# Springfield International Academy — Flutter School Website

## Production-Grade Flutter Web + Mobile School Website

### Architecture
```
lib/
├── main.dart                          # Entry point (initializes DioClient + AuthService)
├── core/
│   ├── constants/app_constants.dart   # Colors, sizes, strings
│   ├── theme/app_theme.dart           # Navy & Gold Material 3 theme
│   ├── router/app_router.dart         # Centralized routing + auth guard
│   └── widgets/
│       ├── app_shell.dart             # Navbar + Footer + Marquee (wraps all pages)
│       ├── shared_widgets.dart        # Reusable section components
│       └── responsive.dart            # Breakpoint utilities
├── models/
│   ├── school_data.dart               # Content data
│   └── auth_models.dart               # AuthUser, AuthResponse, UserRole constants
├── services/
│   ├── dio_client.dart                # HTTP client — injects JWT + X-Tenant-ID on every request
│   └── auth_service.dart              # Login, logout, token storage, role/permission checks
└── features/
    ├── auth/login_page.dart           # Login UI (school code → email → password)
    ├── home/home_page.dart
    ├── about/about_page.dart
    ├── academics/academics_page.dart
    ├── admissions/admissions_page.dart
    ├── gallery/gallery_page.dart
    ├── events/events_page.dart
    ├── transport/transport_page.dart
    ├── contact/contact_page.dart
    ├── results/results_page.dart
    └── admin/admin_dashboard_page.dart # Role-filtered sidebar + logout
```

---

## Tech Stack
- **Frontend**: Flutter 3.x (Web + Mobile from single codebase)
- **Backend**: Java Spring Boot (REST API) — connected via `DioClient`
- **Auth**: JWT Bearer token (stored in SharedPreferences, auto-refreshed on 401)
- **Theme**: Navy Blue (#1B3A5C) + Gold (#C8922A)
- **Fonts**: Cormorant Garamond (headings) + Nunito Sans (body)
- **State**: setState (upgrade to Riverpod/Bloc as complexity grows)

---

## Quick Start

```bash
flutter pub get
flutter run -d chrome        # Web
flutter run -d android       # Android
flutter run -d ios           # iOS
```

### Point to a Custom Backend URL

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://your-api.com/api
```

---

## Login & Authentication — Testing Guide

### Login Page Flow

1. Enter your **School Code** (e.g. `springfield`) and click **Verify**
2. Enter **Email** and **Password**
3. Click **Sign In** — JWT is stored locally and injected on every API request
4. Redirected to **Admin Dashboard** with role-filtered sidebar

### Credentials for Testing

#### Option A — Super Admin (works immediately, no setup needed)

1. Toggle **"Platform Admin login"** switch ON
2. Use these credentials:

```
Email:    superadmin@platform.com
Password: SuperAdmin@123
```

> Super Admin has access to all menus and all features.

#### Option B — School Admin (requires backend setup first)

First complete the backend setup steps (register school + create user via API — see backend README), then:

```
School Code: springfield
Email:       admin@springfield.com
Password:    Admin@123
```

### Role-Based Menu Access

After login, the sidebar shows only menus relevant to the user's role:

| Role | Visible Menus |
|------|--------------|
| `SUPER_ADMIN` / `SCHOOL_ADMIN` | All menus |
| `TEACHER` | Overview, Students, Attendance, Timetable, Results, Notifications |
| `ACCOUNTANT` | Overview, Students, Fees, Expenses, Reports |
| `TRANSPORT_MANAGER` | Overview, Students, Transport |
| `STUDENT` / `PARENT` | Overview only |

### Logout

Click **Logout** at the bottom of the sidebar. Clears the stored JWT and redirects to the login page.

---

## Pages Overview

| Page | Route | Auth Required | Status |
|------|-------|---------------|--------|
| Home | `/` | No | ✅ Complete |
| About | `/about` | No | ✅ Complete |
| Academics | `/academics` | No | ✅ Complete |
| Admissions | `/admissions` | No | ✅ Complete |
| Gallery | `/gallery` | No | ✅ Complete |
| Events | `/events` | No | ✅ Complete |
| Transport | `/transport` | No | ✅ Complete |
| Contact | `/contact` | No | ✅ Complete |
| Results | `/results` | No | ✅ Complete |
| **Login** | `/login` | No | ✅ Complete |
| **Admin Dashboard** | `/admin-dashboard` | **Yes** (redirects to `/login`) | ✅ Complete |

---

## Key Design Decisions

- **AppShell pattern**: Every public page wrapped in `AppShell` (Navbar, Footer, Marquee)
- **Auth guard**: `/admin-dashboard` redirects to `/login` if no valid JWT in memory
- **JWT auto-refresh**: `DioClient` retries failed requests after refreshing the access token on 401
- **Role filtering**: `AuthService.canAccessMenu()` controls sidebar visibility per role
- **Extensible roles**: Add a new role constant in `auth_models.dart` → add a case in `AuthService.canAccessMenu()` → done
- **Responsive**: 3-tier breakpoints (mobile/tablet/desktop) via `Responsive` utility
