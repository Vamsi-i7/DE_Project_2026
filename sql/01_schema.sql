-- sql/01_schema.sql : Practo Doctor Appointments (Phase 2)
-- Constraints only (PK, FK, UNIQUE, NOT NULL, CHECK). No tuning indexes.
-- Indexes that exist: the automatic ones behind every PRIMARY KEY / UNIQUE,
-- plus ONE partial unique index (uq_doctor_one_primary_spec) that enforces
-- "AT MOST one primary specialization per doctor", which a plain PK cannot.
-- "At least one" is not enforced (the seed data has exactly one for all 3,000 doctors).

DROP SCHEMA IF EXISTS practo CASCADE;
CREATE SCHEMA practo;
SET search_path TO practo;

-- ---------------------------------------------------------------- cities
CREATE TABLE cities (
    city_id    integer PRIMARY KEY,
    city_name  text    NOT NULL UNIQUE,
    state      text    NOT NULL
);

-- ------------------------------------------------------- specializations
CREATE TABLE specializations (
    spec_id    integer PRIMARY KEY,
    spec_name  text    NOT NULL UNIQUE
);

-- ---------------------------------------------------------------- doctors
CREATE TABLE doctors (
    doctor_id         integer      PRIMARY KEY,
    full_name         text         NOT NULL,
    registration_no   text         NOT NULL UNIQUE,
    gender            char(1)      NOT NULL,
    experience_years  smallint     NOT NULL,
    consultation_fee  numeric(8,2) NOT NULL,
    video_fee         numeric(8,2),                 -- NULL = doctor does not offer video
    languages         text[]       NOT NULL,
    is_verified       boolean      NOT NULL,
    joined_on         date         NOT NULL,
    CONSTRAINT ck_doctors_gender   CHECK (gender IN ('F', 'M')),
    CONSTRAINT ck_doctors_reg_no   CHECK (registration_no ~ '^[A-Z]{4}-[0-9]{6}$'),
    CONSTRAINT ck_doctors_exp      CHECK (experience_years BETWEEN 0 AND 60),
    CONSTRAINT ck_doctors_fee      CHECK (consultation_fee > 0),
    CONSTRAINT ck_doctors_video_fee CHECK (video_fee IS NULL OR video_fee > 0),
    CONSTRAINT ck_doctors_video_le_clinic CHECK (video_fee IS NULL OR video_fee <= consultation_fee),
    CONSTRAINT ck_doctors_languages CHECK (cardinality(languages) >= 1)
);

-- ------------------------------------------------- doctor_specializations
CREATE TABLE doctor_specializations (
    doctor_id   integer NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    spec_id     integer NOT NULL REFERENCES specializations(spec_id) ON DELETE RESTRICT,
    is_primary  boolean NOT NULL,
    PRIMARY KEY (doctor_id, spec_id)
);
CREATE UNIQUE INDEX uq_doctor_one_primary_spec
    ON doctor_specializations (doctor_id) WHERE is_primary;

-- ---------------------------------------------------------------- clinics
CREATE TABLE clinics (
    clinic_id    integer       PRIMARY KEY,
    clinic_name  text          NOT NULL,
    city_id      integer       NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    locality     text          NOT NULL,
    latitude     numeric(9,6)  NOT NULL,
    longitude    numeric(9,6)  NOT NULL,
    phone        text          NOT NULL UNIQUE,
    CONSTRAINT ck_clinics_lat   CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_clinics_lon   CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_clinics_phone CHECK (phone ~ '^\+[0-9]{2}-[0-9]{2}-[0-9]{7}$')
);

-- ------------------------------------------------------- doctor_schedules
CREATE TABLE doctor_schedules (
    doctor_id     integer  NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    weekday       smallint NOT NULL,                -- ISO: 1 = Monday ... 7 = Sunday
    start_time    time     NOT NULL,
    end_time      time     NOT NULL,
    clinic_id     integer  REFERENCES clinics(clinic_id) ON DELETE RESTRICT,  -- NULL = video window
    slot_minutes  smallint NOT NULL,
    PRIMARY KEY (doctor_id, weekday, start_time),
    CONSTRAINT ck_sched_weekday CHECK (weekday BETWEEN 1 AND 7),
    CONSTRAINT ck_sched_time    CHECK (end_time > start_time),
    CONSTRAINT ck_sched_slot    CHECK (slot_minutes IN (10, 15, 20)),
    CONSTRAINT ck_sched_window  CHECK (((extract(epoch FROM (end_time - start_time)) / 60)::int % slot_minutes) = 0)
);

-- --------------------------------------------------------------- patients
CREATE TABLE patients (
    patient_id   integer     PRIMARY KEY,
    full_name    text        NOT NULL,
    phone        text        NOT NULL UNIQUE,
    email        text        UNIQUE,                -- NULL = not provided
    dob          date        NOT NULL,
    gender       char(1)     NOT NULL,
    blood_group  text,                              -- NULL = not recorded
    allergies    text[],                            -- NULL = none recorded
    city_id      integer     NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    created_at   timestamptz NOT NULL,
    CONSTRAINT ck_patients_phone  CHECK (phone ~ '^[0-9]{10}$'),
    CONSTRAINT ck_patients_gender CHECK (gender IN ('F', 'M', 'X')),
    CONSTRAINT ck_patients_blood  CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    CONSTRAINT ck_patients_allergies CHECK (allergies IS NULL OR cardinality(allergies) >= 1),
    CONSTRAINT ck_patients_dob    CHECK (dob >= DATE '1900-01-01')
);

-- ------------------------------------------------------------ appointments
CREATE TABLE appointments (
    appointment_id      integer      PRIMARY KEY,
    patient_id          integer      NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,
    doctor_id           integer      NOT NULL REFERENCES doctors(doctor_id)   ON DELETE RESTRICT,
    clinic_id           integer      REFERENCES clinics(clinic_id) ON DELETE RESTRICT,  -- NULL = video
    consult_type        text         NOT NULL,
    booked_at           timestamptz  NOT NULL,
    slot_start          timestamptz  NOT NULL,
    slot_end            timestamptz  NOT NULL,
    reason              text         NOT NULL,
    status              text         NOT NULL,
    checked_in_at       timestamptz,
    consult_started_at  timestamptz,
    consult_ended_at    timestamptz,
    fee                 numeric(8,2) NOT NULL,      -- price snapshot at booking time
    payment_status      text         NOT NULL,
    CONSTRAINT ck_appt_consult_type CHECK (consult_type IN ('IN_CLINIC', 'VIDEO')),
    -- CHECKED_IN does not occur in the seed data, but W02 and W04 in workload_30.sql use it
    CONSTRAINT ck_appt_status       CHECK (status IN ('BOOKED', 'CHECKED_IN', 'CANCELLED', 'COMPLETED', 'NO_SHOW')),
    CONSTRAINT ck_appt_checkedin    CHECK (status <> 'CHECKED_IN'
                                           OR (consult_type = 'IN_CLINIC' AND checked_in_at IS NOT NULL)),
    CONSTRAINT ck_appt_payment      CHECK (payment_status IN ('PAID', 'PENDING', 'REFUNDED')),
    CONSTRAINT ck_appt_clinic_rule  CHECK ((consult_type = 'IN_CLINIC') = (clinic_id IS NOT NULL)),
    CONSTRAINT ck_appt_checkin_rule CHECK (checked_in_at IS NULL OR consult_type = 'IN_CLINIC'),
    CONSTRAINT ck_appt_clinic_done  CHECK (NOT (consult_type = 'IN_CLINIC' AND status = 'COMPLETED')
                                           OR checked_in_at IS NOT NULL),
    CONSTRAINT ck_appt_done_times   CHECK ((status = 'COMPLETED')
                                           = (consult_started_at IS NOT NULL AND consult_ended_at IS NOT NULL)),
    CONSTRAINT ck_appt_times_pair   CHECK ((consult_started_at IS NULL) = (consult_ended_at IS NULL)),
    CONSTRAINT ck_appt_consult_order CHECK (consult_started_at <= consult_ended_at),
    CONSTRAINT ck_appt_slot_order   CHECK (slot_end > slot_start),
    CONSTRAINT ck_appt_slot_len     CHECK (slot_end - slot_start IN (INTERVAL '10 minutes',
                                                                      INTERVAL '15 minutes',
                                                                      INTERVAL '20 minutes')),
    CONSTRAINT ck_appt_booked_first CHECK (booked_at <= slot_start),
    CONSTRAINT ck_appt_refund_rule  CHECK (payment_status <> 'REFUNDED' OR status = 'CANCELLED'),
    CONSTRAINT ck_appt_fee          CHECK (fee > 0)
);

-- ----------------------------------------------------------- prescriptions
CREATE TABLE prescriptions (
    prescription_id  integer      PRIMARY KEY,
    appointment_id   integer      NOT NULL UNIQUE REFERENCES appointments(appointment_id) ON DELETE RESTRICT,
    diagnosis        text         NOT NULL,
    notes            text,
    follow_up_date   date,                          -- NULL = no follow-up needed
    issued_at        timestamptz  NOT NULL,
    CONSTRAINT ck_presc_followup CHECK (follow_up_date IS NULL
        OR follow_up_date >= (issued_at AT TIME ZONE 'Asia/Kolkata')::date)
);

-- ----------------------------------------------------- prescription_items
CREATE TABLE prescription_items (
    prescription_id  integer   NOT NULL REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    line_no          smallint  NOT NULL,
    medicine_name    text      NOT NULL,
    dosage           text      NOT NULL,
    duration_days    smallint  NOT NULL,
    instructions     text,
    PRIMARY KEY (prescription_id, line_no),
    CONSTRAINT ck_items_line     CHECK (line_no > 0),
    CONSTRAINT ck_items_dosage   CHECK (dosage ~ '^[0-9]-[0-9]-[0-9]$'),
    CONSTRAINT ck_items_duration CHECK (duration_days > 0)
);

-- --------------------------------------------------------- doctor_reviews
CREATE TABLE doctor_reviews (
    review_id         integer      PRIMARY KEY,
    appointment_id    integer      NOT NULL UNIQUE REFERENCES appointments(appointment_id) ON DELETE RESTRICT,
    rating            smallint     NOT NULL,
    recommends        boolean      NOT NULL,
    wait_time_bucket  text         NOT NULL,
    review_text       text,
    created_at        timestamptz  NOT NULL,
    CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT ck_reviews_wait   CHECK (wait_time_bucket IN ('<15 min', '15-30 min', '30-60 min', '>1 hr'))
);

-- ------------------------------------------------------------------------
-- ck_doctors_video_le_clinic and ck_presc_followup are enabled; the data load is their test.
-- If the load rejects either one, remove it and record it as a data problem.
-- NOT added on purpose (data breaks them): checked_in_at <= consult_started_at (16,183 rows),
-- and UNIQUE (doctor_id, slot_start) for non-cancelled appointments (559 double-booked pairs).
