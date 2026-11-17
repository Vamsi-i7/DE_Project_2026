# Baseline Timings (Phase 3: Workload 30)

Every query from `queries/workload_30.sql` was executed with `EXPLAIN (ANALYZE, BUFFERS)` in PostgreSQL on the `practo` database.
Each query was run **3 times**, and the table below reports all runs, their average, scan types, and performance characteristics.

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Find a doctor: verified dermatologists practising in Bengaluru, most experienced first | READ | 3.201 | 1.749 | 1.624 | 2.191 |
| R02: Doctor profile: doctor 217's weekly timetable with clinic names | READ | 0.241 | 0.211 | 0.210 | 0.221 |
| R03: Slot picker: doctor 217's free in-clinic slots on Friday 3 July 2026 | READ | 11.900 | 10.340 | 9.572 | 10.604 |
| R04: "My appointments": patient 90's upcoming appointments | READ | 7.791 | 7.067 | 6.891 | 7.250 |
| R05: Doctor's queue: doctor 16's appointments on 30 June 2026 | READ | 5.316 | 5.155 | 5.007 | 5.159 |
| R06: Sign-in with mobile number | READ | 0.031 | 0.038 | 0.025 | 0.031 |
| R07: Prescription view: the prescription and medicines of appointment 18872 | READ | 0.053 | 0.040 | 0.040 | 0.044 |
| R08: Quality: no-show rate per specialization in 2026 | READ | 18.903 | 19.197 | 19.063 | 19.054 |
| R09: Clinic experience: average minutes patients waited after their slot time, per clinic (June 2026) | READ | 8.205 | 8.364 | 8.071 | 8.213 |
| R10: Patient safety: patients allergic to penicillin who were prescribed amoxicillin | READ | 16.453 | 16.704 | 16.733 | 16.630 |
| R11: Care team: follow-ups due in the first week of July 2026 that the patient has not booked yet | READ | 16.356 | 16.389 | 16.160 | 16.302 |
| R12: Product analytics: video vs in-clinic appointments per month in 2026 | READ | 22.422 | 22.187 | 21.772 | 22.127 |
| R13: Clinic partnerships: clinics where no doctor has any schedule | READ | 2.655 | 2.521 | 2.739 | 2.638 |
| R14: Doctor ranking: average rating and recommendation rate (at least 10 reviews) | READ | 18.649 | 18.669 | 18.168 | 18.495 |
| R15: Pharmacy partners: most prescribed medicines per primary specialization in June 2026 | READ | 22.189 | 21.795 | 21.882 | 21.955 |
| R16: Finance: fees collected per clinic in June 2026 | READ | 10.142 | 9.853 | 9.711 | 9.902 |
| R17: Population health: completed appointments by patient age group and blood group (2026) | READ | 43.999 | 40.729 | 39.759 | 41.496 |
| R18: Search filter: Tamil-speaking doctors with Chennai clinics | READ | 4.092 | 3.906 | 3.841 | 3.946 |
| R19: City report: June 2026 completed consultations and latest consultation of every doctor with a Bengaluru clinic | READ | 4539.723 | 4525.400 | 4626.711 | 4563.945 |
| R20: Platform analytics: completed appointments per day and running total, June 2026 | READ | 9.084 | 8.117 | 7.868 | 8.356 |
| R21: Finance: completed in-clinic consultations whose fee is still unpaid | READ | 8.916 | 8.897 | 8.339 | 8.717 |
| R22: Support console: all appointments, newest first, page 4,001 (25 per page) | READ | 32.105 | 33.679 | 32.485 | 32.756 |
| R23: Verification team: look up a doctor by medical council registration number | READ | 0.029 | 0.025 | 0.026 | 0.027 |
| R24: Data quality: two active appointments of the same doctor in the same slot (double bookings) | READ | 22.293 | 22.216 | 22.375 | 22.295 |
| R25: Care quality: patients who saw 3 or more different doctors of the same specialization in 2026 | READ | 19.035 | 18.769 | 19.074 | 18.959 |
| W01: Book: patient 90 books doctor 217's 10:30 slot on Friday 3 July 2026 | WRITE | 0.496 | 0.460 | 0.438 | 0.465 |
| W02: Reception: check in the earliest BOOKED in-clinic appointment of 1 July 2026 | WRITE | 7.373 | 7.146 | 6.918 | 7.146 |
| W03: Doctor: add notes and a follow-up date to the prescription of appointment 18872 | WRITE | 0.132 | 0.134 | 0.133 | 0.133 |
| W04: Nightly job (run at 00:00 on 2 July 2026): BOOKED appointments whose slot has ended become NO_SHOW | WRITE | 9.262 | 9.003 | 9.370 | 9.212 |
| W05: Doctor on leave: cancel and refund all of doctor 504's appointments on 3 July 2026 | WRITE | 7.517 | 6.996 | 6.797 | 7.103 |
| **Total (sum of all 30)** | | **4868.563** | **4845.756** | **4941.802** | **4885.374** |

---

## Scan Types & Execution Analysis

| Query | Type | Avg (ms) | Scan Nodes from Plan | Why It Is Slow or Fast |
|---|---|---:|---|---|
| **R01** | READ | 2.191 | `Seq Scan on doctor_specializations \| Seq Scan on specializations \| Index Scan using doctors_pkey on doctors \| Index Scan using doctor_schedules_pkey on doctor_schedules \| Seq Scan on clinics` | Multi-table join (doctors, schedules, clinics, specializations) without composite foreign key indexes causes repeated sequential and index lookups. |
| **R02** | READ | 0.221 | `Index Scan using doctor_schedules_pkey on doctor_schedules \| Seq Scan on clinics` | Fast due to PK index scan on doctor_schedules(doctor_id, weekday, start_time), but does Seq Scan on small clinics table. |
| **R03** | READ | 10.604 | `Index Scan using doctor_schedules_pkey on doctor_schedules \| Seq Scan on appointments` | Slow due to full Seq Scan on appointments (150,000 rows) for the NOT EXISTS check on each generated slot. |
| **R04** | READ | 7.250 | `Seq Scan on appointments \| Index Scan using doctors_pkey on doctors \| Seq Scan on clinics` | Slow due to full Seq Scan on appointments table filtering by patient_id without an index on patient_id. |
| **R05** | READ | 5.159 | `Seq Scan on appointments \| Index Scan using patients_pkey on patients` | Slow due to Seq Scan on appointments filtering by doctor_id and DATE(slot_start AT TIME ZONE); expression prevents simple indexing. |
| **R06** | READ | 0.031 | `Index Scan using patients_phone_key on patients` | Extremely fast (<0.05 ms) due to unique B-tree index on patients(phone). |
| **R07** | READ | 0.044 | `Index Scan using prescriptions_appointment_id_key on prescriptions \| Index Scan using prescription_items_pkey on prescription_items` | Extremely fast (<0.05 ms) due to unique index on prescriptions(appointment_id) and PK index on prescription_items. |
| **R08** | READ | 19.054 | `Seq Scan on appointments \| Seq Scan on doctor_specializations \| Seq Scan on specializations` | Slow (~19 ms) because it sequentially scans the entire appointments table (150k rows) and joins unindexed specializations. |
| **R09** | READ | 8.213 | `Seq Scan on appointments` | Requires Seq Scan on all 150,000 appointments filtering by date range, consult_type, and status. |
| **R10** | READ | 16.630 | `Seq Scan on appointments \| Seq Scan on patients \| Index Scan using prescriptions_appointment_id_key on prescriptions \| Index Scan using prescription_items_pkey on prescription_items` | Slow (~17 ms) due to full Seq Scan on appointments and patients with array containment check and join with prescriptions. |
| **R11** | READ | 16.302 | `Seq Scan on appointments \| Seq Scan on prescriptions \| Index Scan using appointments_pkey on appointments` | Slow (~16 ms) due to Seq Scan on prescriptions and nested anti-join with appointments scanning full table. |
| **R12** | READ | 22.127 | `Seq Scan on appointments` | Slow (~22 ms) due to Seq Scan on appointments grouping by date_trunc on slot_start. |
| **R13** | READ | 2.638 | `Seq Scan on clinics \| Seq Scan on doctor_schedules` | Relatively fast (~2.6 ms) but uses Seq Scan on clinics and doctor_schedules; returns 0 rows due to NOT IN with NULL clinic_id bug. |
| **R14** | READ | 18.495 | `Seq Scan on appointments \| Seq Scan on doctor_reviews` | Slow (~18.5 ms) due to Seq Scan on appointments joined with Seq Scan on doctor_reviews with aggregation. |
| **R15** | READ | 21.955 | `Seq Scan on prescription_items \| Seq Scan on appointments \| Seq Scan on prescriptions \| Seq Scan on doctor_specializations \| Seq Scan on specializations` | Slow (~22 ms) due to heavy joins across 5 tables (prescription_items 243k rows, appointments 150k rows, etc.) with Seq Scans. |
| **R16** | READ | 9.902 | `Seq Scan on appointments \| Seq Scan on clinics` | Slow (~10 ms) due to full Seq Scan on appointments filtering by date range and payment_status. |
| **R17** | READ | 41.496 | `Seq Scan on appointments \| Seq Scan on patients` | Slow (~41.5 ms) due to full Seq Scan on appointments and full Seq Scan on 40,000 patients with age binning and grouping. |
| **R18** | READ | 3.946 | `Seq Scan on doctor_schedules \| Seq Scan on doctors \| Seq Scan on clinics` | Relatively fast (~3.9 ms) but performs Seq Scans on doctor_schedules, clinics, and doctors with array check languages @> ARRAY['Tamil']. |
| **R19** | READ | 4563.945 | `Seq Scan on doctor_schedules \| Seq Scan on clinics \| Seq Scan on doctors \| Seq Scan on appointments` | Extremely slow (~4564 ms) because of correlated subquery executing a full Seq Scan on appointments for every doctor found in Bengaluru. |
| **R20** | READ | 8.356 | `Seq Scan on appointments` | Slow (~8.4 ms) due to full Seq Scan on appointments filtering and window function aggregation over date range. |
| **R21** | READ | 8.717 | `Seq Scan on appointments` | Slow (~8.7 ms) due to full Seq Scan on appointments checking status='COMPLETED' and payment_status='PENDING'. |
| **R22** | READ | 32.756 | `Seq Scan on appointments` | Slow (~33 ms) due to high OFFSET (100,000) requiring PostgreSQL to scan and sort 100,025 rows sequentially. |
| **R23** | READ | 0.027 | `Index Scan using doctors_registration_no_key on doctors` | Extremely fast (<0.03 ms) due to unique B-tree index on doctors(registration_no). |
| **R24** | READ | 22.295 | `Seq Scan on appointments` | Slow (~22 ms) due to self-join on appointments table without index on (doctor_id, slot_start). |
| **R25** | READ | 18.959 | `Seq Scan on appointments \| Seq Scan on doctor_specializations` | Slow (~19 ms) due to Seq Scan on appointments joined to doctor_specializations with multi-group aggregation. |
| **W01** | WRITE | 0.465 | `Index Scan using doctor_schedules_pkey on doctor_schedules \| Index Scan using doctors_pkey on doctors` | Relatively fast (~0.5 ms) because it performs an INSERT with sub-selects checking schedule PK and doctor PK. |
| **W02** | WRITE | 7.146 | `Seq Scan on appointments \| Index Scan using appointments_pkey on appointments` | Slow (~7.1 ms) due to subquery with Seq Scan and Sort on appointments to find the earliest appointment. |
| **W03** | WRITE | 0.133 | `Index Scan using prescriptions_appointment_id_key on prescriptions` | Fast (~0.13 ms) because the UPDATE uses the unique index on prescriptions(appointment_id). |
| **W04** | WRITE | 9.212 | `Seq Scan on appointments` | Slow (~9.2 ms) because UPDATE does a Seq Scan on all 150,000 appointments checking status and slot_end. |
| **W05** | WRITE | 7.103 | `Seq Scan on appointments` | Slow (~7.1 ms) because UPDATE does a Seq Scan on appointments filtering by doctor_id and date range without doctor_id index. |
