import '../core/constants/app_constants.dart';
import '../services/dio_client.dart';

/// Public website content loaded from the Python backend before the app starts.

class SchoolData {
  SchoolData._();
  static String? loadError;

  // --- Principal ---
  static String principalName = '';
  static String principalTitle = '';
  /// Replace this path with your principal's photo.
  static String principalImagePath = '';
  /// School building / campus banner used on the hero section.
  static String heroBannerImagePath = '';
  static String principalMessage =
      'At Springfield International Academy, we believe every child carries within them '
      'the potential to change the world. For over three decades, we have dedicated ourselves '
      'to fostering academic excellence, moral integrity, and creative thinking. Our approach '
      'combines time-honored educational values with modern pedagogical methods, ensuring our '
      'students are prepared not just for examinations, but for life itself.\n\n'
      'I invite you to explore what makes our school a second home for thousands of families.';

  // --- Mission & Vision ---
  static String mission =
      'To provide a holistic education that cultivates intellectual curiosity, '
      'ethical character, and global citizenship in every student.';
  static String vision =
      'To be a beacon of academic excellence and character formation, shaping '
      'leaders who contribute meaningfully to society.';
  static String admissionCtaTitle = 'Admissions Open for Academic Year 2026-27';
  static String admissionCtaSubtitle =
      'Begin your child\'s transformative educational journey with us. Applications invited for Nursery to Grade 11.';
  static String feeStructureTitle = 'Fee Structure';
  static String feeStructureNote =
      '* Transport and optional meal plans billed separately. Sibling concessions available.';
  static String mapUrl = '';
  static String facebookUrl = '';

  // --- Quick Stats ---
  static final List<StatItem> stats = [
    StatItem(value: 'Since 1987', label: 'Established'),
    StatItem(value: '2,400+', label: 'Students'),
    StatItem(value: '180+', label: 'Faculty'),
    StatItem(value: '15 Acre', label: 'Campus'),
  ];

  // --- Core Values ---
  static final List<ValueItem> coreValues = [
    ValueItem(icon: 'book', title: 'Academic Excellence', description: 'Rigorous curriculum designed to challenge and inspire.'),
    ValueItem(icon: 'shield', title: 'Integrity', description: 'Building character rooted in honesty and responsibility.'),
    ValueItem(icon: 'globe', title: 'Global Perspective', description: 'Preparing students for an interconnected world.'),
    ValueItem(icon: 'heart', title: 'Compassion', description: 'Fostering empathy and service to community.'),
  ];

  // --- Achievements ---
  static final List<Achievement> achievements = [
    Achievement(year: '2025', title: 'National Science Olympiad — 3 Gold Medals'),
    Achievement(year: '2024', title: 'Best School Award — State Education Board'),
    Achievement(year: '2024', title: '100% Pass Rate — Board Examinations'),
    Achievement(year: '2023', title: 'Inter-School Debate Championship — Winners'),
    Achievement(year: '2023', title: 'Green Campus Certification — Environmental Council'),
    Achievement(year: '2022', title: 'National Sports Meet — 5 Medals'),
  ];

  // --- Testimonials ---
  static final List<Testimonial> testimonials = [
    Testimonial(
      name: 'Rajesh & Priya Sharma',
      relation: 'Parents of Ananya, Grade 10',
      text: 'Springfield Academy has been instrumental in shaping our daughter\'s confidence and academic abilities. The teachers go above and beyond.',
    ),
    Testimonial(
      name: 'David Chen',
      relation: 'Alumnus, Class of 2020',
      text: 'The values and discipline I learned at SIA have been the foundation of my success at university. Forever grateful to my teachers.',
    ),
    Testimonial(
      name: 'Sarah Mitchell',
      relation: 'Parent of James, Grade 4',
      text: 'The nurturing environment and individual attention each child receives is remarkable. James looks forward to school every single day.',
    ),
    Testimonial(
      name: 'Aisha Patel',
      relation: 'Alumna, Class of 2022',
      text: 'From science fairs to drama productions, SIA gave me opportunities to discover my passions. The faculty truly cares about every student.',
    ),
  ];

  // --- Events ---
  static final List<EventItem> events = [
    EventItem(date: 'Mar 15, 2026', title: 'Annual Science Exhibition',      description: 'Students from all grades showcase innovative science projects.',         category: 'Academic',   imagePath: 'assets/images/events/science_exhibition.jpg'),
    EventItem(date: 'Mar 22, 2026', title: 'Parent-Teacher Conference',      description: 'Quarterly meeting to discuss student progress and development.',         category: 'Meeting',    imagePath: 'assets/images/events/parent_teacher.jpg'),
    EventItem(date: 'Apr 5, 2026',  title: 'Inter-School Sports Meet',       description: 'Annual athletics competition featuring track, field, and team sports.', category: 'Sports',     imagePath: 'assets/images/events/sports_meet.jpg'),
    EventItem(date: 'Apr 18, 2026', title: 'Cultural Festival — Harmony 2026', description: 'Celebration of art, music, dance, and drama by students.',           category: 'Cultural',   imagePath: 'assets/images/events/cultural_festival.jpg'),
    EventItem(date: 'May 1, 2026',  title: 'Admissions Open Day 2026-27',    description: 'Campus tour, faculty interaction, and admissions guidance.',            category: 'Admissions', imagePath: 'assets/images/events/admissions_day.jpg'),
    EventItem(date: 'May 20, 2026', title: 'Annual Day & Prize Distribution', description: 'Celebrating student achievements with awards and performances.',        category: 'Ceremony',   imagePath: 'assets/images/events/annual_day.jpg'),
  ];

  // --- Notices ---
  static final List<NoticeItem> notices = [
    NoticeItem(date: 'Feb 20, 2026', title: 'Summer Uniform Transition — March 1st', isHighPriority: false),
    NoticeItem(date: 'Feb 18, 2026', title: 'Admissions 2026-27 — Applications Now Open', isHighPriority: true),
    NoticeItem(date: 'Feb 15, 2026', title: 'Annual Fee Revision Notice — Effective April', isHighPriority: false),
    NoticeItem(date: 'Feb 10, 2026', title: 'Holiday Notice: Holi — March 14th', isHighPriority: false),
  ];

  // --- Academics ---
  static final List<AcademicLevel> academicLevels = [
    AcademicLevel(
      id: 'primary',
      title: 'Primary School',
      grades: 'Kindergarten – Grade 5',
      focus: 'Building strong foundations in literacy, numeracy, and social skills through experiential learning.',
      highlights: [
        'Phonics-based English program',
        'Hands-on Math manipulatives',
        'Environmental Studies through nature walks',
        'Art, Music & Physical Education weekly',
        'Library & Computer Lab sessions',
      ],
    ),
    AcademicLevel(
      id: 'middle',
      title: 'Middle School',
      grades: 'Grade 6 – Grade 8',
      focus: 'Expanding horizons with structured academics, critical thinking, and co-curricular exploration.',
      highlights: [
        'Advanced Science with lab practicals',
        'Introduction to Foreign Languages',
        'Robotics & Coding electives',
        'Inter-house competitions',
        'Career awareness workshops',
      ],
    ),
    AcademicLevel(
      id: 'senior',
      title: 'Senior School',
      grades: 'Grade 9 – Grade 12',
      focus: 'Preparing for board examinations and higher education with specialized streams and mentorship.',
      highlights: [
        'Science, Commerce & Humanities streams',
        'Board exam preparation & mock tests',
        'College counseling & career guidance',
        'Research projects & internships',
        'Leadership & community service programs',
      ],
    ),
  ];

  static final List<CoCurricular> coCurriculars = [
    CoCurricular(icon: 'science', name: 'Science Club'),
    CoCurricular(icon: 'music', name: 'Music & Band'),
    CoCurricular(icon: 'sports', name: 'Sports Academy'),
    CoCurricular(icon: 'art', name: 'Visual Arts'),
    CoCurricular(icon: 'globe', name: 'Model UN'),
    CoCurricular(icon: 'book', name: 'Literary Society'),
  ];

  // --- Fee Structure ---
  static final List<FeeItem> feeStructure = [
    FeeItem(grade: 'Kindergarten (K1–K2)', admission: '15,000', tuition: '8,500 / month', annual: '1,02,000'),
    FeeItem(grade: 'Primary (Grade 1–5)', admission: '18,000', tuition: '9,200 / month', annual: '1,10,400'),
    FeeItem(grade: 'Middle (Grade 6–8)', admission: '20,000', tuition: '10,500 / month', annual: '1,26,000'),
    FeeItem(grade: 'Senior (Grade 9–10)', admission: '22,000', tuition: '12,000 / month', annual: '1,44,000'),
    FeeItem(grade: 'Senior (Grade 11–12)', admission: '25,000', tuition: '13,500 / month', annual: '1,62,000'),
  ];

  // --- Admission Steps ---
  static final List<AdmissionStep> admissionSteps = [
    AdmissionStep(step: 1, title: 'Submit Application', description: 'Complete the online application form or download and submit a physical copy at the school office.'),
    AdmissionStep(step: 2, title: 'Entrance Assessment', description: 'Age-appropriate assessment to understand the student\'s academic readiness and aptitude.'),
    AdmissionStep(step: 3, title: 'Parent Interaction', description: 'A brief meeting with the admissions committee to discuss expectations and the school\'s philosophy.'),
    AdmissionStep(step: 4, title: 'Offer & Enrollment', description: 'Successful candidates receive an offer letter. Complete fee payment to confirm enrollment.'),
  ];

  // --- Important Dates ---
  static final List<ImportantDate> importantDates = [
    ImportantDate(event: 'Applications Open', date: 'February 1, 2026'),
    ImportantDate(event: 'Entrance Assessments', date: 'March 15–20, 2026'),
    ImportantDate(event: 'Results Announced', date: 'March 28, 2026'),
    ImportantDate(event: 'Enrollment Deadline', date: 'April 15, 2026'),
    ImportantDate(event: 'Session Begins', date: 'June 1, 2026'),
  ];

  // --- Downloadable Forms ---
  static final List<DownloadableForm> forms = [
    DownloadableForm(name: 'Application Form 2026-27', type: 'PDF', size: '245 KB'),
    DownloadableForm(name: 'Medical History Form', type: 'PDF', size: '128 KB'),
    DownloadableForm(name: 'Transfer Certificate Format', type: 'PDF', size: '98 KB'),
    DownloadableForm(name: 'Fee Structure Detailed', type: 'PDF', size: '312 KB'),
    DownloadableForm(name: 'Transport Registration Form', type: 'PDF', size: '156 KB'),
  ];

  // --- Gallery ---
  static final List<String> galleryCategories = ['All', 'Campus', 'Events', 'Sports', 'Labs', 'Classroom'];
  static final List<GalleryItem> galleryImages = [
    GalleryItem(category: 'Campus',    label: 'Main Building Entrance', color: 0xFF2C5F8A, imagePath: 'assets/images/gallery/campus/main_entrance.jpg'),
    GalleryItem(category: 'Campus',    label: 'School Courtyard',       color: 0xFF3A7CA5, imagePath: 'assets/images/gallery/campus/courtyard.jpg'),
    GalleryItem(category: 'Campus',    label: 'Library Wing',           color: 0xFF4A8DB5, imagePath: 'assets/images/gallery/campus/library.jpg'),
    GalleryItem(category: 'Events',    label: 'Annual Day 2025',        color: 0xFF8A6D2C, imagePath: 'assets/images/gallery/events/annual_day_2025.jpg'),
    GalleryItem(category: 'Events',    label: 'Science Exhibition',     color: 0xFFA5883A, imagePath: 'assets/images/gallery/events/science_exhibition.jpg'),
    GalleryItem(category: 'Events',    label: 'Cultural Festival',      color: 0xFFB5984A, imagePath: 'assets/images/gallery/events/cultural_festival.jpg'),
    GalleryItem(category: 'Sports',    label: 'Football Ground',        color: 0xFF2C8A5F, imagePath: 'assets/images/gallery/sports/football_ground.jpg'),
    GalleryItem(category: 'Sports',    label: 'Swimming Pool',          color: 0xFF3AA57C, imagePath: 'assets/images/gallery/sports/swimming_pool.jpg'),
    GalleryItem(category: 'Sports',    label: 'Basketball Court',       color: 0xFF4AB58D, imagePath: 'assets/images/gallery/sports/basketball_court.jpg'),
    GalleryItem(category: 'Labs',      label: 'Physics Laboratory',     color: 0xFF5F2C8A, imagePath: 'assets/images/gallery/labs/physics_lab.jpg'),
    GalleryItem(category: 'Labs',      label: 'Computer Lab',           color: 0xFF7C3AA5, imagePath: 'assets/images/gallery/labs/computer_lab.jpg'),
    GalleryItem(category: 'Labs',      label: 'Chemistry Lab',          color: 0xFF8D4AB5, imagePath: 'assets/images/gallery/labs/chemistry_lab.jpg'),
    GalleryItem(category: 'Classroom', label: 'Smart Classroom',        color: 0xFF8A2C5F, imagePath: 'assets/images/gallery/classroom/smart_classroom.jpg'),
    GalleryItem(category: 'Classroom', label: 'Kindergarten Room',      color: 0xFFA53A7C, imagePath: 'assets/images/gallery/classroom/kindergarten_room.jpg'),
    GalleryItem(category: 'Classroom', label: 'Art Studio',             color: 0xFFB54A8D, imagePath: 'assets/images/gallery/classroom/art_studio.jpg'),
  ];

  // --- Transport ---
  static final List<TransportZone> transportZones = [
    TransportZone(zone: 'Zone A', area: 'Downtown, Civic Center, Old Town', distance: '0–5 km', fee: '2,500 / month'),
    TransportZone(zone: 'Zone B', area: 'Westfield, Maple Heights, Oakwood', distance: '5–10 km', fee: '3,200 / month'),
    TransportZone(zone: 'Zone C', area: 'Riverside, Greenville, Lakewood', distance: '10–15 km', fee: '3,800 / month'),
    TransportZone(zone: 'Zone D', area: 'Hillcrest, Northgate, Sunnyvale', distance: '15–20 km', fee: '4,500 / month'),
  ];

  static final List<String> transportFeatures = [
    'GPS-tracked buses with real-time parent app',
    'Trained drivers with 10+ years experience',
    'Female attendant on every bus',
    'First-aid kit and fire extinguisher equipped',
    'CCTV surveillance on all vehicles',
    'Speed governor limited to 40 km/h',
  ];

  // --- History Timeline ---
  static final List<HistoryEvent> timeline = [
    HistoryEvent(year: '1987', text: 'Founded with 120 students and a vision'),
    HistoryEvent(year: '1995', text: 'Expanded to full K-12 curriculum'),
    HistoryEvent(year: '2005', text: 'New campus inaugurated on 15-acre site'),
    HistoryEvent(year: '2015', text: 'CBSE affiliation and smart classrooms'),
    HistoryEvent(year: '2024', text: 'Crossed 2,400 students milestone'),
  ];

  static String _text(Map<String, dynamic> row, String key) =>
      row[key]?.toString() ?? '';

  static List<Map<String, dynamic>> _rows(Map<String, dynamic> data, String key) =>
      (data[key] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();


  static void _clearPreviewContent() {
    AppStrings.schoolName = 'School';
    AppStrings.schoolShortName = 'School';
    AppStrings.tagline = '';
    AppStrings.accreditation = '';
    AppStrings.founded = '';
    AppStrings.phone = '';
    AppStrings.email = '';
    AppStrings.address = '';
    AppStrings.officeHours = '';
    AppStrings.announcement = '';
    principalName = '';
    principalTitle = '';
    principalImagePath = '';
    heroBannerImagePath = '';
    principalMessage = '';
    mission = '';
    vision = '';
    admissionCtaTitle = '';
    admissionCtaSubtitle = '';
    feeStructureTitle = '';
    feeStructureNote = '';
    mapUrl = '';
    facebookUrl = '';
    stats.clear();
    coreValues.clear();
    achievements.clear();
    testimonials.clear();
    events.clear();
    notices.clear();
    academicLevels.clear();
    coCurriculars.clear();
    feeStructure.clear();
    admissionSteps.clear();
    importantDates.clear();
    forms.clear();
    galleryCategories
      ..clear()
      ..add('All');
    galleryImages.clear();
    transportZones.clear();
    transportFeatures.clear();
    timeline.clear();
  }

  static Future<void> load() async {
    loadError = null;
    try {
      final response = await DioClient.get('/site-content');
      final data = Map<String, dynamic>.from(response.data as Map);
      _clearPreviewContent();
      if (_text(data, 'schoolName').isNotEmpty) AppStrings.schoolName = _text(data, 'schoolName');
      if (_text(data, 'schoolShortName').isNotEmpty) AppStrings.schoolShortName = _text(data, 'schoolShortName');
      if (_text(data, 'tagline').isNotEmpty) AppStrings.tagline = _text(data, 'tagline');
      if (_text(data, 'accreditation').isNotEmpty) AppStrings.accreditation = _text(data, 'accreditation');
      if (_text(data, 'founded').isNotEmpty) AppStrings.founded = _text(data, 'founded');
      if (_text(data, 'phone').isNotEmpty) AppStrings.phone = _text(data, 'phone');
      if (_text(data, 'email').isNotEmpty) AppStrings.email = _text(data, 'email');
      if (_text(data, 'address').isNotEmpty) AppStrings.address = _text(data, 'address');
      if (_text(data, 'officeHours').isNotEmpty) AppStrings.officeHours = _text(data, 'officeHours');
      if (_text(data, 'announcement').isNotEmpty) AppStrings.announcement = _text(data, 'announcement');
      if (_text(data, 'principalName').isNotEmpty) principalName = _text(data, 'principalName');
      if (_text(data, 'principalTitle').isNotEmpty) principalTitle = _text(data, 'principalTitle');
      if (_text(data, 'principalImagePath').isNotEmpty) principalImagePath = _text(data, 'principalImagePath');
      if (_text(data, 'heroBannerImagePath').isNotEmpty) heroBannerImagePath = _text(data, 'heroBannerImagePath');
      if (_text(data, 'principalMessage').isNotEmpty) principalMessage = _text(data, 'principalMessage');
      if (_text(data, 'mission').isNotEmpty) mission = _text(data, 'mission');
      if (_text(data, 'vision').isNotEmpty) vision = _text(data, 'vision');
      if (_text(data, 'admissionCtaTitle').isNotEmpty) admissionCtaTitle = _text(data, 'admissionCtaTitle');
      if (_text(data, 'admissionCtaSubtitle').isNotEmpty) admissionCtaSubtitle = _text(data, 'admissionCtaSubtitle');
      if (_text(data, 'feeStructureTitle').isNotEmpty) feeStructureTitle = _text(data, 'feeStructureTitle');
      if (_text(data, 'feeStructureNote').isNotEmpty) feeStructureNote = _text(data, 'feeStructureNote');
      if (_text(data, 'mapUrl').isNotEmpty) mapUrl = _text(data, 'mapUrl');
      if (_text(data, 'facebookUrl').isNotEmpty) facebookUrl = _text(data, 'facebookUrl');

      final rStats = _rows(data, 'stats');
      if (rStats.isNotEmpty) {
        stats.clear();
        stats.addAll(rStats.map((r) => StatItem(value: _text(r, 'value'), label: _text(r, 'label'))));
      }
      final rValues = _rows(data, 'coreValues');
      if (rValues.isNotEmpty) {
        coreValues.clear();
        coreValues.addAll(rValues.map((r) => ValueItem(icon: _text(r, 'icon'), title: _text(r, 'title'), description: _text(r, 'description'))));
      }
      final rAchievements = _rows(data, 'achievements');
      if (rAchievements.isNotEmpty) {
        achievements.clear();
        achievements.addAll(rAchievements.map((r) => Achievement(year: _text(r, 'year'), title: _text(r, 'title'))));
      }
      final rTestimonials = _rows(data, 'testimonials');
      if (rTestimonials.isNotEmpty) {
        testimonials.clear();
        testimonials.addAll(rTestimonials.map((r) => Testimonial(name: _text(r, 'name'), relation: _text(r, 'relation'), text: _text(r, 'text'))));
      }
      final rEvents = _rows(data, 'events');
      if (rEvents.isNotEmpty) {
        events.clear();
        events.addAll(rEvents.map((r) => EventItem(date: _text(r, 'date'), title: _text(r, 'title'), description: _text(r, 'description'), category: _text(r, 'category'), imagePath: _text(r, 'imagePath'))));
      }
      final rNotices = _rows(data, 'notices');
      if (rNotices.isNotEmpty) {
        notices.clear();
        notices.addAll(rNotices.map((r) => NoticeItem(date: _text(r, 'date'), title: _text(r, 'title'), isHighPriority: r['isHighPriority'] == true)));
      }
      final rAcademicLevels = _rows(data, 'academicLevels');
      if (rAcademicLevels.isNotEmpty) {
        academicLevels.clear();
        academicLevels.addAll(rAcademicLevels.map((r) => AcademicLevel(id: _text(r, 'id'), title: _text(r, 'title'), grades: _text(r, 'grades'), focus: _text(r, 'focus'), highlights: (r['highlights'] as List? ?? const []).map((item) => item.toString()).toList())));
      }
      final rCoCurriculars = _rows(data, 'coCurriculars');
      if (rCoCurriculars.isNotEmpty) {
        coCurriculars.clear();
        coCurriculars.addAll(rCoCurriculars.map((r) => CoCurricular(icon: _text(r, 'icon'), name: _text(r, 'name'))));
      }
      final rFeeStructure = _rows(data, 'feeStructure');
      if (rFeeStructure.isNotEmpty) {
        feeStructure.clear();
        feeStructure.addAll(rFeeStructure.map((r) => FeeItem(grade: _text(r, 'grade'), admission: _text(r, 'admission'), tuition: _text(r, 'tuition'), annual: _text(r, 'annual'))));
      }
      final rAdmissionSteps = _rows(data, 'admissionSteps');
      if (rAdmissionSteps.isNotEmpty) {
        admissionSteps.clear();
        admissionSteps.addAll(rAdmissionSteps.map((r) => AdmissionStep(step: (r['step'] as num?)?.toInt() ?? 0, title: _text(r, 'title'), description: _text(r, 'description'))));
      }
      final rImportantDates = _rows(data, 'importantDates');
      if (rImportantDates.isNotEmpty) {
        importantDates.clear();
        importantDates.addAll(rImportantDates.map((r) => ImportantDate(event: _text(r, 'event'), date: _text(r, 'date'))));
      }
      final rForms = _rows(data, 'forms');
      if (rForms.isNotEmpty) {
        forms.clear();
        forms.addAll(rForms.map((r) => DownloadableForm(name: _text(r, 'name'), type: _text(r, 'type'), size: _text(r, 'size'), url: _text(r, 'url'))));
      }
      if (data['galleryCategories'] is List && (data['galleryCategories'] as List).isNotEmpty) {
        galleryCategories.clear();
        galleryCategories.add('All');
        galleryCategories.addAll((data['galleryCategories'] as List).map((item) => item.toString()).where((item) => item != 'All'));
      }
      final rGalleryImages = _rows(data, 'galleryImages');
      if (rGalleryImages.isNotEmpty) {
        galleryImages.clear();
        galleryImages.addAll(rGalleryImages.map((r) => GalleryItem(category: _text(r, 'category'), label: _text(r, 'label'), color: (r['color'] as num?)?.toInt() ?? 0xFF17324D, imagePath: _text(r, 'imagePath'))));
      }
      final rTransportZones = _rows(data, 'transportZones');
      if (rTransportZones.isNotEmpty) {
        transportZones.clear();
        transportZones.addAll(rTransportZones.map((r) => TransportZone(zone: _text(r, 'zone'), area: _text(r, 'area'), distance: _text(r, 'distance'), fee: _text(r, 'fee'))));
      }
      if (data['transportFeatures'] is List && (data['transportFeatures'] as List).isNotEmpty) {
        transportFeatures.clear();
        transportFeatures.addAll((data['transportFeatures'] as List).map((item) => item.toString()));
      }
      final rTimeline = _rows(data, 'timeline');
      if (rTimeline.isNotEmpty) {
        timeline.clear();
        timeline.addAll(rTimeline.map((r) => HistoryEvent(year: _text(r, 'year'), text: _text(r, 'text'))));
      }
    } catch (_) {
      _clearPreviewContent();
      loadError = 'School information is temporarily unavailable.';
    }
  }

  /// Day-one setup checklist for administrators.
  static List<({String title, String description, bool isComplete, int targetIndex})> get setupChecklist => [
    (
      title: 'School Identity & Contact Info',
      description: 'School name, phone number, email, and campus address',
      isComplete: AppStrings.schoolName.isNotEmpty &&
          AppStrings.schoolName != 'School' &&
          AppStrings.phone.isNotEmpty,
      targetIndex: 18, // Settings
    ),
    (
      title: 'Leadership & Welcome Message',
      description: 'Principal message and leadership profile',
      isComplete: principalName.isNotEmpty && principalMessage.isNotEmpty,
      targetIndex: 18, // Settings
    ),
    (
      title: 'Academic Fee Structure',
      description: 'Grade-wise fee amounts and installment terms',
      isComplete: feeStructure.isNotEmpty,
      targetIndex: 5, // Fees
    ),
    (
      title: 'Campus Hero & Visuals',
      description: 'Custom campus banner and event photos',
      isComplete: heroBannerImagePath.isNotEmpty,
      targetIndex: 18, // Settings
    ),
  ];
}

// --- Data Models ---

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
  /// Asset path e.g. 'assets/images/events/annual_day.jpg'
  /// Drop your photo in that path and it will appear automatically.
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
  final String url;
  const DownloadableForm({required this.name, required this.type, required this.size, this.url = ''});
}

class GalleryItem {
  final String category;
  final String label;
  final int color; // fallback placeholder colour when image not yet added
  /// Asset path e.g. 'assets/images/gallery/campus/main_entrance.jpg'
  /// Drop your photo in that path and it will appear automatically.
  final String? imagePath;
  const GalleryItem({required this.category, required this.label, required this.color, this.imagePath});
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
