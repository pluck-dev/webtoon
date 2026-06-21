-- 더빙고 모바일 앱(anon/authenticated)이 공개 콘텐츠를 읽을 수 있게 하는 RLS 정책
-- 적용: node로 실행하거나 Supabase SQL Editor에 붙여넣기

DROP POLICY IF EXISTS "read_published_episodes" ON "Episode";
CREATE POLICY "read_published_episodes" ON "Episode"
  FOR SELECT TO anon, authenticated USING (status = 'PUBLISHED');

DROP POLICY IF EXISTS "read_cuts" ON "Cut";
CREATE POLICY "read_cuts" ON "Cut"
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "read_dialogues" ON "Dialogue";
CREATE POLICY "read_dialogues" ON "Dialogue"
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "read_characters" ON "Character";
CREATE POLICY "read_characters" ON "Character"
  FOR SELECT TO anon, authenticated USING (true);
