-- BE-41: nearby search filters on a lat/lng bounding box before the distance
-- formula, so it can use this index instead of scanning every provider.
CREATE INDEX IF NOT EXISTS idx_provider_profiles_lat_lng ON provider_profiles (latitude, longitude);
