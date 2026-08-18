# Directory Layout & Structure

## 1. Monorepo Organization
```
onlook/
├── apps/
│   ├── web/
│   │   ├── client/                  # Primary Next.js 16 App Router application
│   │   │   ├── src/
│   │   │   │   ├── app/             # App Router pages, layouts, and API routes
│   │   │   │   │   ├── api/
│   │   │   │   │   │   ├── chat/    # AI chat streaming endpoint (route.ts)
│   │   │   │   │   │   └── trpc/    # tRPC API gateway (/api/trpc/[trpc])
│   │   │   │   │   ├── project/     # Canvas editor workspaces (/project/[id])
│   │   │   │   │   └── webhook/     # Stripe webhook processor
│   │   │   │   ├── components/
│   │   │   │   │   ├── editor/      # Canvas, frames, layers, style panels
│   │   │   │   │   └── store/       # MobX editor engine & state stores
│   │   │   │   ├── server/api/      # tRPC root router & sub-routers
│   │   │   │   └── utils/supabase/  # Client and server Supabase clients
│   │   │   └── public/              # Static assets & onlook-preload-script.js
│   │   ├── preload/                 # Injected preview iframe runtime bundle
│   │   │   └── script/              # DOM event capture & Penpal RPC bridge
│   │   └── server/                  # Fastify server (legacy/stub)
│   └── backend/                     # Local Supabase dev harness (config, migrations)
│       └── supabase/
│           ├── config.toml          # Ports: Postgres 54322, Kong 54321, Studio 54323
│           └── migrations/          # SQL schema migrations & RLS policies
├── packages/
│   ├── ai/                          # LLM agents, streaming, tools, prompt engine
│   ├── code-provider/               # Abstract filesystem & CodeSandbox / NodeFs runner
│   ├── constants/                   # Global configuration constants and templates
│   ├── db/                          # Drizzle ORM schemas, database client, seeders
│   ├── email/                       # Resend email templates & delivery
│   ├── file-system/                 # In-browser virtual filesystem (@zenfs/core)
│   ├── fonts/                       # Google Fonts loader and AST style injector
│   ├── git/                         # isomorphic-git wrappers
│   ├── github/                      # Octokit GitHub App REST API client
│   ├── growth/                      # Analytics and telemetry helpers
│   ├── image-server/                # Sharp image optimizer
│   ├── models/                      # Shared TypeScript DTOs, AST types, chat schemas
│   ├── parser/                      # Babel AST transformer for JSX/TSX and Tailwind
│   ├── penpal/                      # PostMessage RPC wrapper
│   ├── rpc/                         # Shared tRPC client/server contracts
│   ├── scripts/                     # Environment initialization scripts
│   ├── stripe/                      # Stripe SDK billing & plans
│   ├── types/                       # Shared utility types
│   ├── ui/                          # Radix UI + Tailwind component library
│   └── utility/                     # Common utilities (UUID, colors, DOM math)
└── docs/                            # Fumadocs documentation application
```

## 2. Key Entry Points & Configurations
- Root Monorepo Config: `package.json`, `bunfig.toml`
- Client Web Entry: `apps/web/client/src/app/layout.tsx`, `apps/web/client/next.config.ts`
- Editor Canvas Entry: `apps/web/client/src/app/project/[id]/page.tsx`
- Preload Bundle Entry: `apps/web/preload/script/index.ts`
- Backend API Entry: `apps/web/client/src/app/api/trpc/[trpc]/route.ts` & `src/server/api/root.ts`
- Database Schema Entry: `packages/db/src/schema/index.ts`
