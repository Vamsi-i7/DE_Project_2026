SET search_path TO practo;

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA practo;

CREATE INDEX IF NOT EXISTS idx_clinics_city ON clinics (city_id, clinic_id);
CREATE INDEX IF NOT EXISTS idx_doctor_schedules_clinic ON doctor_schedules (clinic_id, doctor_id) WHERE clinic_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_doctor_specializations_spec ON doctor_specializations (spec_id, doctor_id);
CREATE INDEX IF NOT EXISTS idx_doctors_languages ON doctors USING gin (languages);
CREATE INDEX IF NOT EXISTS idx_doctors_verified_exp ON doctors (experience_years DESC) WHERE is_verified;

CREATE INDEX IF NOT EXISTS idx_patients_allergies ON patients USING gin (allergies);
CREATE INDEX IF NOT EXISTS idx_appointments_patient ON appointments (patient_id, appointment_id);
CREATE INDEX IF NOT EXISTS idx_prescription_items_med_trgm ON prescription_items USING gin (medicine_name practo.gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_prescriptions_followup ON prescriptions (follow_up_date) INCLUDE (prescription_id, appointment_id) WHERE follow_up_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_prescriptions_issued ON prescriptions (issued_at) INCLUDE (prescription_id, appointment_id);

CREATE INDEX IF NOT EXISTS idx_appointments_active_slots ON appointments (doctor_id, slot_start, appointment_id) WHERE status <> 'CANCELLED';
CREATE INDEX IF NOT EXISTS idx_appointments_patient_doctor_slot ON appointments (patient_id, doctor_id, slot_start) WHERE status <> 'CANCELLED';
CREATE INDEX IF NOT EXISTS idx_appointments_patient_booked ON appointments (patient_id, slot_start) INCLUDE (appointment_id, doctor_id, clinic_id, consult_type) WHERE status = 'BOOKED';
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_slot ON appointments (doctor_id, slot_start) INCLUDE (patient_id, status, checked_in_at, appointment_id, consult_ended_at);
CREATE INDEX IF NOT EXISTS idx_appointments_id_doctor ON appointments (appointment_id) INCLUDE (doctor_id);
CREATE INDEX IF NOT EXISTS idx_appointments_slot_start_desc ON appointments (slot_start DESC) INCLUDE (appointment_id, patient_id, doctor_id, status, consult_type);
CREATE INDEX IF NOT EXISTS idx_appointments_completed_pending ON appointments (slot_start DESC) INCLUDE (appointment_id, patient_id, clinic_id, fee) WHERE status = 'COMPLETED' AND payment_status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_appointments_paid_june ON appointments (slot_start, clinic_id, fee) WHERE payment_status = 'PAID';
CREATE INDEX IF NOT EXISTS idx_appointments_clinic_wait ON appointments (slot_start, clinic_id, consult_started_at) WHERE status = 'COMPLETED' AND consult_type = 'IN_CLINIC';
CREATE INDEX IF NOT EXISTS idx_appointments_completed_2026 ON appointments (slot_start, patient_id, doctor_id) WHERE status = 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_appointments_booked_inclinic ON appointments (slot_start) WHERE status = 'BOOKED' AND consult_type = 'IN_CLINIC';
CREATE INDEX IF NOT EXISTS idx_appointments_noshow_sweep ON appointments (slot_end) WHERE status IN ('BOOKED', 'CHECKED_IN') AND consult_ended_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_booked ON appointments (doctor_id, slot_start) WHERE status = 'BOOKED';
