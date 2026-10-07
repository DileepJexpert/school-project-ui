-- Seed Exam Configs for risingstar and risingstar-test
INSERT OR IGNORE INTO exam_configs (id, tenant_id, academic_year, exam_type, display_name, weightage_percent, max_marks_default, is_active)
VALUES 
  ('cfg-rs-ut1', 'risingstar', '2026-2027', 'UNIT_TEST_1', 'Unit Test 1', 10, 50, 1),
  ('cfg-rs-mid', 'risingstar', '2026-2027', 'MID_TERM', 'Mid Term', 25, 100, 1),
  ('cfg-rs-half', 'risingstar', '2026-2027', 'HALF_YEARLY', 'Half Yearly', 25, 100, 1),
  ('cfg-rs-ann', 'risingstar', '2026-2027', 'ANNUAL', 'Annual Examination', 40, 100, 1),
  ('cfg-rst-ut1', 'risingstar-test', '2026-2027', 'UNIT_TEST_1', 'Unit Test 1', 10, 50, 1),
  ('cfg-rst-mid', 'risingstar-test', '2026-2027', 'MID_TERM', 'Mid Term', 25, 100, 1),
  ('cfg-rst-half', 'risingstar-test', '2026-2027', 'HALF_YEARLY', 'Half Yearly', 25, 100, 1),
  ('cfg-rst-ann', 'risingstar-test', '2026-2027', 'ANNUAL', 'Annual Examination', 40, 100, 1);

-- Seed Incidents
INSERT OR IGNORE INTO incidents (id, tenant_id, student_id, student_name, class_name, academic_year, severity, category, description, action_taken, reported_by, incident_date, parent_notified, follow_up_notes, resolved, resolved_at, created_at)
VALUES
  ('inc-rs-1', 'risingstar', '19de91f5b62641c99ebc492bb914a0c1', 'aashvi', 'Class 3 - A', '2026-2027', 'MINOR', 'ACADEMIC', 'Demonstrated exceptional enthusiasm during science project demonstration.', 'Awarded badge of excellence in assembly.', 'Science Teacher', '2026-10-05', 1, 'Positive reinforcement recorded.', 1, '2026-10-06T10:00:00Z', '2026-10-05T09:30:00Z');

-- Seed Notifications
INSERT OR IGNORE INTO notifications (id, tenant_id, title, message, type, target_audience, target_class, target_student_id, priority, created_by, created_at, expires_at)
VALUES
  ('notif-rs-1', 'risingstar', 'Annual Sports Meet 2026', 'Annual Sports Meet 2026 will commence on October 25th. Parents are invited to attend and cheer for student teams.', 'EVENT', 'ALL', NULL, NULL, 'HIGH', 'Principal Office', '2026-10-01T08:00:00Z', '2026-10-31T23:59:59Z'),
  ('notif-rs-2', 'risingstar', 'Mid-Term Assessment Schedule', 'Mid-term examinations for all grades will commence next week. Detailed subject timetables have been updated on the student portal.', 'ACADEMIC', 'ALL', NULL, NULL, 'MEDIUM', 'Academic Dean', '2026-10-04T09:00:00Z', '2026-10-25T23:59:59Z'),
  ('notif-rst-1', 'risingstar-test', 'Annual Sports Meet 2026', 'Annual Sports Meet 2026 will commence on October 25th. Parents are invited to attend.', 'EVENT', 'ALL', NULL, NULL, 'HIGH', 'Principal Office', '2026-10-01T08:00:00Z', '2026-10-31T23:59:59Z');

-- Seed Timetable for Class 3 - A
INSERT OR IGNORE INTO timetable_days (id, tenant_id, class_name, academic_year, day_of_week)
VALUES
  ('tt-rs-mon', 'risingstar', 'Class 3 - A', '2026-2027', 'Monday'),
  ('tt-rs-tue', 'risingstar', 'Class 3 - A', '2026-2027', 'Tuesday'),
  ('tt-rs-wed', 'risingstar', 'Class 3 - A', '2026-2027', 'Wednesday'),
  ('tt-rs-thu', 'risingstar', 'Class 3 - A', '2026-2027', 'Thursday'),
  ('tt-rs-fri', 'risingstar', 'Class 3 - A', '2026-2027', 'Friday');

INSERT OR IGNORE INTO timetable_periods (id, day_id, period_number, subject, teacher_name, start_time, end_time)
VALUES
  ('ttp-rs-m1', 'tt-rs-mon', 1, 'English', 'Aarav Sharma', '08:30', '09:15'),
  ('ttp-rs-m2', 'tt-rs-mon', 2, 'Mathematics', 'Priya Patel', '09:15', '10:00'),
  ('ttp-rs-m3', 'tt-rs-mon', 3, 'Environmental Studies', 'Rohit Verma', '10:15', '11:00'),
  ('ttp-rs-m4', 'tt-rs-mon', 4, 'Hindi', 'Sunita Rao', '11:00', '11:45'),
  ('ttp-rs-m5', 'tt-rs-mon', 5, 'Arts & Crafts', 'Neha Gupta', '12:15', '13:00'),
  ('ttp-rs-tu1', 'tt-rs-tue', 1, 'Mathematics', 'Priya Patel', '08:30', '09:15'),
  ('ttp-rs-tu2', 'tt-rs-tue', 2, 'English', 'Aarav Sharma', '09:15', '10:00'),
  ('ttp-rs-tu3', 'tt-rs-tue', 3, 'Environmental Studies', 'Rohit Verma', '10:15', '11:00'),
  ('ttp-rs-tu4', 'tt-rs-tue', 4, 'Physical Education', 'Vikram Singh', '11:00', '11:45'),
  ('ttp-rs-tu5', 'tt-rs-tue', 5, 'Computer Science', 'Ananya Joshi', '12:15', '13:00');

-- Seed AI Config
INSERT OR IGNORE INTO ai_configs (id, tenant_id, enabled, enabled_modes, primary_provider, ollama_base_url, ollama_model, daily_limit_per_student, max_conversation_turns, updated_at)
VALUES
  ('aic-rs-1', 'risingstar', 1, '["TUTOR", "HOMEWORK_HELPER"]', 'OLLAMA', 'http://localhost:11434', 'llama3', 20, 30, '2026-10-01T00:00:00Z'),
  ('aic-rst-1', 'risingstar-test', 1, '["TUTOR", "HOMEWORK_HELPER"]', 'OLLAMA', 'http://localhost:11434', 'llama3', 20, 30, '2026-10-01T00:00:00Z');
