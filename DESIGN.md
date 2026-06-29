# Design

## Source of truth
- Status: Active
- Last refreshed: 2026-06-29
- Primary product surfaces: Next.js public web (`/`, `/episodes`) and Flutter mobile app (`mobile/lib/screens/*`).
- Evidence reviewed:
  - `src/app/page.tsx`: previous web home mixed hero, marketplace stats, featured episode, and full collection.
  - `src/components/SiteHeader.tsx`: shared web navigation and auth entry.
  - `src/components/EpisodeBrowser.tsx`: reusable web collection filtering UI.
  - `mobile/lib/screens/home_screen.dart`: mobile discovery, AI creation entry, recommendation carousel.
  - `mobile/lib/screens/creator_screen.dart`: app-first AI/storyboard/webtoon creation and autosave.
  - `mobile/lib/screens/performer_screen.dart`: app-first recording, upload recovery, on-device render progress.
  - `mobile/lib/screens/root_screen.dart`: app shell tabs: home, feed, create, my work, profile.
  - `mobile/lib/theme.dart`, `src/app/globals.css`: shared warm cream/ink/coral/teal/gold brand language.

## Brand
- Personality: playful, creator-friendly, warm, slightly theatrical, and confident enough for first-time voice actors.
- Trust signals: clear scope boundary between web trial and app production, visible workflow steps, saved work/retry language, and result ownership.
- Avoid: generic SaaS gradients, cold enterprise tone, overpromising instant full production on web, hiding login/render constraints.

## Product goals
- Goals:
  - Make `/` explain what 더빙고 is before asking users to install the app.
  - Position web as introduction, SEO/share surface, and public gallery.
  - Position mobile as the full creation loop for AI webtoon creation, repeated recording, collaboration, and polished video making.
  - Route creation intent to app install instead of exposing web production tools publicly.
- Non-goals:
  - Do not make web a full replacement for the mobile app.
  - Do not add new dependencies or a separate design-system layer for this iteration.
  - Do not expose admin, my page, or production-tool navigation in the public website.
- Success signals:
  - First-time visitor can understand the product from `/` and see install intent clearly.
  - Existing collection remains reachable as a browse-only gallery at `/episodes`.
  - Primary CTAs clearly separate “구경하기” from “앱 설치/제작”.

## Personas and jobs
- Primary personas:
  - Curious visitor: wants to understand the app quickly and see proof.
  - Prospective creator: wants to see examples before installing the app.
  - Returning creator: wants to find saved recordings/videos in my page.
  - Mobile-first creator: wants to create AI webtoon cuts and make final videos in the app.
- User jobs:
  - Learn what 더빙고 does.
  - Browse what people can make with minimal commitment.
  - Move to the mobile app for creation.
- Key contexts of use: mobile web discovery, desktop browser trial, social/shared link landing, and authenticated my-page result checking.

## Information architecture
- Primary navigation: 앱 소개 (`/`), 작품 둘러보기 (`/episodes`), 사용법 (`/guidelines`).
- Core routes/screens:
  - `/`: app introduction landing, web/app boundary explanation, steps, proof, trial CTA.
  - `/episodes`: browse-only example collection and filters.
  - Mobile app: home/feed/create/my work/profile full production loop.
- Content hierarchy:
  - Landing starts with value proposition, then gallery/app boundary, workflow, app-first feature cards, example preview, and install CTA.
  - Collection page starts with gallery framing, then stats/featured item, filters, and browse-only grid.

## Design principles
- Principle 1: Explain before asking users to act. Landing copy must answer “what is this?” and “why app?” first.
- Principle 2: Keep the web/app boundary simple. Web explains and showcases; app owns creation.
- Principle 3: Reuse existing warm editorial marketplace language. Extend `market-shell`, token colors, rounded cards, and marquee proof instead of inventing a new brand.
- Principle 4: Every CTA should map to a clear user intent: learn, browse, or install the app.
- Tradeoffs:
  - Dynamic proof (episode counts/latest works) is more persuasive but requires DB-backed dynamic rendering.
  - Static landing is faster and simpler but weaker as product proof. This iteration may use light dynamic latest-work previews if already available.

## Visual language
- Color: cream/paper/card backgrounds, ink primary text, coral emotional emphasis, teal live/voice accent, gold app/create accent.
- Typography: heavy Korean display headlines, short bold labels, relaxed body copy; keep existing Tailwind token classes.
- Spacing/layout rhythm: wide max-width shell (`max-w-[1760px]`), rounded sections, responsive grids, generous hero spacing.
- Shape/radius/elevation: pill CTAs, `rounded-2xl` cards, soft borders, occasional deep ink panels for high-contrast CTA.
- Motion: marquee and soft pulse only as progressive enhancement; respect reduced motion.
- Imagery/iconography: use generated/sample webtoon cuts and simple phone/mockup cards; avoid needing new image assets unless explicitly requested.

## Components
- Existing components to reuse:
  - `SiteHeader`, `SiteFooter`, `EpisodeBrowser`, `AuthNav`, `EpisodeStudio`, `MyPerformanceCard`.
- New/changed components:
  - `/` page sections for app landing and web/app capability boundary.
  - `/episodes/page.tsx` collection page using the previous home collection pattern.
  - `SiteHeader` nav labels/hrefs updated for new IA.
- Variants and states:
  - Landing CTA variants: ink browse CTA, outlined learn CTA, gold app-install CTA.
  - Episode collection empty states remain inside `EpisodeBrowser`.
  - Web rendering status remains inside `EpisodeStudio` and my page cards.
- Token/component ownership: `src/app/globals.css` owns tokens and component-layer brand utilities.

## Accessibility
- Target standard: practical WCAG 2.1 AA for color contrast, keyboard focus, semantic sections, and alt text.
- Keyboard/focus behavior: all CTAs/filters remain buttons or links; preserve `:focus-visible` global ring.
- Contrast/readability: dark text on cream/paper, paper/gold on ink panels; avoid small low-contrast text for critical CTAs.
- Screen-reader semantics: meaningful section labels, decorative marquees `aria-hidden`, alt text for proof images when content-bearing.
- Reduced motion and sensory considerations: existing marquee/pulse media query disables animation for reduced motion.

## Responsive behavior
- Supported breakpoints/devices: mobile-first web, tablet, desktop; App Router server-rendered pages.
- Layout adaptations:
  - Landing hero stacks on mobile and splits into content + phone/proof composition on desktop.
  - Capability cards and steps use 1-column mobile, 2–4-column desktop grids.
  - Collection grid remains 2 columns mobile and expands at larger breakpoints.
- Touch/hover differences: hover lifts are enhancements only; touch targets should remain at least ~40px high.

## Interaction states
- Loading: dynamic collection/studio routes should have lightweight skeleton/loading UI where practical.
- Empty: keep clear “soon/none” states in collection and my page.
- Error: studio upload/render errors must remain recoverable with retry/continue language.
- Success: completed web render should point to my page/download; app success can emphasize final video creation.
- Disabled: recording/render buttons should stay disabled during active work.
- Offline/slow network, if applicable: web render polling already tolerates transient failures and points to my page after timeout.

## Content voice
- Tone: Korean, direct, energetic, creator-first, not corporate.
- Terminology:
  - Product name: 더빙고.
  - Web scope: 앱 소개, 작품 구경, 갤러리, 앱 설치 안내.
  - App scope: 본격 제작, AI 웹툰 만들기, 녹음, 영상 완성, 내 작업.
- Microcopy rules:
  - Avoid “웹에서 만들기/녹음하기” on public pages unless web production is intentionally reopened.
  - Prefer “웹에서 구경하고, 앱에서 직접 만드세요.”
  - Keep CTA labels action-oriented and concrete.

## Implementation constraints
- Framework/styling system: Next.js 16 App Router with Server Components by default; Tailwind v4 utilities without preflight; Clerk auth.
- Design-token constraints: use existing `@theme` tokens in `globals.css`; no new CSS framework/dependency.
- Performance constraints: keep landing mostly static; use Next `<Link>` for internal navigation prefetch/client transitions.
- Compatibility constraints: public web should not depend on authenticated production flows; app-install links can remain placeholder until store URLs exist.
- Test/screenshot expectations: run lint/build after route changes; use app docs from `node_modules/next/dist/docs` before App Router edits.

## Open questions
- [ ] App store links / owner / needed before final download CTA can leave “준비 중” state.
- [ ] Whether web landing should expose pricing or AI generation limits / owner / affects conversion copy.
- [ ] Whether public feed/community should become a top-level web route / owner / affects nav once feed exists on web.
