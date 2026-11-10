-- sql/02_load_data.sql : load the 11 seed CSVs, then verify (Phase 2)
-- Run from the repo root, i.e. the folder that contains seed_data/ (unzipped, not committed):
--   psql -d <your_db> -f sql/01_schema.sql
--   psql -d <your_db> -f sql/02_load_data.sql > load_results.txt
-- Paste the output sections into docs/02_schema_design.md.

\set ON_ERROR_STOP on
\pset pager off
SET search_path TO practo;

BEGIN;

-- makes the file re-runnable
TRUNCATE cities, specializations, doctors, doctor_specializations, clinics, doctor_schedules,
         patients, appointments, prescriptions, prescription_items, doctor_reviews CASCADE;

-- parents before children
\copy cities (city_id, city_name, state) FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy specializations (spec_id, spec_name) FROM 'seed_data/specializations.csv' WITH (FORMAT csv, HEADER true)
\copy doctors (doctor_id, full_name, registration_no, gender, experience_years, consultation_fee, video_fee, languages, is_verified, joined_on) FROM 'seed_data/doctors.csv' WITH (FORMAT csv, HEADER true)
\copy clinics (clinic_id, clinic_name, city_id, locality, latitude, longitude, phone) FROM 'seed_data/clinics.csv' WITH (FORMAT csv, HEADER true)
\copy patients (patient_id, full_name, phone, email, dob, gender, blood_group, allergies, city_id, created_at) FROM 'seed_data/patients.csv' WITH (FORMAT csv, HEADER true)
\copy doctor_specializations (doctor_id, spec_id, is_primary) FROM 'seed_data/doctor_specializations.csv' WITH (FORMAT csv, HEADER true)
\copy doctor_schedules (doctor_id, weekday, start_time, end_time, clinic_id, slot_minutes) FROM 'seed_data/doctor_schedules.csv' WITH (FORMAT csv, HEADER true)
\copy appointments (appointment_id, patient_id, doctor_id, clinic_id, consult_type, booked_at, slot_start, slot_end, reason, status, checked_in_at, consult_started_at, consult_ended_at, fee, payment_status) FROM 'seed_data/appointments.csv' WITH (FORMAT csv, HEADER true)
\copy prescriptions (prescription_id, appointment_id, diagnosis, notes, follow_up_date, issued_at) FROM 'seed_data/prescriptions.csv' WITH (FORMAT csv, HEADER true)
\copy prescription_items (prescription_id, line_no, medicine_name, dosage, duration_days, instructions) FROM 'seed_data/prescription_items.csv' WITH (FORMAT csv, HEADER true)
\copy doctor_reviews (review_id, appointment_id, rating, recommends, wait_time_bucket, review_text, created_at) FROM 'seed_data/doctor_reviews.csv' WITH (FORMAT csv, HEADER true)

COMMIT;
ANALYZE;

-- =====================================================================
-- VERIFICATION
-- =====================================================================
\echo
\echo '===== 1. ROW COUNTS (ok must be true everywhere) ====='
SELECT t.table_name, t.loaded, t.expected, (t.loaded = t.expected) AS ok
FROM (
    SELECT 'cities' AS table_name,                 (SELECT count(*) FROM cities) AS loaded,                 10     AS expected
    UNION ALL SELECT 'specializations',            (SELECT count(*) FROM specializations),                  15
    UNION ALL SELECT 'doctors',                    (SELECT count(*) FROM doctors),                          3000
    UNION ALL SELECT 'doctor_specializations',     (SELECT count(*) FROM doctor_specializations),           3700
    UNION ALL SELECT 'clinics',                    (SELECT count(*) FROM clinics),                          1500
    UNION ALL SELECT 'doctor_schedules',           (SELECT count(*) FROM doctor_schedules),                 30499
    UNION ALL SELECT 'patients',                   (SELECT count(*) FROM patients),                         40000
    UNION ALL SELECT 'appointments',               (SELECT count(*) FROM appointments),                     150000
    UNION ALL SELECT 'prescriptions',              (SELECT count(*) FROM prescriptions),                    97234
    UNION ALL SELECT 'prescription_items',         (SELECT count(*) FROM prescription_items),               243085
    UNION ALL SELECT 'doctor_reviews',             (SELECT count(*) FROM doctor_reviews),                   30339
) t;

\echo
\echo '===== 2. INDEXES THAT EXIST (PK / UNIQUE only, plus the one partial unique index) ====='
SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'practo' ORDER BY tablename, indexname;

\echo
\echo '===== 3. INTEGRITY CHECKS (expect 0 unless noted) ====='

\echo '-- 3.1 appointments NOT inside any schedule of that doctor (weekday, clock time in IST, same clinic, same slot length)'
SELECT count(*) AS appointments_outside_schedule
FROM appointments a
WHERE NOT EXISTS (
    SELECT 1 FROM doctor_schedules s
    WHERE s.doctor_id = a.doctor_id
      AND s.weekday = extract(isodow FROM a.slot_start AT TIME ZONE 'Asia/Kolkata')::int
      AND (a.slot_start AT TIME ZONE 'Asia/Kolkata')::time >= s.start_time
      AND (a.slot_end   AT TIME ZONE 'Asia/Kolkata')::time <= s.end_time
      AND s.clinic_id IS NOT DISTINCT FROM a.clinic_id
      AND s.slot_minutes = extract(epoch FROM a.slot_end - a.slot_start)::int / 60
);

\echo '-- 3.2 in-clinic appointments at a clinic where the doctor has no schedule'
SELECT count(*) AS clinic_visits_at_wrong_clinic
FROM appointments a
WHERE a.clinic_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM doctor_schedules s
                  WHERE s.doctor_id = a.doctor_id AND s.clinic_id = a.clinic_id);

\echo '-- 3.3 prescribed medicine that matches a recorded allergy (informational: a finding, not an error)'
WITH map(allergen, med_pattern) AS (
    VALUES ('Penicillin', '%amoxicillin%'), ('Penicillin', '%ampicillin%'), ('Penicillin', '%penicillin%'),
           ('Aspirin',    '%aspirin%'),
           ('Sulfa',      '%sulfamethoxazole%'), ('Sulfa', '%co-trimoxazole%')
)
SELECT m.allergen, count(DISTINCT (i.prescription_id, i.line_no)) AS conflicting_items
FROM patients pt
JOIN appointments a       ON a.patient_id = pt.patient_id
JOIN prescriptions p      ON p.appointment_id = a.appointment_id
JOIN prescription_items i ON i.prescription_id = p.prescription_id
JOIN map m                ON i.medicine_name ILIKE m.med_pattern AND pt.allergies @> ARRAY[m.allergen]
GROUP BY m.allergen
ORDER BY m.allergen;

\echo '-- 3.4 doctors without a primary specialization (the partial unique index only limits to at most one)'
SELECT count(*) AS doctors_without_primary_spec
FROM doctors d
WHERE NOT EXISTS (SELECT 1 FROM doctor_specializations ds WHERE ds.doctor_id = d.doctor_id AND ds.is_primary);

\echo '-- 3.5 prescriptions or reviews attached to an appointment that is not COMPLETED'
SELECT (SELECT count(*) FROM prescriptions p JOIN appointments a ON a.appointment_id = p.appointment_id
        WHERE a.status <> 'COMPLETED') AS prescriptions_on_non_completed,
       (SELECT count(*) FROM doctor_reviews r JOIN appointments a ON a.appointment_id = r.appointment_id
        WHERE a.status <> 'COMPLETED') AS reviews_on_non_completed;

\echo '-- 3.6 video appointments for doctors with no video fee'
SELECT count(*) AS video_appts_without_video_fee
FROM appointments a JOIN doctors d ON d.doctor_id = a.doctor_id
WHERE a.consult_type = 'VIDEO' AND d.video_fee IS NULL;

\echo '-- 3.7 appointment fee differs from the doctor fee for that consult type (redundancy check; 0 means fee is derivable)'
SELECT count(*) AS fee_differs_from_doctor_fee
FROM appointments a JOIN doctors d ON d.doctor_id = a.doctor_id
WHERE a.fee <> CASE WHEN a.consult_type = 'IN_CLINIC' THEN d.consultation_fee ELSE d.video_fee END;

\echo
\echo '===== 4. DATA PROBLEMS (findings to record in docs/02_schema_design.md; non-zero is expected) ====='

\echo '-- 4.1 double bookings: same doctor, same slot, both not cancelled (expect 559 pairs)'
SELECT count(*) AS double_booked_pairs
FROM appointments a JOIN appointments b
  ON b.doctor_id = a.doctor_id AND b.slot_start = a.slot_start AND b.appointment_id > a.appointment_id
WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED';

\echo '-- 4.2 check-in recorded after the consult started (expect 16183)'
SELECT count(*) AS checkin_after_consult_start
FROM appointments WHERE checked_in_at > consult_started_at;

\echo '-- 4.3 appointment booked before the patient account was created'
SELECT count(*) AS booked_before_patient_created
FROM appointments a JOIN patients p ON p.patient_id = a.patient_id
WHERE a.booked_at < p.created_at;

\echo '-- 4.4 payment oddities: cancelled but still PAID, completed but still PENDING (expect 6021 and 24683)'
SELECT count(*) FILTER (WHERE status = 'CANCELLED' AND payment_status = 'PAID')     AS cancelled_but_paid,
       count(*) FILTER (WHERE status = 'COMPLETED' AND payment_status = 'PENDING')  AS completed_but_pending
FROM appointments;

\echo '-- 4.5 completed appointments without a prescription'
SELECT count(*) AS completed_without_prescription
FROM appointments a
WHERE a.status = 'COMPLETED'
  AND NOT EXISTS (SELECT 1 FROM prescriptions p WHERE p.appointment_id = a.appointment_id);

\echo
\echo '===== DONE ====='