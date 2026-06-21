-- 더빙고 모바일: 로그인 유저가 자기 데이터만 CRUD 하도록 하는 쓰기 RLS
-- 소유 판정: 행의 userId(또는 performance.userId)가 auth.uid()에 매핑된 User.id 인지

-- ── User: 본인 행 조회/생성/수정 ──
DROP POLICY IF EXISTS "user_select_self" ON "User";
CREATE POLICY "user_select_self" ON "User"
  FOR SELECT TO authenticated USING ("supabaseUserId" = auth.uid()::text);

DROP POLICY IF EXISTS "user_insert_self" ON "User";
CREATE POLICY "user_insert_self" ON "User"
  FOR INSERT TO authenticated WITH CHECK ("supabaseUserId" = auth.uid()::text);

DROP POLICY IF EXISTS "user_update_self" ON "User";
CREATE POLICY "user_update_self" ON "User"
  FOR UPDATE TO authenticated
  USING ("supabaseUserId" = auth.uid()::text)
  WITH CHECK ("supabaseUserId" = auth.uid()::text);

-- ── Performance: 본인 것만 ──
DROP POLICY IF EXISTS "perf_all_own" ON "Performance";
CREATE POLICY "perf_all_own" ON "Performance"
  FOR ALL TO authenticated
  USING ("userId" IN (SELECT id FROM "User" WHERE "supabaseUserId" = auth.uid()::text))
  WITH CHECK ("userId" IN (SELECT id FROM "User" WHERE "supabaseUserId" = auth.uid()::text));

-- ── Recording: 본인 것만 ──
DROP POLICY IF EXISTS "rec_all_own" ON "Recording";
CREATE POLICY "rec_all_own" ON "Recording"
  FOR ALL TO authenticated
  USING ("userId" IN (SELECT id FROM "User" WHERE "supabaseUserId" = auth.uid()::text))
  WITH CHECK ("userId" IN (SELECT id FROM "User" WHERE "supabaseUserId" = auth.uid()::text));

-- ── RenderJob: 본인 공연의 잡만 (생성/조회) ──
DROP POLICY IF EXISTS "renderjob_own" ON "RenderJob";
CREATE POLICY "renderjob_own" ON "RenderJob"
  FOR ALL TO authenticated
  USING ("performanceId" IN (SELECT p.id FROM "Performance" p JOIN "User" u ON u.id = p."userId" WHERE u."supabaseUserId" = auth.uid()::text))
  WITH CHECK ("performanceId" IN (SELECT p.id FROM "Performance" p JOIN "User" u ON u.id = p."userId" WHERE u."supabaseUserId" = auth.uid()::text));

-- ── RenderedVideo: 본인 공연 영상 조회 ──
DROP POLICY IF EXISTS "video_select_own" ON "RenderedVideo";
CREATE POLICY "video_select_own" ON "RenderedVideo"
  FOR SELECT TO authenticated
  USING ("performanceId" IN (SELECT p.id FROM "Performance" p JOIN "User" u ON u.id = p."userId" WHERE u."supabaseUserId" = auth.uid()::text));

-- ── Storage: 녹음 업로드/조회, 영상 조회 (authenticated) ──
DROP POLICY IF EXISTS "rec_obj_insert" ON storage.objects;
CREATE POLICY "rec_obj_insert" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'recordings');

DROP POLICY IF EXISTS "rec_obj_select" ON storage.objects;
CREATE POLICY "rec_obj_select" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'recordings');

DROP POLICY IF EXISTS "vid_obj_select" ON storage.objects;
CREATE POLICY "vid_obj_select" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'rendered-videos');
