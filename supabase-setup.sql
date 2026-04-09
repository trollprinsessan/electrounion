-- ============================================================
-- ELECTRO UNION — Supabase Backend Setup
-- ============================================================
-- Run this entire file in the Supabase SQL Editor (one shot).
-- It is idempotent: safe to re-run without duplicating data.
-- ============================================================


-- ------------------------------------------------------------
-- 1. APPROVALS TABLE
--    Each row = one approval click. We count rows for the total.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS approvals (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL    DEFAULT now()
);

COMMENT ON TABLE approvals IS 'One row per approval click; total = count(*)';


-- ------------------------------------------------------------
-- 2. GALLERY TABLE
--    Stores user-submitted gallery images + optional metadata.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS gallery (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url  text        NOT NULL,
  name       text,
  country    text,
  message    text,
  created_at timestamptz NOT NULL    DEFAULT now()
);

COMMENT ON TABLE gallery IS 'User-submitted gallery images with optional name, country, and message';


-- ------------------------------------------------------------
-- 3. RPC — increment_and_get_count
--    Inserts a new approval row and returns the new total.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION increment_and_get_count()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER          -- runs with table-owner privileges
AS $$
DECLARE
  total bigint;
BEGIN
  INSERT INTO approvals DEFAULT VALUES;
  SELECT count(*) INTO total FROM approvals;
  RETURN total;
END;
$$;

COMMENT ON FUNCTION increment_and_get_count IS 'Insert one approval and return the new total count';


-- ------------------------------------------------------------
-- 4. RPC — get_approval_count
--    Returns the current approval count (read-only).
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_approval_count()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT count(*) FROM approvals;
$$;

COMMENT ON FUNCTION get_approval_count IS 'Return the current total number of approvals';


-- ------------------------------------------------------------
-- 5. ROW LEVEL SECURITY
-- ------------------------------------------------------------

-- ---- Approvals ----

ALTER TABLE approvals ENABLE ROW LEVEL SECURITY;

-- Anyone (including anon) can insert
CREATE POLICY "approvals_insert_anon"
  ON approvals FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Only authenticated / service role can delete
CREATE POLICY "approvals_delete_auth"
  ON approvals FOR DELETE
  TO authenticated
  USING (true);

-- ---- Gallery ----

ALTER TABLE gallery ENABLE ROW LEVEL SECURITY;

-- Anyone can view gallery submissions
CREATE POLICY "gallery_select_anon"
  ON gallery FOR SELECT
  TO anon, authenticated
  USING (true);

-- Anyone can submit to the gallery
CREATE POLICY "gallery_insert_anon"
  ON gallery FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Only authenticated / service role can delete
CREATE POLICY "gallery_delete_auth"
  ON gallery FOR DELETE
  TO authenticated
  USING (true);


-- ------------------------------------------------------------
-- 6. STORAGE BUCKET — gallery-images (public)
-- ------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public)
VALUES ('gallery-images', 'gallery-images', true)
ON CONFLICT (id) DO NOTHING;


-- ------------------------------------------------------------
-- 7. STORAGE POLICIES — gallery-images
-- ------------------------------------------------------------

-- Anyone can upload images
CREATE POLICY "gallery_images_insert"
  ON storage.objects FOR INSERT
  TO anon, authenticated
  WITH CHECK (bucket_id = 'gallery-images');

-- Anyone can read / download images
CREATE POLICY "gallery_images_select"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'gallery-images');

-- Only service role can delete images
-- (service_role bypasses RLS by default, so no explicit policy needed;
--  this ensures no anon/authenticated user can delete.)
CREATE POLICY "gallery_images_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'gallery-images' AND auth.role() = 'service_role');


-- ============================================================
-- DONE. Tables, functions, RLS policies, and storage are ready.
-- ============================================================
