SET search_path TO practo;
BEGIN;

-- @R01
SELECT DISTINCT d.doctor_id, d.full_name, d.experience_years, d.consultation_fee
FROM doctors d
JOIN doctor_specializations ds ON ds.doctor_id = d.doctor_id
JOIN specializations s         ON s.spec_id = ds.spec_id AND s.spec_name = 'Dermatologist'
JOIN doctor_schedules sc       ON sc.doctor_id = d.doctor_id
JOIN clinics c                 ON c.clinic_id = sc.clinic_id
WHERE c.city_id = 1 AND d.is_verified
ORDER BY d.experience_years DESC
LIMIT 20;

-- @R02
SELECT sc.weekday, sc.start_time, sc.end_time, sc.slot_minutes, coalesce(c.clinic_name, 'Video consultation') AS place
FROM doctor_schedules sc
LEFT JOIN clinics c ON c.clinic_id = sc.clinic_id
WHERE sc.doctor_id = 217
ORDER BY sc.weekday, sc.start_time;

-- @R03
SELECT slot
FROM doctor_schedules sc
CROSS JOIN LATERAL generate_series(('2026-07-03'::date + sc.start_time)::timestamptz,
                                   ('2026-07-03'::date + sc.end_time)::timestamptz - sc.slot_minutes * interval '1 minute',
                                   sc.slot_minutes * interval '1 minute') AS slot
WHERE sc.doctor_id = 217 AND sc.weekday = 5 AND sc.clinic_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM appointments a
                  WHERE a.doctor_id = 217 AND a.slot_start = slot AND a.status <> 'CANCELLED')
ORDER BY slot;

-- @R04
SELECT a.appointment_id, d.full_name, a.consult_type, a.slot_start, c.clinic_name
FROM appointments a
JOIN doctors d ON d.doctor_id = a.doctor_id
LEFT JOIN clinics c ON c.clinic_id = a.clinic_id
WHERE a.patient_id = 90 AND a.status = 'BOOKED'
ORDER BY a.slot_start;

-- @R05
SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 16
  AND a.slot_start >= '2026-06-30 00:00:00+05:30' AND a.slot_start < '2026-07-01 00:00:00+05:30'
ORDER BY a.slot_start;

-- @R06
SELECT patient_id, full_name, dob, blood_group
FROM patients
WHERE phone = '9400000090';

-- @R07
SELECT p.diagnosis, p.follow_up_date, i.line_no, i.medicine_name, i.dosage, i.duration_days, i.instructions
FROM prescriptions p
JOIN prescription_items i ON i.prescription_id = p.prescription_id
WHERE p.appointment_id = 18872
ORDER BY i.line_no;

-- @R08
SELECT s.spec_name, count(*) AS appointments,
       round(100.0 * count(*) FILTER (WHERE a.status = 'NO_SHOW') / count(*), 2) AS no_show_pct
FROM appointments a
JOIN doctor_specializations ds ON ds.doctor_id = a.doctor_id AND ds.is_primary
JOIN specializations s         ON s.spec_id = ds.spec_id
WHERE a.slot_start >= '2026-01-01 00:00:00+05:30' AND a.slot_start < '2027-01-01 00:00:00+05:30'
  AND a.status IN ('COMPLETED', 'NO_SHOW')
GROUP BY s.spec_name
ORDER BY no_show_pct DESC;

-- @R09
SELECT a.clinic_id, count(*) AS consults,
       round(avg(EXTRACT(EPOCH FROM (a.consult_started_at - a.slot_start)) / 60), 1) AS avg_wait_min
FROM appointments a
WHERE a.status = 'COMPLETED' AND a.consult_type = 'IN_CLINIC'
  AND a.slot_start >= '2026-06-01' AND a.slot_start < '2026-07-01'
GROUP BY a.clinic_id
HAVING count(*) >= 5
ORDER BY avg_wait_min DESC
LIMIT 20;

-- @R10
SELECT pt.patient_id, pt.full_name, pt.allergies, i.medicine_name, p.issued_at
FROM patients pt
JOIN appointments a        ON a.patient_id = pt.patient_id
JOIN prescriptions p       ON p.appointment_id = a.appointment_id
JOIN prescription_items i  ON i.prescription_id = p.prescription_id
WHERE pt.allergies @> ARRAY['Penicillin']
  AND i.medicine_name ILIKE '%amoxicillin%'
ORDER BY p.issued_at DESC;

-- @R11
SELECT p.prescription_id, a.patient_id, a.doctor_id, p.follow_up_date
FROM prescriptions p
JOIN appointments a ON a.appointment_id = p.appointment_id
WHERE p.follow_up_date BETWEEN '2026-07-01' AND '2026-07-07'
  AND NOT EXISTS (SELECT 1 FROM appointments f
                  WHERE f.patient_id = a.patient_id AND f.doctor_id = a.doctor_id
                    AND f.slot_start > a.slot_start AND f.status <> 'CANCELLED')
ORDER BY p.follow_up_date;

-- @R12
SELECT date_trunc('month', slot_start) AS month, consult_type, count(*) AS appointments
FROM appointments
WHERE slot_start >= '2026-01-01 00:00:00+05:30' AND slot_start < '2027-01-01 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R13
SELECT c.clinic_id, c.clinic_name, c.city_id
FROM clinics c
WHERE NOT EXISTS (SELECT 1 FROM doctor_schedules sc WHERE sc.clinic_id = c.clinic_id);

-- @R14
SELECT a.doctor_id, round(avg(r.rating), 2) AS avg_rating,
       round(100.0 * count(*) FILTER (WHERE r.recommends) / count(*), 1) AS recommend_pct, count(*) AS reviews
FROM doctor_reviews r
JOIN appointments a ON a.appointment_id = r.appointment_id
GROUP BY a.doctor_id
HAVING count(*) >= 10
ORDER BY avg_rating DESC, reviews DESC
LIMIT 20;

-- @R15
SELECT s.spec_name, i.medicine_name, count(*) AS times_prescribed
FROM prescription_items i
JOIN prescriptions p           ON p.prescription_id = i.prescription_id
JOIN appointments a            ON a.appointment_id = p.appointment_id
JOIN doctor_specializations ds ON ds.doctor_id = a.doctor_id AND ds.is_primary
JOIN specializations s         ON s.spec_id = ds.spec_id
WHERE p.issued_at >= '2026-06-01' AND p.issued_at < '2026-07-01'
GROUP BY s.spec_name, i.medicine_name
ORDER BY s.spec_name, times_prescribed DESC;

-- @R16
SELECT c.clinic_id, c.clinic_name, count(*) AS paid_consults, sum(a.fee) AS collected
FROM appointments a
JOIN clinics c ON c.clinic_id = a.clinic_id
WHERE a.payment_status = 'PAID'
  AND a.slot_start >= '2026-06-01' AND a.slot_start < '2026-07-01'
GROUP BY c.clinic_id, c.clinic_name
ORDER BY collected DESC
LIMIT 20;

-- @R17
SELECT CASE WHEN age(a.slot_start::date, p.dob) < interval '18 years' THEN '0-17'
            WHEN age(a.slot_start::date, p.dob) < interval '40 years' THEN '18-39'
            WHEN age(a.slot_start::date, p.dob) < interval '60 years' THEN '40-59' ELSE '60+' END AS age_group,
       coalesce(p.blood_group, 'unknown') AS blood_group, count(*) AS appointments
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
WHERE a.status = 'COMPLETED' AND a.slot_start >= '2026-01-01'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R18
SELECT DISTINCT d.doctor_id, d.full_name, d.languages, d.consultation_fee
FROM doctors d
JOIN doctor_schedules sc ON sc.doctor_id = d.doctor_id
JOIN clinics c           ON c.clinic_id = sc.clinic_id
WHERE c.city_id = 5
  AND 'Tamil' = ANY (d.languages)
ORDER BY d.consultation_fee;

-- @R19
WITH bengaluru_doctors AS (
    SELECT DISTINCT sc.doctor_id
    FROM doctor_schedules sc
    JOIN clinics c ON c.clinic_id = sc.clinic_id
    WHERE c.city_id = 1
),
june_counts AS (
    SELECT a.doctor_id, count(*) AS june_consults
    FROM appointments a
    JOIN bengaluru_doctors bd ON bd.doctor_id = a.doctor_id
    WHERE a.status = 'COMPLETED'
      AND a.slot_start >= '2026-06-01' AND a.slot_start < '2026-07-01'
    GROUP BY a.doctor_id
),
last_consults AS (
    SELECT a.doctor_id, max(a.consult_ended_at) AS last_consult_at
    FROM appointments a
    JOIN bengaluru_doctors bd ON bd.doctor_id = a.doctor_id
    GROUP BY a.doctor_id
)
SELECT d.doctor_id, d.full_name,
       coalesce(jc.june_consults, 0) AS june_consults,
       lc.last_consult_at
FROM doctors d
JOIN bengaluru_doctors bd ON bd.doctor_id = d.doctor_id
LEFT JOIN june_counts jc ON jc.doctor_id = d.doctor_id
LEFT JOIN last_consults lc ON lc.doctor_id = d.doctor_id
ORDER BY june_consults DESC;

-- @R20
SELECT day, consults, sum(consults) OVER (ORDER BY day) AS running_total
FROM (
    SELECT slot_start::date AS day, count(*) AS consults
    FROM appointments
    WHERE status = 'COMPLETED'
      AND slot_start >= '2026-06-01 00:00:00+05:30' AND slot_start < '2026-07-01 00:00:00+05:30'
    GROUP BY 1
) d
ORDER BY day;

-- @R21
SELECT appointment_id, patient_id, clinic_id, fee, slot_start
FROM appointments
WHERE status = 'COMPLETED' AND payment_status = 'PENDING'
ORDER BY slot_start DESC
LIMIT 100;

-- @R22
SELECT appointment_id, patient_id, doctor_id, status, slot_start
FROM appointments
ORDER BY slot_start DESC
OFFSET 100000
LIMIT 25;

-- @R23
SELECT doctor_id, full_name, is_verified, joined_on
FROM doctors
WHERE registration_no = 'TSMC-011519';

-- @R24
SELECT a.doctor_id, a.slot_start, a.appointment_id, b.appointment_id AS other_appointment_id
FROM appointments a
JOIN appointments b ON b.doctor_id = a.doctor_id AND b.slot_start = a.slot_start
                   AND b.appointment_id > a.appointment_id
WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED'
ORDER BY a.slot_start DESC;

-- @R25
SELECT a.patient_id, ds.spec_id, count(DISTINCT a.doctor_id) AS doctors_seen
FROM appointments a
JOIN doctor_specializations ds ON ds.doctor_id = a.doctor_id AND ds.is_primary
WHERE a.status = 'COMPLETED' AND a.slot_start >= '2026-01-01'
GROUP BY a.patient_id, ds.spec_id
HAVING count(DISTINCT a.doctor_id) >= 3
ORDER BY doctors_seen DESC, a.patient_id;

-- @W01
INSERT INTO appointments (appointment_id, patient_id, doctor_id, clinic_id, consult_type, booked_at, slot_start, slot_end,
                          reason, status, fee, payment_status)
SELECT 90000001, 90, 217, sc.clinic_id, 'IN_CLINIC', '2026-07-01 09:00:00+05:30',
       '2026-07-03 10:30:00+05:30', TIMESTAMPTZ '2026-07-03 10:30:00+05:30' + sc.slot_minutes * interval '1 minute',
       'Skin rash', 'BOOKED', d.consultation_fee, 'PENDING'
FROM doctor_schedules sc JOIN doctors d ON d.doctor_id = sc.doctor_id
WHERE sc.doctor_id = 217 AND sc.weekday = 5 AND sc.start_time = '10:00';

-- @W02
UPDATE appointments
SET status = 'CHECKED_IN', checked_in_at = slot_start - interval '5 minutes'
WHERE appointment_id = (SELECT appointment_id FROM appointments
                        WHERE status = 'BOOKED' AND consult_type = 'IN_CLINIC'
                          AND slot_start >= '2026-07-01' AND slot_start < '2026-07-02'
                        ORDER BY slot_start LIMIT 1);

-- @W03
UPDATE prescriptions
SET notes = 'Review blood sugar after 2 weeks', follow_up_date = '2026-07-15'
WHERE appointment_id = 18872;

-- @W04
UPDATE appointments
SET status = 'NO_SHOW'
WHERE status IN ('BOOKED', 'CHECKED_IN')
  AND slot_end < '2026-07-02 00:00:00+05:30'
  AND consult_ended_at IS NULL;

-- @W05
UPDATE appointments
SET status = 'CANCELLED', payment_status = 'REFUNDED'
WHERE doctor_id = 504 AND status = 'BOOKED'
  AND slot_start >= '2026-07-03' AND slot_start < '2026-07-04';

-- @END
ROLLBACK;
