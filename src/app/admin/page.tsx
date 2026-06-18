import Link from 'next/link';

import AdminImageGenerator from '@/components/AdminImageGenerator';

export default function AdminPage() {
  return (
    <main className="shell">
      <nav className="topbar">
        <Link href="/" className="brand">
          <span className="brand-mark">WV</span>
          <span>
            <strong>Admin Console</strong>
            <small>Create webtoon cuts and manage episode originals</small>
          </span>
        </Link>
      </nav>

      <section className="workspace single">
        <section className="panel">
          <div className="panel-head">
            <h1>Built-in Image Generation</h1>
            <span>private-codex runtime</span>
          </div>
          <div className="panel-content">
            <p className="muted">
              This project now contains its own image generation runtime. It does not depend
              on another local project path. Generated PNG files are saved into
              public/generated and can be attached to episode cuts.
            </p>
            <AdminImageGenerator />
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <h2>Admin Workflow</h2>
          </div>
          <div className="panel-content flow-list">
            <div><strong>1. Generate cuts</strong><span>Create 9:16 webtoon panels and check character consistency.</span></div>
            <div><strong>2. Publish episode</strong><span>Register cut images, speech bubbles, characters, and voice guides.</span></div>
            <div><strong>3. Open participation</strong><span>Actors keep the original webtoon fixed and create their own voice version.</span></div>
            <div><strong>4. Render shorts</strong><span>RenderJob combines cut images, bubble text, and recordings into a vertical timeline.</span></div>
          </div>
        </section>
      </section>
    </main>
  );
}
