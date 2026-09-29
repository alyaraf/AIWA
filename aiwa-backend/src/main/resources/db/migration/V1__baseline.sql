-- Baseline schema: every table as it stood before V2.
--
-- This file used to be empty. Any database that was not first created by
-- Hibernate (ddl-auto) — i.e. every fresh production database — therefore
-- failed at V2 ("relation bookings does not exist") and, with
-- ddl-auto=validate in the prod profile, the application could not start.
--
-- Existing databases are unaffected: a database that already has tables but no
-- Flyway history is baselined at version 1 (spring.flyway.baseline-on-migrate),
-- so this script never runs there. It only runs on an empty database, which is
-- exactly the case it has to handle. No release ever applied the old empty V1
-- to a database that then migrated successfully (V2 fails on an empty schema),
-- so changing it cannot break a working deployment.
--
-- Deliberately left to later migrations (they create or add these themselves):
--   V2  bookings.proposed_*            V3  users.notify_*/quiet_hours_*, bookings.penalty/commission,
--   V4  bookings.checked_in_at             staff_members.skills, availabilities.staff_member_id
--   V5  platform_settings              V6  audit_log, reviews.hidden
--   V8  admin_permissions              V9  provider_profiles.*_override, support_numbers
--   V10 users.push_*                   V11 chat_messages.removed
--   V12 home_service_travel_fee / bookings.travel_fee
-- Enum columns are plain varchar with no CHECK constraint, so adding a value
-- to a Java enum never needs a migration.

CREATE TABLE IF NOT EXISTS users (
    id                     bigserial PRIMARY KEY,
    full_name              varchar(255) NOT NULL,
    email                  varchar(255) UNIQUE,
    phone                  varchar(255) UNIQUE,
    password               varchar(255) NOT NULL,
    role                   varchar(255) NOT NULL,
    gender                 varchar(255),
    profile_image_url      varchar(255),
    active                 boolean      NOT NULL DEFAULT true,
    preferred_language     varchar(255) NOT NULL DEFAULT 'EN',
    accepted_terms_version varchar(255),
    terms_accepted_at      timestamp(6),
    terms_accepted         boolean      NOT NULL DEFAULT false,
    search_radius_min_km   double precision,
    search_radius_max_km   double precision,
    totp_secret            varchar(255),
    totp_enabled           boolean      NOT NULL DEFAULT false,
    created_at             timestamp(6) NOT NULL DEFAULT now(),
    updated_at             timestamp(6)
);

CREATE TABLE IF NOT EXISTS provider_profiles (
    id                     bigserial PRIMARY KEY,
    user_id                bigint       NOT NULL UNIQUE REFERENCES users (id),
    business_name          varchar(255) NOT NULL,
    bio                    varchar(255),
    address                varchar(255),
    latitude               double precision,
    longitude              double precision,
    provider_type          varchar(255) NOT NULL DEFAULT 'INDIVIDUAL',
    primary_category       varchar(255),
    average_rating         double precision,
    total_reviews          integer DEFAULT 0,
    vacation_mode          boolean      NOT NULL DEFAULT false,
    offline_mode           boolean      NOT NULL DEFAULT false,
    travel_buffer_minutes  integer DEFAULT 0,
    cancellation_strikes   integer DEFAULT 0,
    settlement_paused      boolean      NOT NULL DEFAULT false,
    verification_status    varchar(255) NOT NULL DEFAULT 'PENDING_VERIFICATION',
    national_id_front_path varchar(255),
    national_id_back_path  varchar(255),
    selfie_path            varchar(255),
    rejection_reason       varchar(255),
    created_at             timestamp(6) NOT NULL DEFAULT now(),
    updated_at             timestamp(6)
);

CREATE TABLE IF NOT EXISTS provider_images (
    provider_id bigint NOT NULL REFERENCES provider_profiles (id),
    image_url   varchar(255)
);

CREATE TABLE IF NOT EXISTS services (
    id                 bigserial PRIMARY KEY,
    provider_id        bigint         NOT NULL REFERENCES provider_profiles (id),
    name               varchar(255)   NOT NULL,
    description        varchar(255),
    price              numeric(10, 2) NOT NULL,
    duration_minutes   integer        NOT NULL,
    category           varchar(255),
    pricing_type       varchar(255)   NOT NULL DEFAULT 'FIXED',
    transport_included boolean        NOT NULL DEFAULT false,
    active             boolean        NOT NULL DEFAULT true,
    created_at         timestamp(6)   NOT NULL DEFAULT now(),
    updated_at         timestamp(6)
);

CREATE TABLE IF NOT EXISTS staff_members (
    id          bigserial PRIMARY KEY,
    provider_id bigint       NOT NULL REFERENCES provider_profiles (id),
    full_name   varchar(255) NOT NULL,
    title       varchar(255),
    phone       varchar(255),
    active      boolean      NOT NULL DEFAULT true,
    created_at  timestamp(6) NOT NULL DEFAULT now(),
    updated_at  timestamp(6)
);

-- The pre-V3 one-row-per-day rule; V3 drops it in favour of a per-staff index.
CREATE TABLE IF NOT EXISTS availabilities (
    id                    bigserial PRIMARY KEY,
    provider_id           bigint       NOT NULL REFERENCES provider_profiles (id),
    day_of_week           varchar(255) NOT NULL,
    start_time            time(6)      NOT NULL,
    end_time              time(6)      NOT NULL,
    slot_duration_minutes integer,
    available             boolean      NOT NULL DEFAULT true,
    created_at            timestamp(6) NOT NULL DEFAULT now(),
    updated_at            timestamp(6),
    CONSTRAINT uk_availability_provider_day UNIQUE (provider_id, day_of_week)
);

CREATE TABLE IF NOT EXISTS saved_addresses (
    id              bigserial PRIMARY KEY,
    user_id         bigint       NOT NULL REFERENCES users (id),
    label           varchar(255) NOT NULL,
    address_line    varchar(255) NOT NULL,
    latitude        double precision,
    longitude       double precision,
    default_address boolean      NOT NULL DEFAULT false,
    created_at      timestamp(6) NOT NULL DEFAULT now(),
    updated_at      timestamp(6)
);

CREATE TABLE IF NOT EXISTS bookings (
    id                        bigserial PRIMARY KEY,
    customer_id               bigint         NOT NULL REFERENCES users (id),
    provider_id               bigint         NOT NULL REFERENCES provider_profiles (id),
    service_id                bigint         NOT NULL REFERENCES services (id),
    staff_member_id           bigint REFERENCES staff_members (id),
    saved_address_id          bigint REFERENCES saved_addresses (id),
    booking_date              date           NOT NULL,
    start_time                time(6)        NOT NULL,
    end_time                  time(6)        NOT NULL,
    booking_type              varchar(255)   NOT NULL DEFAULT 'SCHEDULED',
    estimated_arrival_minutes integer,
    home_service              boolean        NOT NULL DEFAULT false,
    status                    varchar(255),
    total_price               numeric(10, 2) NOT NULL,
    notes                     varchar(255),
    cancellation_reason       varchar(255),
    cancelled_by              varchar(255),
    cancelled_at              timestamp(6),
    rejection_reason          varchar(255),
    payment_status            varchar(255),
    payment_method            varchar(255),
    created_at                timestamp(6)   NOT NULL DEFAULT now(),
    updated_at                timestamp(6)
);

CREATE TABLE IF NOT EXISTS reviews (
    id          bigserial PRIMARY KEY,
    user_id     bigint       NOT NULL REFERENCES users (id),
    provider_id bigint       NOT NULL REFERENCES provider_profiles (id),
    booking_id  bigint       NOT NULL REFERENCES bookings (id),
    direction   varchar(255) NOT NULL DEFAULT 'CUSTOMER_TO_PROVIDER',
    rating      integer      NOT NULL,
    comment     varchar(1000),
    created_at  timestamp(6) NOT NULL DEFAULT now(),
    updated_at  timestamp(6)
);

CREATE TABLE IF NOT EXISTS review_tags (
    review_id bigint NOT NULL REFERENCES reviews (id),
    tag       varchar(255)
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id                bigserial PRIMARY KEY,
    booking_id        bigint        NOT NULL REFERENCES bookings (id),
    sender_id         bigint        NOT NULL REFERENCES users (id),
    type              varchar(255)  NOT NULL,
    message           varchar(2000) NOT NULL,
    read_by_recipient boolean       NOT NULL DEFAULT false,
    created_at        timestamp(6)  NOT NULL DEFAULT now(),
    updated_at        timestamp(6)
);

CREATE TABLE IF NOT EXISTS commission_ledger_entries (
    id                 bigserial PRIMARY KEY,
    provider_id        bigint         NOT NULL REFERENCES provider_profiles (id),
    booking_id         bigint REFERENCES bookings (id),
    booking_amount     numeric(10, 2) NOT NULL,
    commission_percent numeric(5, 2)  NOT NULL,
    commission_amount  numeric(10, 2) NOT NULL,
    status             varchar(255)   NOT NULL,
    settled_at         timestamp(6),
    created_at         timestamp(6)   NOT NULL DEFAULT now(),
    updated_at         timestamp(6)
);

CREATE TABLE IF NOT EXISTS complaints (
    id                   bigserial PRIMARY KEY,
    reporter_id          bigint        NOT NULL REFERENCES users (id),
    target_provider_id   bigint REFERENCES provider_profiles (id),
    target_user_id       bigint REFERENCES users (id),
    booking_id           bigint REFERENCES bookings (id),
    category             varchar(255)  NOT NULL,
    description          varchar(2000) NOT NULL,
    status               varchar(255),
    admin_notes          varchar(2000),
    resolved_by_admin_id bigint,
    flagged              boolean       NOT NULL DEFAULT false,
    created_at           timestamp(6)  NOT NULL DEFAULT now(),
    updated_at           timestamp(6)
);

CREATE TABLE IF NOT EXISTS moderation_cases (
    id          bigserial PRIMARY KEY,
    target_type varchar(255)  NOT NULL,
    target_id   bigint        NOT NULL,
    reason      varchar(1000),
    status      varchar(255)  NOT NULL DEFAULT 'OPEN',
    admin_id    bigint REFERENCES users (id),
    admin_notes varchar(1000),
    created_at  timestamp(6)  NOT NULL DEFAULT now(),
    updated_at  timestamp(6)
);

CREATE TABLE IF NOT EXISTS notifications (
    id                  bigserial PRIMARY KEY,
    user_id             bigint        NOT NULL REFERENCES users (id),
    type                varchar(255)  NOT NULL,
    title_en            varchar(255)  NOT NULL,
    title_ar            varchar(255)  NOT NULL,
    body_en             varchar(1000),
    body_ar             varchar(1000),
    related_booking_id  bigint,
    related_provider_id bigint,
    read                boolean       NOT NULL DEFAULT false,
    created_at          timestamp(6)  NOT NULL DEFAULT now(),
    updated_at          timestamp(6)
);

CREATE TABLE IF NOT EXISTS safety_events (
    id         bigserial PRIMARY KEY,
    booking_id bigint       NOT NULL REFERENCES bookings (id),
    actor_id   bigint       NOT NULL REFERENCES users (id),
    type       varchar(255) NOT NULL,
    latitude   double precision,
    longitude  double precision,
    notes      varchar(1000),
    created_at timestamp(6) NOT NULL DEFAULT now(),
    updated_at timestamp(6)
);

CREATE TABLE IF NOT EXISTS saved_providers (
    id          bigserial PRIMARY KEY,
    user_id     bigint       NOT NULL REFERENCES users (id),
    provider_id bigint       NOT NULL REFERENCES provider_profiles (id),
    created_at  timestamp(6) NOT NULL DEFAULT now(),
    updated_at  timestamp(6),
    CONSTRAINT uk_saved_provider UNIQUE (user_id, provider_id)
);

CREATE TABLE IF NOT EXISTS support_settings (
    id                      bigserial PRIMARY KEY,
    whatsapp_number         varchar(255) NOT NULL,
    whatsapp_number_display varchar(255),
    support_email           varchar(255),
    availability_hours_en   varchar(255),
    availability_hours_ar   varchar(255),
    whatsapp_enabled        boolean      NOT NULL DEFAULT true,
    created_at              timestamp(6) NOT NULL DEFAULT now(),
    updated_at              timestamp(6)
);

CREATE TABLE IF NOT EXISTS terms_policies (
    id         bigserial PRIMARY KEY,
    version    varchar(255) NOT NULL UNIQUE,
    type       varchar(255),
    content_en varchar(50000),
    content_ar varchar(50000),
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamp(6) NOT NULL DEFAULT now(),
    updated_at timestamp(6)
);
