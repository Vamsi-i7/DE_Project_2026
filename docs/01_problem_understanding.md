# Phase 1: Problem Understanding

**Project:** Practo Doctor Appointments Database (DBMS Project 15)
**Team:** EduWrap, Section A, Mentor: Satyaki
**Members:** Bala Vamsi Krishna (lead), Jayanth Pranay Konada, Shreya Das, Chekka Chandra Mouli

## Context

Practo lets patients find doctors, book a slot (in clinic or by video), consult, receive a prescription and leave a review. The database was built quickly, has no documented schema, and seven product teams report problems. Our job is to rebuild a correct schema, measure the 30 key queries, make them fast without changing their results, and show the design can handle 20x more appointments.

## Problems P1 to P7

| # | What the business needs (our words) | Who is affected | Type |
|---|---|---|---|
| **P1** | Searching doctors by specialization, city and language, opening a profile and showing free slots must feel instant. Free slots are currently worked out from the weekly schedule on every request, which is wasteful. (R01, R02, R03, R18) | Patients; doctors (their profile and slots are what is shown) | **Customer-facing / real-time** |
| **P2** | A patient should see "My appointments", sign in and open prescriptions without waiting, and booking a slot should confirm quickly. (R04, R06, R07, W01) | Patients | **Customer-facing / real-time** |
| **P3** | Reception staff need the doctor's queue for the day and the check-in action to respond immediately while patients are waiting. (R05, W02) | Clinic reception; doctors | **Customer-facing / real-time** |
| **P4** | The care team needs to quickly spot (a) prescriptions that conflict with a patient's allergies, (b) patients who missed a follow-up, and (c) "doctor shopping", where one patient visits many doctors for the same issue. (R10, R11, R25, W03) | Patient-safety team; care team; doctors | **Mixed:** allergy checks are real-time (safety at prescribing time); follow-ups and doctor shopping are reporting |
| **P5** | The "clinics with no doctor schedule" list returns nothing, so partnerships cannot find clinics to follow up. This is a **correctness** problem, not only a speed problem. (R13) | Clinic partnerships | **Reporting / analytics** |
| **P6** | Quality reports on no-shows, waiting time, ratings and double bookings time out, so the quality team cannot monitor service. (R08, R09, R14, R24, W04) | Quality team; clinics; doctors | **Reporting / analytics** |
| **P7** | Finance, pharmacy and population-health reports are slow today and must stay usable when appointments grow 20x. (R12, R15, R16, R17, R19 to R23, W05) | Finance; pharmacy partners; insights / support | **Reporting / analytics** |

## Why the classification matters

Customer-facing queries (P1 to P3, and the allergy check in P4) run while a person waits, so they need very low latency and should stay fast under many concurrent users. Reporting queries (P5 to P7 and the rest of P4) can run in batches, so the target is to finish reliably and scale, even if they take longer. We will use this split to set our performance targets in Phases 3 to 5.

## Assumptions

1. A schedule or appointment with no `clinic_id` is a **video consultation**, and an in-clinic one always has a `clinic_id`. We will confirm this against the data in Phase 2.
2. `consultation_fee` and `video_fee` belong to the doctor, and `appointments.fee` is the amount charged for that booking at the time (a price snapshot).
3. The seed data is a representative sample of production, and the 20x growth applies mainly to `appointments` and the tables hanging off it (prescriptions, items, reviews).
4. Reports can read slightly stale data, but booking, check-in and sign-in must always see current data.
5. The empty list in P5 is likely a logic or NULL-handling bug in the current query and not only a speed issue. We will check this when we analyse R13.
6. We keep results of all 30 queries identical while optimizing, so any change in output is treated as a bug.
