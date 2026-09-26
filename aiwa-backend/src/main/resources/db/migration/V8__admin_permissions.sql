-- Fine-grained admin permissions (SUPPORT / FINANCE / SUPER_ADMIN)
CREATE TABLE IF NOT EXISTS admin_permissions (
    user_id    bigint      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    permission varchar(32) NOT NULL,
    PRIMARY KEY (user_id, permission)
);

-- Grant every existing admin the full permission set so nobody is locked out on upgrade.
INSERT INTO admin_permissions (user_id, permission)
SELECT u.id, p.perm
FROM users u
CROSS JOIN (VALUES ('SUPPORT'), ('FINANCE'), ('SUPER_ADMIN')) AS p(perm)
WHERE u.role = 'ADMIN'
ON CONFLICT DO NOTHING;
