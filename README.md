# Springfield International Academy — Flutter School Website

## Production-Grade Flutter Web + Mobile School Website

### Architecture
```
lib/
├── main.dart                          # Entry point
├── core/
│   ├── constants/app_constants.dart   # Colors, sizes, strings
│   ├── theme/app_theme.dart           # Navy & Gold Material 3 theme
│   ├── router/app_router.dart         # Centralized routing
│   └── widgets/
│       ├── app_shell.dart             # Navbar + Footer + Marquee (wraps all pages)
│       ├── shared_widgets.dart        # Reusable section components
│       └── responsive.dart            # Breakpoint utilities
├── models/
│   └── school_data.dart               # All content data + models (swap with API later)
├── services/
│   └── dio_client.dart                # HTTP client for Spring Boot API
└── features/
    ├── home/home_page.dart            # Hero, Stats, Principal, Achievements, Testimonials
    ├── about/about_page.dart          # Mission, Vision, Timeline, Values
    ├── academics/academics_page.dart  # Tab-based K-5, 6-8, 9-12 + Co-curriculars
    ├── admissions/admissions_page.dart# Process, Dates, Forms, Fee Table
    ├── gallery/gallery_page.dart      # Filterable photo grid
    ├── events/events_page.dart        # Notice board + Event cards
    ├── transport/transport_page.dart   # Zone table + Safety features
    ├── contact/contact_page.dart      # Inquiry form + Contact details
    ├── results/results_page.dart      # Public results viewer
    └── admin/admin_dashboard_page.dart# Admin panel with sidebar navigation
```

### Tech Stack
- **Frontend**: Flutter 3.x (Web + Mobile from single codebase)
- **Backend**: Java Spring Boot (REST API) — connect via `DioClient`
- **Theme**: Navy Blue (#1B3A5C) + Gold (#C8922A)
- **Fonts**: Cormorant Garamond (headings) + Nunito Sans (body)
- **State**: setState (upgrade to Riverpod/Bloc as complexity grows)

### Quick Start
```bash
flutter pub get
flutter run -d chrome        # Web
flutter run -d android       # Android
flutter run -d ios            # iOS
```

### Deployment
```bash
flutter build web --release
# Deploy build/web/ to Firebase Hosting, Vercel, Netlify, etc.
```

### Spring Boot Integration Guide

1. **Update API URL** in `lib/services/dio_client.dart`:
   ```dart
   static const String _baseUrl = 'https://your-api.com/api/v1';
   ```

2. **Replace static data** in `lib/models/school_data.dart` with API calls:
   ```dart
   // Before (static):
   static final List<EventItem> events = [...];

   // After (API):
   static Future<List<EventItem>> fetchEvents() async {
     final response = await DioClient.get('/events');
     return (response.data as List).map((e) => EventItem.fromJson(e)).toList();
   }
   ```

3. **Add authentication** for admin routes in `dio_client.dart` interceptor.

### Pages Overview
| Page | Route | Status |
|------|-------|--------|
| Home | `/` | ✅ Complete |
| About | `/about` | ✅ Complete |
| Academics | `/academics` | ✅ Complete |
| Admissions | `/admissions` | ✅ Complete |
| Gallery | `/gallery` | ✅ Complete |
| Events | `/events` | ✅ Complete |
| Transport | `/transport` | ✅ Complete |
| Contact | `/contact` | ✅ Complete |
| Results | `/results` | ✅ Complete |
| Admin Dashboard | `/admin-dashboard` | ✅ Scaffold Ready |

### Key Design Decisions
- **AppShell pattern**: Every public page is wrapped in `AppShell` which provides consistent Navbar, Footer, and Marquee banner
- **ContentContainer**: All page content is constrained to 1200px max width
- **Feature-based folders**: Each page is self-contained in its feature folder
- **SchoolData**: Single source of truth for all content — trivial to swap with API
- **Responsive**: 3-tier breakpoints (mobile/tablet/desktop) via `Responsive` utility
