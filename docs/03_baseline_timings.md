# Baseline Timings (Phase 3: Workload 30)

Every query from `queries/workload_30.sql` was executed with `EXPLAIN (ANALYZE, BUFFERS)` in PostgreSQL on the `practo` database.
Each query was run **3 times**, and the table below reports all runs, their average, scan types, and performance characteristics.

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Find a doctor: verified dermatologists practising in Bengaluru, most experienced first | READ | 2.432 | 1.955 | 1.616 | 2.001 |
| R02: Doctor profile: doctor 217's weekly timetable with clinic names | READ | 0.324 | 0.203 | 0.227 | 0.251 |
| R03: Slot picker: doctor 217's free in-clinic slots on Friday 3 July 2026 | READ | 10.831 | 10.060 | 9.469 | 10.120 |
| R04: "My appointments": patient 90's upcoming appointments | READ | 7.673 | 7.165 | 7.010 | 7.283 |
| R05: Doctor's queue: doctor 16's appointments on 30 June 2026 | READ | 5.265 | 5.576 | 5.304 | 5.382 |
| R06: Sign-in with mobile number | READ | 0.030 | 0.048 | 0.024 | 0.034 |
| R07: Prescription view: the prescription and medicines of appointment 18872 | READ | 0.064 | 0.042 | 0.041 | 0.049 |
| R08: Quality: no-show rate per specialization in 2026 | READ | 20.826 | 21.017 | 20.611 | 20.818 |
| R09: Clinic experience: average minutes patients waited after their slot time, per clinic (June 2026) | READ | 8.319 | 8.276 | 8.076 | 8.224 |
| R10: Patient safety: patients allergic to penicillin who were prescribed amoxicillin | READ | 20.077 | 17.856 | 17.977 | 18.637 |
| R11: Care team: follow-ups due in the first week of July 2026 that the patient has not booked yet | READ | 16.683 | 16.731 | 17.049 | 16.821 |
| R12: Product analytics: video vs in-clinic appointments per month in 2026 | READ | 23.260 | 23.815 | 23.191 | 23.422 |
| R13: Clinic partnerships: clinics where no doctor has any schedule | READ | 2.747 | 2.499 | 2.501 | 2.582 |
| R14: Doctor ranking: average rating and recommendation rate (at least 10 reviews) | READ | 19.401 | 18.987 | 18.761 | 19.050 |
| R15: Pharmacy partners: most prescribed medicines per primary specialization in June 2026 | READ | 21.690 | 20.847 | 22.786 | 21.774 |
| R16: Finance: fees collected per clinic in June 2026 | READ | 9.902 | 9.798 | 9.241 | 9.647 |
| R17: Population health: completed appointments by patient age group and blood group (2026) | READ | 42.550 | 41.749 | 41.849 | 42.049 |
| R18: Search filter: Tamil-speaking doctors with Chennai clinics | READ | 3.940 | 3.917 | 3.909 | 3.922 |
| R19: City report: June 2026 completed consultations and latest consultation of every doctor with a Bengaluru clinic | READ | 4734.350 | 4680.990 | 4403.820 | 4606.387 |
| R20: Platform analytics: completed appointments per day and running total, June 2026 | READ | 8.791 | 8.337 | 8.362 | 8.497 |
| R21: Finance: completed in-clinic consultations whose fee is still unpaid | READ | 8.753 | 8.452 | 8.532 | 8.579 |
| R22: Support console: all appointments, newest first, page 4,001 (25 per page) | READ | 33.069 | 32.835 | 35.084 | 33.663 |
| R23: Verification team: look up a doctor by medical council registration number | READ | 0.028 | 0.027 | 0.029 | 0.028 |
| R24: Data quality: two active appointments of the same doctor in the same slot (double bookings) | READ | 23.040 | 24.084 | 24.495 | 23.873 |
| R25: Care quality: patients who saw 3 or more different doctors of the same specialization in 2026 | READ | 19.875 | 20.032 | 19.844 | 19.917 |
| W01: Book: patient 90 books doctor 217's 10:30 slot on Friday 3 July 2026 | WRITE | 1.906 | 0.486 | 0.503 | 0.965 |
| W02: Reception: check in the earliest BOOKED in-clinic appointment of 1 July 2026 | WRITE | 7.000 | 6.725 | 6.941 | 6.889 |
| W03: Doctor: add notes and a follow-up date to the prescription of appointment 18872 | WRITE | 0.174 | 0.140 | 0.142 | 0.152 |
| W04: Nightly job (run at 00:00 on 2 July 2026): BOOKED appointments whose slot has ended become NO_SHOW | WRITE | 10.344 | 8.847 | 9.858 | 9.683 |
| W05: Doctor on leave: cancel and refund all of doctor 504's appointments on 3 July 2026 | WRITE | 6.971 | 6.928 | 6.902 | 6.934 |
| **Total (sum of all 30)** | | **5070.315** | **5008.424** | **4734.154** | **4937.633** |

---

## Scan Types & Execution Analysis

| Query | Type | Avg (ms) | Scan Nodes from Plan | Why It Is Slow or Fast |
|---|---|---:|---|---|
| **R01** | READ | 2.001 | `Seq Scan on doctor_specializations | Seq Scan on specializations | Index Scan using doctors_pkey on doctors | Index Scan using doctor_schedules_pkey on doctor_schedules | Seq Scan on clinics` | Multi-table join (doctors, schedules, clinics, specializations) without composite foreign key indexes causes repeated sequential and index lookups. |
| **R02** | READ | 0.251 | `Index Scan using doctor_schedules_pkey on doctor_schedules | Seq Scan on clinics` | Fast due to PK index scan on doctor_schedules(doctor_id, weekday, start_time), but does Seq Scan on small clinics table. |
| **R03** | READ | 10.120 | `Index Scan using doctor_schedules_pkey on doctor_schedules | Seq Scan on appointments` | Slow due to full Seq Scan on appointments (150,000 rows) for the NOT EXISTS check on each generated slot. |
| **R04** | READ | 7.283 | `Seq Scan on appointments | Index Scan using doctors_pkey on doctors | Seq Scan on clinics` | Slow due to full Seq Scan on appointments table filtering by patient_id without an index on patient_id. |
| **R05** | READ | 5.382 | `Seq Scan on appointments | Index Scan using patients_pkey on patients` | Slow due to Seq Scan on appointments filtering by doctor_id and DATE(slot_start AT TIME ZONE); expression prevents simple indexing. |
| **R06** | READ | 0.034 | `Index Scan using patients_phone_key on patients` | Extremely fast (<0.05 ms) due to unique B-tree index on patients(phone). |
| **R07** | READ | 0.049 | `Index Scan using prescriptions_appointment_id_key on prescriptions | Index Scan using prescription_items_pkey on prescription_items` | Extremely fast (<0.05 ms) due to unique index on prescriptions(appointment_id) and PK index on prescription_items. |
| **R08** | READ | 20.818 | `Seq Scan on appointments | Seq Scan on doctor_specializations | Seq Scan on specializations` | Slow (~21 ms) because it sequentially scans the entire appointments table (150k rows) and joins unindexed specializations. |
| **R09** | READ | 8.224 | `Seq Scan on appointments` | Requires Seq Scan on all 150,000 appointments filtering by date range, consult_type, and status. |
| **R10** | READ | 18.637 | `Seq Scan on appointments | Seq Scan on patients | Index Scan using prescriptions_appointment_id_key on prescriptions | Index Scan using prescription_items_pkey on prescription_items` | Slow (~18 ms) due to full Seq Scan on appointments and patients with array containment check and join with prescriptions. |
| **R11** | READ | 16.821 | `Seq Scan on appointments | Seq Scan on prescriptions | Index Scan using appointments_pkey on appointments` | Slow (~17 ms) due to Seq Scan on prescriptions and nested anti-join with appointments scanning full table. |
| **R12** | READ | 23.422 | `Seq Scan on appointments` | Slow (~23 ms) due to Seq Scan on appointments grouping by date_trunc on slot_start. |
| **R13** | READ | 2.582 | `Seq Scan on clinics | Seq Scan on doctor_schedules` | Relatively fast (~2.5 ms) but uses Seq Scan on clinics and doctor_schedules; returns 0 rows due to NOT IN with NULL clinic_id bug. |
| **R14** | READ | 19.050 | `Seq Scan on appointments | Seq Scan on doctor_reviews` | Slow (~19 ms) due to Seq Scan on appointments joined with Seq Scan on doctor_reviews with aggregation. |
| **R15** | READ | 21.774 | `Seq Scan on prescription_items | Seq Scan on appointments | Seq Scan on prescriptions | Seq Scan on doctor_specializations | Seq Scan on specializations` | Slow (~22 ms) due to heavy joins across 5 tables (prescription_items 243k rows, appointments 150k rows, etc.) with Seq Scans. |
| **R16** | READ | 9.647 | `Seq Scan on appointments | Seq Scan on clinics` | Slow (~10 ms) due to full Seq Scan on appointments filtering by date range and payment_status. |
| **R17** | READ | 42.049 | `Seq Scan on appointments | Seq Scan on patients` | Slow (~42 ms) due to full Seq Scan on appointments and full Seq Scan on 40,000 patients with age binning and grouping. |
| **R18** | READ | 3.922 | `Seq Scan on doctor_schedules | Seq Scan on doctors | Seq Scan on clinics` | Relatively fast (~3.9 ms) but performs Seq Scans on doctor_schedules, clinics, and doctors with array check languages @> ARRAY['Tamil']. |
| **R19** | READ | 4606.387 | `Seq Scan on doctor_schedules | Seq Scan on clinics | Seq Scan on doctors | Seq Scan on appointments` | Extremely slow (~4600 ms) because of correlated subquery executing a full Seq Scan on appointments for every doctor found in Bengaluru. |
| **R20** | READ | 8.497 | `Seq Scan on appointments` | Slow (~8.5 ms) due to full Seq Scan on appointments filtering and window function aggregation over date range. |
| **R21** | READ | 8.579 | `Seq Scan on appointments` | Slow (~8.5 ms) due to full Seq Scan on appointments checking status='COMPLETED' and payment_status='PENDING'. |
| **R22** | READ | 33.663 | `Seq Scan on appointments` | Slow (~33 ms) due to high OFFSET (100,000) requiring PostgreSQL to scan and sort 100,025 rows sequentially. |
| **R23** | READ | 0.028 | `Index Scan using doctors_registration_no_key on doctors` | Extremely fast (<0.03 ms) due to unique B-tree index on doctors(registration_no). |
| **R24** | READ | 23.873 | `Seq Scan on appointments` | Slow (~24 ms) due to self-join on appointments table without index on (doctor_id, slot_start). |
| **R25** | READ | 19.917 | `Seq Scan on appointments | Seq Scan on doctor_specializations` | Slow (~20 ms) due to Seq Scan on appointments joined to doctor_specializations with multi-group aggregation. |
| **W01** | WRITE | 0.965 | `Index Scan using doctor_schedules_pkey on doctor_schedules | Index Scan using doctors_pkey on doctors` | Relatively fast (~1 ms) because it performs an INSERT with sub-selects checking schedule PK and doctor PK. |
| **W02** | WRITE | 6.889 | `Seq Scan on appointments | Index Scan using appointments_pkey on appointments` | Slow (~7 ms) due to subquery with Seq Scan and Sort on appointments to find the earliest appointment. |
| **W03** | WRITE | 0.152 | `Index Scan using prescriptions_appointment_id_key on prescriptions` | Fast (~0.15 ms) because the UPDATE uses the unique index on prescriptions(appointment_id). |
| **W04** | WRITE | 9.683 | `Seq Scan on appointments` | Slow (~9.7 ms) because UPDATE does a Seq Scan on all 150,000 appointments checking status and slot_end. |
| **W05** | WRITE | 6.934 | `Seq Scan on appointments` | Slow (~6.9 ms) because UPDATE does a Seq Scan on appointments filtering by doctor_id and date range without doctor_id index. |
