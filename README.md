# Webtoon Voice Studio

Admin-created webtoon episodes, actor-created voice versions.

## Product shape

- Admin generates 9:16 webtoon cut images with `god-tibo-imagen`.
- Admin publishes episodes with cuts, characters, and dialogue lines.
- Actors create their own performance version of the same episode.
- Actors record each dialogue line in the browser.
- The app stores recordings and creates a hyperlapse timeline for a future ffmpeg worker.

## Stack

- Next.js App Router
- Prisma
- Postgres
- Browser `MediaRecorder`
- `god-tibo-imagen` CLI for image generation

## Setup

```bash
cp .env.example .env
docker compose up -d
npm install
npm run db:push
npm run db:seed
npm run dev -- --port 4175
```

Open:

- App: http://localhost:4175
- Admin: http://localhost:4175/admin
- Sample episode: http://localhost:4175/episodes/ex-interviewer

## Image Generation

The admin API calls the local `god-tibo-imagen` CLI path from `GTI_CLI_PATH`.

```env
GTI_CLI_PATH="C:/Users/SIMJAE/Desktop/pluck/god-tibo-imagen/src/cli/generate.js"
```

Generated images are saved under `public/generated`.

## Current Rendering Boundary

This project currently creates render jobs and timeline JSON. The next worker should:

1. Read `RenderJob.timeline`.
2. Pull cut images and recording audio.
3. Use ffmpeg to produce a 1080x1920 MP4.
4. Save the MP4 and create a `RenderedVideo` row.
