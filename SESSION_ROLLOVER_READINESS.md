# Academic-year rollover readiness

The Flutter client now requires a source year for class promotion, derives the
immediately following target year, reads the full cohort, and checks that the
target class has a fee structure. A failed per-student run reports how many
updates completed; rerunning that source class/year skips students already
moved. Admission and fee setup offer rolling year choices rather than a fixed
list, and admissions require a matching fee structure before submission.
Ordinary student edits cannot silently change class or year; those changes
must follow the promotion workflow so fee implications are visible.

This is **not an atomic school-year rollover**. The backend source and a live
test environment are not in this repository, so the following server behavior
cannot be verified or implemented here:

- Promote or graduate a cohort in one transaction (or persist a resumable job
  with per-student results and an idempotency key). Avoid a partially promoted
  class if a request fails or two administrators run it at once.
- Keep old-year fees, payments, receipts, attendance, marks, and reports tied
  to their original year. Create the new-year fee profile exactly once from
  the new class/year structure. State explicitly whether arrears remain in the
  old profile or are carried forward, and prevent double collection.
- Expose an academic year on student fee profiles, installments, and payment
  requests. The current `StudentFeeProfile` and `FeePaymentRequest` client
  contracts have no year, so the cashier cannot independently confirm which
  year's installment a payment will settle.
- Return the created admission/student ID and verify fee-profile creation on
  new admission and enquiry conversion. The present client only knows that
  `/students/add` or `/students/{id}` returned successfully.
- Reconcile class/section and roll numbers, graduated students, and new-year
  timetable assignments. The current promotion keeps roll numbers and only
  changes student class/year/status.

Before real use, test on a copy of school data: configure next-year fee
structures; admit a new student and convert an enquiry; collect a fee; promote
one class; interrupt and retry a promotion; check old and new fee balances,
receipts, reports, attendance, and marks; then graduate Class 12. Verify the
same outcomes through the actual backend and school roles.
