-- Chat messages can now be reported and, once reviewed, redacted. The original
-- text stays in the row for audit; the API substitutes a fixed placeholder for
-- both parties once removed=true. targetType 'CHAT_MESSAGE' on moderation_cases
-- needs no schema change — it's a plain varchar enum column.
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS removed boolean NOT NULL DEFAULT false;
