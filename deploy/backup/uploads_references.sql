-- Every file the database points at, as "kind|value" lines (psql -tA -F "|"). Read by backup/reconcile_uploads.sh.
-- public values are URL paths (/files/public/<folder>/<file>), private values are the stored paths
-- (uploads/private/<sub>/<file>). Both live under the uploads volume.
SELECT 'public', profile_image_url FROM users WHERE profile_image_url LIKE '/files/public/%'
UNION ALL SELECT 'public', url FROM gallery_images WHERE url LIKE '/files/public/%'
UNION ALL SELECT 'private', national_id_front_path FROM provider_profiles WHERE national_id_front_path IS NOT NULL
UNION ALL SELECT 'private', national_id_back_path FROM provider_profiles WHERE national_id_back_path IS NOT NULL
UNION ALL SELECT 'private', selfie_path FROM provider_profiles WHERE selfie_path IS NOT NULL;
