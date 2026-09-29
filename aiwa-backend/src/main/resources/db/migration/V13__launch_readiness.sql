-- V13: launch-readiness pass (backend checklist BE-1 … BE-21 + audit fixes).
-- Additive only: new columns are nullable or have defaults, nothing is dropped
-- except the otp_codes table, which no code has used since OTP moved to Redis.

-- ── Hibernate-generated enum CHECK constraints ────────────────────────────────
-- Databases first created by ddl-auto carry CHECK (col IN (...)) guards that are
-- never updated when a Java enum gains a value (new notification types, etc.),
-- so inserts would start failing. Enum columns are validated by the application.
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.conrelid::regclass::text AS tbl, c.conname
        FROM pg_constraint c
        JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE c.contype = 'c'
          AND n.nspname = current_schema()
          AND pg_get_constraintdef(c.oid) LIKE '%ARRAY[%'
          AND c.conrelid::regclass::text IN (
              'users', 'provider_profiles', 'services', 'availabilities', 'bookings',
              'reviews', 'chat_messages', 'commission_ledger_entries', 'complaints',
              'moderation_cases', 'notifications', 'safety_events', 'admin_permissions')
    LOOP
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.tbl, r.conname);
    END LOOP;
END $$;

-- ── Accounts ─────────────────────────────────────────────────────────────────
-- Session cut-off (password reset, phone change, admin deactivation).
ALTER TABLE users ADD COLUMN IF NOT EXISTS tokens_valid_after    timestamp(6) with time zone;
-- "Your area" discovery preference.
ALTER TABLE users ADD COLUMN IF NOT EXISTS search_area_label     varchar(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS search_area_latitude  double precision;
ALTER TABLE users ADD COLUMN IF NOT EXISTS search_area_longitude double precision;

ALTER TABLE saved_addresses ADD COLUMN IF NOT EXISTS archived boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS trusted_contacts (
    id           bigserial PRIMARY KEY,
    user_id      bigint       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name         varchar(120) NOT NULL,
    phone        varchar(32)  NOT NULL,
    relationship varchar(60),
    created_at   timestamp(6) NOT NULL DEFAULT now(),
    updated_at   timestamp(6)
);
CREATE INDEX IF NOT EXISTS idx_trusted_contacts_user ON trusted_contacts (user_id);

-- ── Providers ────────────────────────────────────────────────────────────────
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS verified_at            timestamp(6);
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS service_radius_km      double precision;
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS settlement_reported_at timestamp(6);
-- Best available date for providers approved before verified_at existed.
UPDATE provider_profiles
SET verified_at = COALESCE(updated_at, created_at)
WHERE verification_status = 'APPROVED' AND verified_at IS NULL;

CREATE TABLE IF NOT EXISTS staff_services (
    staff_member_id bigint NOT NULL REFERENCES staff_members (id) ON DELETE CASCADE,
    service_id      bigint NOT NULL REFERENCES services (id) ON DELETE CASCADE,
    PRIMARY KEY (staff_member_id, service_id)
);

CREATE TABLE IF NOT EXISTS provider_waitlist (
    id          bigserial PRIMARY KEY,
    user_id     bigint       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    category    varchar(255),
    latitude    double precision,
    longitude   double precision,
    notified_at timestamp(6),
    created_at  timestamp(6) NOT NULL DEFAULT now(),
    updated_at  timestamp(6)
);
CREATE INDEX IF NOT EXISTS idx_waitlist_open ON provider_waitlist (category) WHERE notified_at IS NULL;

-- ── Gallery: one row per photo, with a moderation flag (BE-19 / OPS-9) ───────
CREATE TABLE IF NOT EXISTS gallery_images (
    id          bigserial PRIMARY KEY,
    provider_id bigint       NOT NULL REFERENCES provider_profiles (id) ON DELETE CASCADE,
    url         varchar(512) NOT NULL,
    hidden      boolean      NOT NULL DEFAULT false,
    created_at  timestamp(6) NOT NULL DEFAULT now(),
    updated_at  timestamp(6)
);
CREATE INDEX IF NOT EXISTS idx_gallery_images_provider ON gallery_images (provider_id);

-- Copy the old element-collection rows once, turning stored disk paths
-- ("uploads/public/gallery/x.jpg", or with Windows backslashes) into the public
-- URL path the API serves ("/files/public/gallery/x.jpg") — BE-1.
-- provider_images is kept (unused) so this step can be re-checked or rolled back.
INSERT INTO gallery_images (provider_id, url, hidden, created_at)
SELECT pi.provider_id,
       CASE
           WHEN replace(pi.image_url, '\', '/') LIKE 'uploads/public/%'
               THEN '/files/public/' || substring(replace(pi.image_url, '\', '/') FROM 16)
           ELSE pi.image_url
       END,
       false,
       now()
FROM provider_images pi
WHERE pi.image_url IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gallery_images g WHERE g.provider_id = pi.provider_id);

UPDATE users
SET profile_image_url = '/files/public/' || substring(replace(profile_image_url, '\', '/') FROM 16)
WHERE replace(profile_image_url, '\', '/') LIKE 'uploads/public/%';

-- ── Bookings ─────────────────────────────────────────────────────────────────
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS proposed_at            timestamp(6);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS travel_fee_quote       numeric(10, 2);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS travel_fee_quote_status varchar(16);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS completion_note        varchar(500);

-- ── Reviews: provider replies (BE-18) ────────────────────────────────────────
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reply      varchar(1000);
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS replied_at timestamp(6);

-- ── Safety: SOS incident handling (BE-4) ─────────────────────────────────────
ALTER TABLE safety_events ADD COLUMN IF NOT EXISTS resolved         boolean NOT NULL DEFAULT false;
ALTER TABLE safety_events ADD COLUMN IF NOT EXISTS resolved_at      timestamp(6);
ALTER TABLE safety_events ADD COLUMN IF NOT EXISTS resolved_by_id   bigint REFERENCES users (id);
ALTER TABLE safety_events ADD COLUMN IF NOT EXISTS resolution_notes varchar(1000);

-- ── Terms: versions unique per document type, PDF link (BE-5 / BE-19) ────────
ALTER TABLE terms_policies ADD COLUMN IF NOT EXISTS pdf_url varchar(512);
DO $$
DECLARE
    r record;
BEGIN
    -- Drop the old single-column UNIQUE(version), whatever it was named.
    FOR r IN
        SELECT c.conname
        FROM pg_constraint c
        WHERE c.conrelid = 'terms_policies'::regclass
          AND c.contype = 'u'
          AND array_length(c.conkey, 1) = 1
          AND c.conkey[1] = (SELECT attnum FROM pg_attribute
                             WHERE attrelid = 'terms_policies'::regclass AND attname = 'version')
    LOOP
        EXECUTE format('ALTER TABLE terms_policies DROP CONSTRAINT %I', r.conname);
    END LOOP;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS ux_terms_type_version ON terms_policies (type, version);

-- Launch terms, so sign-up works on a fresh database (before, terms only came
-- from the local-profile seeder and GET /terms/latest failed in production).
-- Replace through the admin panel (Policies → Publish) once legal signs off.
INSERT INTO terms_policies (version, type, content_en, content_ar, active, created_at)
SELECT '1.0', 'CUSTOMER_TERMS',
       'AIWA connects customers with verified beauty and grooming providers across Egypt. '
    || 'By using AIWA you agree that: (1) bookings are requests until the provider accepts them; '
    || '(2) you pay the provider in cash when the service is completed, at the price shown when you booked, '
    || 'plus any travel fee you accepted; (3) you can cancel an accepted booking free of charge up to the '
    || 'cancellation cutoff shown in the app, and repeated no-shows may restrict your account; '
    || '(4) you treat providers with respect, and AIWA may suspend accounts that break these terms; '
    || '(5) you can raise a complaint or payment dispute from the booking and AIWA support will review it; '
    || '(6) in an emergency use the SOS button, which alerts AIWA support and your trusted contacts, and call 122. '
    || 'Personal data is used only to run your bookings, keep the platform safe and meet legal obligations.',
       'تربط AIWA العملاء بمقدمي خدمات تجميل وعناية موثقين في جميع أنحاء مصر. '
    || 'باستخدامك AIWA فإنك توافق على ما يلي: (1) الحجز طلب حتى يقبله مقدم الخدمة؛ '
    || '(2) تدفع لمقدم الخدمة نقداً عند إتمام الخدمة بالسعر المعروض وقت الحجز مضافاً إليه أي رسوم انتقال وافقت عليها؛ '
    || '(3) يمكنك إلغاء الحجز المقبول مجاناً قبل موعد الإلغاء الموضح في التطبيق، وقد يؤدي تكرار عدم الحضور إلى تقييد حسابك؛ '
    || '(4) تتعامل مع مقدمي الخدمة باحترام، ويحق لـ AIWA إيقاف الحسابات المخالفة لهذه الشروط؛ '
    || '(5) يمكنك تقديم شكوى أو نزاع دفع من صفحة الحجز وسيراجعه دعم AIWA؛ '
    || '(6) في حالات الطوارئ استخدم زر الاستغاثة الذي ينبه دعم AIWA وجهات اتصالك الموثوقة، واتصل بـ 122. '
    || 'تُستخدم بياناتك الشخصية فقط لإدارة حجوزاتك والحفاظ على أمان المنصة والوفاء بالالتزامات القانونية.',
       true, now()
WHERE NOT EXISTS (SELECT 1 FROM terms_policies WHERE type = 'CUSTOMER_TERMS' AND active = true);

INSERT INTO terms_policies (version, type, content_en, content_ar, active, created_at)
SELECT '1.0', 'PROVIDER_TERMS',
       'Providers on AIWA agree that: (1) your identity and business details are verified before you can '
    || 'receive bookings, and must stay accurate; (2) you set your own services, prices, working hours and any '
    || 'home-service travel fee, and you honour the price the customer booked at; (3) customers pay you in cash, '
    || 'and AIWA charges a platform commission on the service price (not on travel fees), recorded after each '
    || 'completed booking; (4) commission must be settled by its due date — overdue or over-limit balances pause '
    || 'new bookings until settled; (5) cancelling accepted bookings or not showing up counts against your account '
    || 'and may carry a penalty; (6) you keep customers'' personal details confidential and use them only for the '
    || 'booking; (7) AIWA may hide content and suspend accounts that break these terms or endanger anyone.',
       'يوافق مقدمو الخدمة على AIWA على ما يلي: (1) يتم التحقق من هويتك وبيانات نشاطك قبل استقبال الحجوزات، ويجب أن تظل دقيقة؛ '
    || '(2) تحدد خدماتك وأسعارك ومواعيد عملك وأي رسوم انتقال للخدمة المنزلية، وتلتزم بالسعر الذي حجز به العميل؛ '
    || '(3) يدفع العملاء لك نقداً، وتحصل AIWA على عمولة منصة من سعر الخدمة (وليس من رسوم الانتقال) تُسجل بعد كل حجز مكتمل؛ '
    || '(4) يجب تسوية العمولة قبل موعد استحقاقها — الأرصدة المتأخرة أو المتجاوزة للحد توقف الحجوزات الجديدة حتى التسوية؛ '
    || '(5) إلغاء الحجوزات المقبولة أو عدم الحضور يُحتسب على حسابك وقد تترتب عليه غرامة؛ '
    || '(6) تحافظ على سرية بيانات العملاء الشخصية وتستخدمها للحجز فقط؛ '
    || '(7) يحق لـ AIWA إخفاء المحتوى وإيقاف الحسابات المخالفة لهذه الشروط أو التي تعرّض أي شخص للخطر.',
       true, now()
WHERE NOT EXISTS (SELECT 1 FROM terms_policies WHERE type = 'PROVIDER_TERMS' AND active = true);

-- ── Integrity guards against races (only created when existing data allows) ──
DO $$
BEGIN
    -- One review per booking and direction (the service check alone can race).
    IF NOT EXISTS (SELECT booking_id, direction FROM reviews GROUP BY booking_id, direction HAVING count(*) > 1) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS ux_reviews_booking_direction ON reviews (booking_id, direction);
    END IF;
    -- One commission entry per booking (completion and payment confirmation can race).
    IF NOT EXISTS (SELECT booking_id FROM commission_ledger_entries WHERE booking_id IS NOT NULL
                   GROUP BY booking_id HAVING count(*) > 1) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS ux_ledger_booking ON commission_ledger_entries (booking_id)
            WHERE booking_id IS NOT NULL;
    END IF;
END $$;

-- ── Indexes for the hot query paths (lists, conflict checks, counters) ───────
CREATE INDEX IF NOT EXISTS idx_bookings_customer_created ON bookings (customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_customer_status  ON bookings (customer_id, status);
CREATE INDEX IF NOT EXISTS idx_bookings_provider_date    ON bookings (provider_id, booking_date, start_time);
CREATE INDEX IF NOT EXISTS idx_bookings_provider_status  ON bookings (provider_id, status);
CREATE INDEX IF NOT EXISTS idx_bookings_staff_date       ON bookings (staff_member_id, booking_date);
CREATE INDEX IF NOT EXISTS idx_bookings_status           ON bookings (status);
CREATE INDEX IF NOT EXISTS idx_bookings_payment_status   ON bookings (payment_status);
CREATE INDEX IF NOT EXISTS idx_bookings_saved_address    ON bookings (saved_address_id);
CREATE INDEX IF NOT EXISTS idx_bookings_created          ON bookings (created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user        ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread      ON notifications (user_id) WHERE read = false;
CREATE INDEX IF NOT EXISTS idx_reviews_provider          ON reviews (provider_id, direction, hidden);
CREATE INDEX IF NOT EXISTS idx_reviews_user              ON reviews (user_id);
CREATE INDEX IF NOT EXISTS idx_chat_booking              ON chat_messages (booking_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ledger_provider_status    ON commission_ledger_entries (provider_id, status);
CREATE INDEX IF NOT EXISTS idx_ledger_status             ON commission_ledger_entries (status, created_at);
CREATE INDEX IF NOT EXISTS idx_complaints_status         ON complaints (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_reporter       ON complaints (reporter_id);
CREATE INDEX IF NOT EXISTS idx_moderation_status_type    ON moderation_cases (status, target_type);
CREATE INDEX IF NOT EXISTS idx_safety_booking            ON safety_events (booking_id);
CREATE INDEX IF NOT EXISTS idx_safety_open_sos           ON safety_events (created_at DESC) WHERE type = 'SOS' AND resolved = false;
CREATE INDEX IF NOT EXISTS idx_saved_addresses_user      ON saved_addresses (user_id);
CREATE INDEX IF NOT EXISTS idx_services_provider         ON services (provider_id, active);
CREATE INDEX IF NOT EXISTS idx_staff_provider            ON staff_members (provider_id);
CREATE INDEX IF NOT EXISTS idx_availabilities_provider   ON availabilities (provider_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_provider_status           ON provider_profiles (verification_status);
CREATE INDEX IF NOT EXISTS idx_users_role                ON users (role, active);
CREATE INDEX IF NOT EXISTS idx_users_push_token          ON users (push_token);

-- ── Dead table (BE-21): OTP codes live in Redis ──────────────────────────────
DROP TABLE IF EXISTS otp_codes;
