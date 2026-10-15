-- Review Low: a hidden gallery photo answers 404 at its file URL too (StaticResourceConfig). That check runs on
-- every gallery file request; hidden photos are few, so the index holds only them.
CREATE INDEX IF NOT EXISTS idx_gallery_images_hidden_url ON gallery_images (url) WHERE hidden = true;
