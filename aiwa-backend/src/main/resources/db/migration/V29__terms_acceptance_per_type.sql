-- AU-19 (owner rule 2026-10-04): which version of EACH document a user accepted.
-- users.accepted_terms_version held one version for every document type, so a
-- provider who accepted CUSTOMER_TERMS 1.0 counted as current on PROVIDER_TERMS 1.0.
CREATE TABLE IF NOT EXISTS terms_acceptances (
    id          bigserial    PRIMARY KEY,
    user_id     bigint       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type        varchar(32)  NOT NULL,
    version     varchar(255) NOT NULL,
    accepted_at timestamp(6) NOT NULL DEFAULT now(),
    CONSTRAINT ux_terms_acceptances_user_type UNIQUE (user_id, type)
);

-- Carry over what the old single field meant: the main document of the user's role.
INSERT INTO terms_acceptances (user_id, type, version, accepted_at)
SELECT id,
       CASE WHEN role = 'PROVIDER' THEN 'PROVIDER_TERMS' ELSE 'CUSTOMER_TERMS' END,
       accepted_terms_version,
       COALESCE(terms_accepted_at, now())
FROM users
WHERE accepted_terms_version IS NOT NULL AND role <> 'ADMIN'
  AND NOT EXISTS (SELECT 1 FROM terms_acceptances t WHERE t.user_id = users.id);
