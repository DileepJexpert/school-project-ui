import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../services/school_website_service.dart';

/// Centralized data source for the school website.
///
/// On startup, [loadFromApi] fetches the school's website config from the
/// backend and populates all fields. Pages continue to read `SchoolData.xxx`
/// exactly as before — the only difference is the data is now dynamic.
class SchoolData {
  SchoolData._();

  static bool _loaded = false;
  static bool get isLoaded => _loaded;

  /// Loads website config from the backend for the given tenant.
  /// Falls back silently to defaults on error (so the site always renders).
  static Future<void> loadFromApi(String tenantId) async {
    try {
      final data = await SchoolWebsiteService.getPublicWebsite(tenantId);
      _applyFromJson(data);
      _syncAppStrings();
      _loaded = true;
    } catch (e) {
      debugPrint('[SchoolData] Failed to load website config for "$tenantId": $e');
    }
  }

  /// Applies website data from a JSON map (used by both loadFromApi and admin preview).
  static void applyFromJson(Map<String, dynamic> data) => _applyFromJson(data);

  static void _applyFromJson(Map<String, dynamic> d) {
    // ── Identity (also updates AppStrings via the static fields here) ──
    if (d['schoolName'] != null) schoolName = d['schoolName'] as String;
    if (d['shortName'] != null) shortName = d['shortName'] as String;
    if (d['tagline'] != null) tagline = d['tagline'] as String;
    if (d['accreditation'] != null) accreditation = d['accreditation'] as String;
    if (d['phone'] != null) contactPhone = d['phone'] as String;
    if (d['email'] != null) contactEmail = d['email'] as String;
    if (d['address'] != null) address = d['address'] as String;
    if (d['officeHours'] != null) officeHours = d['officeHours'] as String;
    if (d['founded'] != null) founded = d['founded'] as String;

    // ── Theme ──
    if (d['primaryColor'] != null) primaryColor = d['primaryColor'] as String;
    if (d['secondaryColor'] != null) secondaryColor = d['secondaryColor'] as String;
    if (d['logoUrl'] != null) logoUrl = d['logoUrl'] as String?;

    // ── Hero ──
    if (d['heroImageUrl'] != null) heroImageUrl = d['heroImageUrl'] as String?;
    if (d['marqueeText'] != null) marqueeText = d['marqueeText'] as String;

    // ── Principal ──
    if (d['principalName'] != null) principalName = d['principalName'] as String;
    if (d['principalTitle'] != null) principalTitle = d['principalTitle'] as String;
    if (d['principalMessage'] != null) principalMessage = d['principalMessage'] as String;
    if (d['principalImageUrl'] != null) principalImageUrl = d['principalImageUrl'] as String?;

    // ── About ──
    if (d['mission'] != null) mission = d['mission'] as String;
    if (d['vision'] != null) vision = d['vision'] as String;

    // ── Lists ──
    if (d['stats'] != null) {
      stats = (d['stats'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return StatItem(value: m['value'] ?? '', label: m['label'] ?? '');
      }).toList();
    }

    if (d['coreValues'] != null) {
      coreValues = (d['coreValues'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return ValueItem(icon: m['icon'] ?? 'star', title: m['title'] ?? '', description: m['description'] ?? '');
      }).toList();
    }

    if (d['achievements'] != null) {
      achievements = (d['achievements'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return Achievement(year: m['year'] ?? '', title: m['title'] ?? '');
      }).toList();
    }

    if (d['testimonials'] != null) {
      testimonials = (d['testimonials'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return Testimonial(name: m['name'] ?? '', relation: m['relation'] ?? '', text: m['text'] ?? '');
      }).toList();
    }

    if (d['events'] != null) {
      events = (d['events'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return EventItem(
          date: m['date'] ?? '', title: m['title'] ?? '',
          description: m['description'] ?? '', category: m['category'] ?? '',
          imagePath: m['imagePath'] as String?,
        );
      }).toList();
    }

    if (d['notices'] != null) {
      notices = (d['notices'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return NoticeItem(
          date: m['date'] ?? '', title: m['title'] ?? '',
          isHighPriority: m['isHighPriority'] == true || m['isHighPriority'] == 'true',
        );
      }).toList();
    }

    if (d['academicLevels'] != null) {
      academicLevels = (d['academicLevels'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        List<String> highlights = [];
        if (m['highlights'] is List) {
          highlights = (m['highlights'] as List).map((h) => h.toString()).toList();
        } else if (m['highlights'] is String) {
          highlights = (m['highlights'] as String).split('|');
        }
        return AcademicLevel(
          id: m['id'] ?? '', title: m['title'] ?? '',
          grades: m['grades'] ?? '', focus: m['focus'] ?? '',
          highlights: highlights,
        );
      }).toList();
    }

    if (d['coCurriculars'] != null) {
      coCurriculars = (d['coCurriculars'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return CoCurricular(icon: m['icon'] ?? 'star', name: m['name'] ?? '');
      }).toList();
    }

    if (d['feeStructure'] != null) {
      feeStructure = (d['feeStructure'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return FeeItem(
          grade: m['grade'] ?? '', admission: m['admission'] ?? '',
          tuition: m['tuition'] ?? '', annual: m['annual'] ?? '',
        );
      }).toList();
    }

    if (d['admissionSteps'] != null) {
      admissionSteps = (d['admissionSteps'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return AdmissionStep(
          step: int.tryParse(m['step']?.toString() ?? '') ?? 0,
          title: m['title'] ?? '', description: m['description'] ?? '',
        );
      }).toList();
    }

    if (d['importantDates'] != null) {
      importantDates = (d['importantDates'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return ImportantDate(event: m['event'] ?? '', date: m['date'] ?? '');
      }).toList();
    }

    if (d['galleryImages'] != null) {
      galleryImages = (d['galleryImages'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return GalleryItem(
          category: m['category'] ?? 'Campus', label: m['label'] ?? '',
          color: int.tryParse(m['color']?.toString() ?? '') ?? 0xFF2C5F8A,
          imagePath: m['imagePath'] as String?, imageUrl: m['imageUrl'] as String?,
        );
      }).toList();
    }

    if (d['transportZones'] != null) {
      transportZones = (d['transportZones'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return TransportZone(
          zone: m['zone'] ?? '', area: m['area'] ?? '',
          distance: m['distance'] ?? '', fee: m['fee'] ?? '',
        );
      }).toList();
    }

    if (d['transportFeatures'] != null) {
      transportFeatures = (d['transportFeatures'] as List).map((e) => e.toString()).toList();
    }

    if (d['timeline'] != null) {
      timeline = (d['timeline'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return HistoryEvent(year: m['year'] ?? '', text: m['text'] ?? '');
      }).toList();
    }
  }

  static void _syncAppStrings() {
    AppStrings.syncWith({
      'schoolName': schoolName,
      'shortName': shortName,
      'tagline': tagline,
      'accreditation': accreditation,
      'founded': founded,
      'phone': contactPhone,
      'email': contactEmail,
      'address': address,
      'officeHours': officeHours,
    });
  }

  // ── Identity ──
  static String schoolName = 'Springfield International Academy';
  static String shortName = 'SIA';
  static String tagline = 'Nurturing Minds, Building Futures';
  static String accreditation = 'CBSE Affiliated';
  static String founded = '1987';
  static String contactPhone = '+1 (555) 234-5678';
  static String contactEmail = 'admissions@springfieldacademy.edu';
  static String address = '42 Heritage Lane, Springfield, IL 62704';
  static String officeHours = 'Mon – Fri: 8:00 AM – 4:00 PM\nSat: 9:00 AM – 1:00 PM';

  // ── Theme ──
  static String primaryColor = '#1B3A5C';
  static String secondaryColor = '#C8922A';
  static String? logoUrl;

  // ── Hero ──
  static String? heroImageUrl;
  static String heroBannerImagePath = 'assets/images/home/hero_bg.jpg';
  static String marqueeText = '';

  // ── Principal ──
  static String principalName = 'Dr. Margaret Whitfield';
  static String principalTitle = 'Principal & Director';
  static String principalImagePath = 'assets/images/home/principal.jpg';
  static String? principalImageUrl;
  static String principalMessage =
      'At Springfield International Academy, we believe every child carries within them '
      'the potential to change the world. For over three decades, we have dedicated ourselves '
      'to fostering academic excellence, moral integrity, and creative thinking. Our approach '
      'combines time-honored educational values with modern pedagogical methods, ensuring our '
      'students are prepared not just for examinations, but for life itself.\n\n'
      'I invite you to explore what makes our school a second home for thousands of families.';

  // ── Mission & Vision ──
  static String mission =
      'To provide a holistic education that cultivates intellectual curiosity, '
      'ethical character, and global citizenship in every student.';
  static String vision =
      'To be a beacon of academic excellence and character formation, shaping '
      'leaders who contribute meaningfully to society.';

  // ── Quick Stats ──
  static List<StatItem> stats = [
    StatItem(value: 'Since 1987', label: 'Established'),
    StatItem(value: '2,400+', label: 'Students'),
    StatItem(value: '180+', label: 'Faculty'),
    StatItem(value: '15 Acre', label: 'Campus'),
  ];

  // ── Core Values ──
  static List<ValueItem> coreValues = [
    ValueItem(icon: 'book', title: 'Academic Excellence', description: 'Rigorous curriculum designed to challenge and inspire.'),
    ValueItem(icon: 'shield', title: 'Integrity', description: 'Building character rooted in honesty and responsibility.'),
    ValueItem(icon: 'globe', title: 'Global Perspective', description: 'Preparing students for an interconnected world.'),
    ValueItem(icon: 'heart', title: 'Compassion', description: 'Fostering empathy and service to community.'),
  ];

  // ── Achievements ──
  static List<Achievement> achievements = [
    Achievement(year: '2025', title: 'National Science Olympiad — 3 Gold Medals'),
    Achievement(year: '2024', title: 'Best School Award — State Education Board'),
    Achievement(year: '2024', title: '100% Pass Rate — Board Examinations'),
    Achievement(year: '2023', title: 'Inter-School Debate Championship — Winners'),
    Achievement(year: '2023', title: 'Green Campus Certification — Environmental Council'),
    Achievement(year: '2022', title: 'National Sports Meet — 5 Medals'),
  ];

  // ── Testimonials ──
  static List<Testimonial> testimonials = [
    Testimonial(name: 'Rajesh & Priya Sharma', relation: 'Parents of Ananya, Grade 10', text: 'Springfield Academy has been instrumental in shaping our daughter\'s confidence and academic abilities. The teachers go above and beyond.'),
    Testimonial(name: 'David Chen', relation: 'Alumnus, Class of 2020', text: 'The values and discipline I learned at SIA have been the foundation of my success at university. Forever grateful to my teachers.'),
    Testimonial(name: 'Sarah Mitchell', relation: 'Parent of James, Grade 4', text: 'The nurturing environment and individual attention each child receives is remarkable. James looks forward to school every single day.'),
    Testimonial(name: 'Aisha Patel', relation: 'Alumna, Class of 2022', text: 'From science fairs to drama productions, SIA gave me opportunities to discover my passions. The faculty truly cares about every student.'),
  ];

  // ── Events ──
  static List<EventItem> events = [
    EventItem(date: 'Mar 15, 2026', title: 'Annual Science Exhibition', description: 'Students from all grades showcase innovative science projects.', category: 'Academic', imagePath: 'assets/images/events/science_exhibition.jpg'),
    EventItem(date: 'Mar 22, 2026', title: 'Parent-Teacher Conference', description: 'Quarterly meeting to discuss student progress and development.', category: 'Meeting', imagePath: 'assets/images/events/parent_teacher.jpg'),
    EventItem(date: 'Apr 5, 2026', title: 'Inter-School Sports Meet', description: 'Annual athletics competition featuring track, field, and team sports.', category: 'Sports', imagePath: 'assets/images/events/sports_meet.jpg'),
    EventItem(date: 'Apr 18, 2026', title: 'Cultural Festival — Harmony 2026', description: 'Celebration of art, music, dance, and drama by students.', category: 'Cultural', imagePath: 'assets/images/events/cultural_festival.jpg'),
    EventItem(date: 'May 1, 2026', title: 'Admissions Open Day 2026-27', description: 'Campus tour, faculty interaction, and admissions guidance.', category: 'Admissions', imagePath: 'assets/images/events/admissions_day.jpg'),
    EventItem(date: 'May 20, 2026', title: 'Annual Day & Prize Distribution', description: 'Celebrating student achievements with awards and performances.', category: 'Ceremony', imagePath: 'assets/images/events/annual_day.jpg'),
  ];

  // ── Notices ──
  static List<NoticeItem> notices = [
    NoticeItem(date: 'Feb 20, 2026', title: 'Summer Uniform Transition — March 1st', isHighPriority: false),
    NoticeItem(date: 'Feb 18, 2026', title: 'Admissions 2026-27 — Applications Now Open', isHighPriority: true),
    NoticeItem(date: 'Feb 15, 2026', title: 'Annual Fee Revision Notice — Effective April', isHighPriority: false),
    NoticeItem(date: 'Feb 10, 2026', title: 'Holiday Notice: Holi — March 14th', isHighPriority: false),
  ];

  // ── Academics ──
  static List<AcademicLevel> academicLevels = [
    AcademicLevel(id: 'primary', title: 'Primary School', grades: 'Kindergarten – Grade 5', focus: 'Building strong foundations in literacy, numeracy, and social skills through experiential learning.', highlights: ['Phonics-based English program', 'Hands-on Math manipulatives', 'Environmental Studies through nature walks', 'Art, Music & Physical Education weekly', 'Library & Computer Lab sessions']),
    AcademicLevel(id: 'middle', title: 'Middle School', grades: 'Grade 6 – Grade 8', focus: 'Expanding horizons with structured academics, critical thinking, and co-curricular exploration.', highlights: ['Advanced Science with lab practicals', 'Introduction to Foreign Languages', 'Robotics & Coding electives', 'Inter-house competitions', 'Career awareness workshops']),
    AcademicLevel(id: 'senior', title: 'Senior School', grades: 'Grade 9 – Grade 12', focus: 'Preparing for board examinations and higher education with specialized streams and mentorship.', highlights: ['Science, Commerce & Humanities streams', 'Board exam preparation & mock tests', 'College counseling & career guidance', 'Research projects & internships', 'Leadership & community service programs']),
  ];

  static List<CoCurricular> coCurriculars = [
    CoCurricular(icon: 'science', name: 'Science Club'),
    CoCurricular(icon: 'music', name: 'Music & Band'),
    CoCurricular(icon: 'sports', name: 'Sports Academy'),
    CoCurricular(icon: 'art', name: 'Visual Arts'),
    CoCurricular(icon: 'globe', name: 'Model UN'),
    CoCurricular(icon: 'book', name: 'Literary Society'),
  ];

  // ── Fee Structure ──
  static List<FeeItem> feeStructure = [
    FeeItem(grade: 'Kindergarten (K1–K2)', admission: '15,000', tuition: '8,500 / month', annual: '1,02,000'),
    FeeItem(grade: 'Primary (Grade 1–5)', admission: '18,000', tuition: '9,200 / month', annual: '1,10,400'),
    FeeItem(grade: 'Middle (Grade 6–8)', admission: '20,000', tuition: '10,500 / month', annual: '1,26,000'),
    FeeItem(grade: 'Senior (Grade 9–10)', admission: '22,000', tuition: '12,000 / month', annual: '1,44,000'),
    FeeItem(grade: 'Senior (Grade 11–12)', admission: '25,000', tuition: '13,500 / month', annual: '1,62,000'),
  ];

  // ── Admission Steps ──
  static List<AdmissionStep> admissionSteps = [
    AdmissionStep(step: 1, title: 'Submit Application', description: 'Complete the online application form or download and submit a physical copy at the school office.'),
    AdmissionStep(step: 2, title: 'Entrance Assessment', description: 'Age-appropriate assessment to understand the student\'s academic readiness and aptitude.'),
    AdmissionStep(step: 3, title: 'Parent Interaction', description: 'A brief meeting with the admissions committee to discuss expectations and the school\'s philosophy.'),
    AdmissionStep(step: 4, title: 'Offer & Enrollment', description: 'Successful candidates receive an offer letter. Complete fee payment to confirm enrollment.'),
  ];

  // ── Important Dates ──
  static List<ImportantDate> importantDates = [
    ImportantDate(event: 'Applications Open', date: 'February 1, 2026'),
    ImportantDate(event: 'Entrance Assessments', date: 'March 15–20, 2026'),
    ImportantDate(event: 'Results Announced', date: 'March 28, 2026'),
    ImportantDate(event: 'Enrollment Deadline', date: 'April 15, 2026'),
    ImportantDate(event: 'Session Begins', date: 'June 1, 2026'),
  ];

  // ── Downloadable Forms ──
  static List<DownloadableForm> forms = [
    DownloadableForm(name: 'Application Form 2026-27', type: 'PDF', size: '245 KB'),
    DownloadableForm(name: 'Medical History Form', type: 'PDF', size: '128 KB'),
    DownloadableForm(name: 'Transfer Certificate Format', type: 'PDF', size: '98 KB'),
    DownloadableForm(name: 'Fee Structure Detailed', type: 'PDF', size: '312 KB'),
    DownloadableForm(name: 'Transport Registration Form', type: 'PDF', size: '156 KB'),
  ];

  // ── Gallery ──
  static List<String> galleryCategories = ['All', 'Campus', 'Events', 'Sports', 'Labs', 'Classroom'];
  static List<GalleryItem> galleryImages = [
    GalleryItem(category: 'Campus', label: 'Main Building Entrance', color: 0xFF2C5F8A, imagePath: 'assets/images/gallery/campus/main_entrance.jpg'),
    GalleryItem(category: 'Campus', label: 'School Courtyard', color: 0xFF3A7CA5, imagePath: 'assets/images/gallery/campus/courtyard.jpg'),
    GalleryItem(category: 'Campus', label: 'Library Wing', color: 0xFF4A8DB5, imagePath: 'assets/images/gallery/campus/library.jpg'),
    GalleryItem(category: 'Events', label: 'Annual Day 2025', color: 0xFF8A6D2C, imagePath: 'assets/images/gallery/events/annual_day_2025.jpg'),
    GalleryItem(category: 'Events', label: 'Science Exhibition', color: 0xFFA5883A, imagePath: 'assets/images/gallery/events/science_exhibition.jpg'),
    GalleryItem(category: 'Events', label: 'Cultural Festival', color: 0xFFB5984A, imagePath: 'assets/images/gallery/events/cultural_festival.jpg'),
    GalleryItem(category: 'Sports', label: 'Football Ground', color: 0xFF2C8A5F, imagePath: 'assets/images/gallery/sports/football_ground.jpg'),
    GalleryItem(category: 'Sports', label: 'Swimming Pool', color: 0xFF3AA57C, imagePath: 'assets/images/gallery/sports/swimming_pool.jpg'),
    GalleryItem(category: 'Sports', label: 'Basketball Court', color: 0xFF4AB58D, imagePath: 'assets/images/gallery/sports/basketball_court.jpg'),
    GalleryItem(category: 'Labs', label: 'Physics Laboratory', color: 0xFF5F2C8A, imagePath: 'assets/images/gallery/labs/physics_lab.jpg'),
    GalleryItem(category: 'Labs', label: 'Computer Lab', color: 0xFF7C3AA5, imagePath: 'assets/images/gallery/labs/computer_lab.jpg'),
    GalleryItem(category: 'Labs', label: 'Chemistry Lab', color: 0xFF8D4AB5, imagePath: 'assets/images/gallery/labs/chemistry_lab.jpg'),
    GalleryItem(category: 'Classroom', label: 'Smart Classroom', color: 0xFF8A2C5F, imagePath: 'assets/images/gallery/classroom/smart_classroom.jpg'),
    GalleryItem(category: 'Classroom', label: 'Kindergarten Room', color: 0xFFA53A7C, imagePath: 'assets/images/gallery/classroom/kindergarten_room.jpg'),
    GalleryItem(category: 'Classroom', label: 'Art Studio', color: 0xFFB54A8D, imagePath: 'assets/images/gallery/classroom/art_studio.jpg'),
  ];

  // ── Transport ──
  static List<TransportZone> transportZones = [
    TransportZone(zone: 'Zone A', area: 'Downtown, Civic Center, Old Town', distance: '0–5 km', fee: '2,500 / month'),
    TransportZone(zone: 'Zone B', area: 'Westfield, Maple Heights, Oakwood', distance: '5–10 km', fee: '3,200 / month'),
    TransportZone(zone: 'Zone C', area: 'Riverside, Greenville, Lakewood', distance: '10–15 km', fee: '3,800 / month'),
    TransportZone(zone: 'Zone D', area: 'Hillcrest, Northgate, Sunnyvale', distance: '15–20 km', fee: '4,500 / month'),
  ];

  static List<String> transportFeatures = [
    'GPS-tracked buses with real-time parent app',
    'Trained drivers with 10+ years experience',
    'Female attendant on every bus',
    'First-aid kit and fire extinguisher equipped',
    'CCTV surveillance on all vehicles',
    'Speed governor limited to 40 km/h',
  ];

  // ── History Timeline ──
  static List<HistoryEvent> timeline = [
    HistoryEvent(year: '1987', text: 'Founded with 120 students and a vision'),
    HistoryEvent(year: '1995', text: 'Expanded to full K-12 curriculum'),
    HistoryEvent(year: '2005', text: 'New campus inaugurated on 15-acre site'),
    HistoryEvent(year: '2015', text: 'CBSE affiliation and smart classrooms'),
    HistoryEvent(year: '2024', text: 'Crossed 2,400 students milestone'),
  ];
}

// ── Data Models ──

class StatItem {
  final String value;
  final String label;
  const StatItem({required this.value, required this.label});
}

class ValueItem {
  final String icon;
  final String title;
  final String description;
  const ValueItem({required this.icon, required this.title, required this.description});
}

class Achievement {
  final String year;
  final String title;
  const Achievement({required this.year, required this.title});
}

class Testimonial {
  final String name;
  final String relation;
  final String text;
  const Testimonial({required this.name, required this.relation, required this.text});
}

class EventItem {
  final String date;
  final String title;
  final String description;
  final String category;
  final String? imagePath;
  const EventItem({required this.date, required this.title, required this.description, required this.category, this.imagePath});
}

class NoticeItem {
  final String date;
  final String title;
  final bool isHighPriority;
  const NoticeItem({required this.date, required this.title, required this.isHighPriority});
}

class AcademicLevel {
  final String id;
  final String title;
  final String grades;
  final String focus;
  final List<String> highlights;
  const AcademicLevel({required this.id, required this.title, required this.grades, required this.focus, required this.highlights});
}

class CoCurricular {
  final String icon;
  final String name;
  const CoCurricular({required this.icon, required this.name});
}

class FeeItem {
  final String grade;
  final String admission;
  final String tuition;
  final String annual;
  const FeeItem({required this.grade, required this.admission, required this.tuition, required this.annual});
}

class AdmissionStep {
  final int step;
  final String title;
  final String description;
  const AdmissionStep({required this.step, required this.title, required this.description});
}

class ImportantDate {
  final String event;
  final String date;
  const ImportantDate({required this.event, required this.date});
}

class DownloadableForm {
  final String name;
  final String type;
  final String size;
  const DownloadableForm({required this.name, required this.type, required this.size});
}

class GalleryItem {
  final String category;
  final String label;
  final int color;
  final String? imagePath;
  final String? imageUrl;
  const GalleryItem({required this.category, required this.label, required this.color, this.imagePath, this.imageUrl});
}

class TransportZone {
  final String zone;
  final String area;
  final String distance;
  final String fee;
  const TransportZone({required this.zone, required this.area, required this.distance, required this.fee});
}

class HistoryEvent {
  final String year;
  final String text;
  const HistoryEvent({required this.year, required this.text});
}
