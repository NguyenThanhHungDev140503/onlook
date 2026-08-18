# Onlook Monorepo: Architecture, Feature Set, and Backend Analysis

## Executive Summary

**Onlook** is an open-source visual development tool and design-to-code editor designed for web interfaces (Next.js, React, Tailwind CSS). It combines an interactive infinite canvas, direct DOM visual manipulation with bidirectional AST code synchronization, AI-powered generation and multi-file editing, remote ephemeral development sandboxes (CodeSandbox / NodeFs), GitHub integration, project branching, and one-click deployment/hosting (via Freestyle / Custom domains).

This report presents a thorough, primary-source examination of the entire monorepo based on source code, package configurations, schemas, and deployment artifacts.

---

## 1. Feature Breakdown & Capabilities

Based on `@onlook/web-client`, `@onlook/ai`, `@onlook/db`, `@onlook/models`, and `@onlook/code-provider`, Onlook provides the following core capabilities:

### 1.1. Visual Code Editor & Infinite Canvas
* **Infinite Multi-device Canvas**: Manages multiple responsive frames/viewports on an interactive canvas (`apps/web/client/src/components/store/editor/canvas/index.ts`, `apps/web/client/src/components/store/editor/frames/index.ts`).
* **Bidirectional DOM-to-Code Sync**: Renders the running Next.js app in iframes. The preload script (`apps/web/preload/script/index.ts`) interacts with the parent window using RPC via `@onlook/penpal`. Elements carry data attributes with sourcemaps pointing to source files (`packages/parser/src/index.ts`).
* **Visual Style & Layout Manipulation**: Directly edit Tailwind classes, CSS properties, typography, margins/padding, colors, images, and layout hierarchies without writing raw code (`apps/web/client/src/components/store/editor/style/index.ts`, `apps/web/client/src/components/store/editor/element/index.ts`).
* **AST Parsing & Code Generation**: Uses Babel parser/traverse (`packages/parser/package.json:39-40`) to manipulate JSX/TSX ASTs in real-time, inserting components, modifying styles, or restructuring DOM hierarchies (`packages/parser/src/index.ts`).
* **Integrated Web Terminal & Code Mirror Editor**: Real-time terminal (`@xterm/xterm`, `@xterm/addon-fit`) and integrated code diff/merge editor (`@uiw/react-codemirror`, `react-codemirror-merge`) in `apps/web/client/package.json:67-71, 101`.

### 1.2. AI-Powered Design & Code Generation
* **Multi-Provider AI Engine**: Built on Vercel AI SDK (`ai: 5.0.26`, `@ai-sdk/react: 2.0.60`), OpenRouter (`@openrouter/ai-sdk-provider: 1.2.0`), Anthropic, OpenAI, AWS Bedrock, and Google Vertex AI (`apps/web/client/src/env.ts:22-41`, `packages/ai/src/chat/providers.ts`).
* **Agentic Toolset**: Features automated tools such as `read-file`, `write-file`, `search-replace-edit`, `fuzzy-edit-file`, `terminal-command`, `web-search` (Exa), `scrape-url` (Firecrawl), `check-errors`, `typecheck`, and `upload-image` (`packages/ai/src/tools/classes/index.ts`).
* **AI Apply Engine**: High-fidelity diff application using Fast Apply / Morph / Relace models (`apps/web/client/src/env.ts:22-23`, `packages/ai/src/apply/index.ts`).
* **Chat Route & Observability**: Streaming chat endpoint at `apps/web/client/src/app/api/chat/route.ts` with telemetry logged to Langfuse and PostHog (`apps/web/client/src/app/api/chat/route.ts:2, 83`, `apps/web/client/src/env.ts:55-59`).

### 1.3. Cloud Sandboxes & File System Abstraction
* **Remote Ephemeral Dev Environments**: Runs projects inside CodeSandbox VM sandboxes via `@codesandbox/sdk` (`packages/code-provider/src/providers/codesandbox/index.ts`).
* **Local In-Browser Virtual File System**: Browser-based file system backed by `@zenfs/core` / `@zenfs/dom` and indexedDB for local caching and offline operation (`packages/file-system/package.json:46-47`, `apps/web/client/src/components/store/editor/cache/unified-cache.ts`).
* **Provider Abstraction**: Unified `CodeProvider` interface supporting both `CodeSandbox` and `NodeFs` (`packages/code-provider/src/index.ts:17-37`).

### 1.4. GitHub Import, Branching & Version Control
* **GitHub App Authentication & Import**: Clone repositories directly into sandboxes and commit branches (`packages/github/package.json`, `apps/web/client/src/server/api/routers/github.ts`).
* **In-Browser Git Client**: Pure JavaScript Git implementation using `isomorphic-git` (`packages/git/package.json:38-39`).
* **Branch Management**: Multiple branch workspaces per project with migration and conflict tracking (`packages/db/src/schema/project/branch.ts`, `apps/web/client/src/server/api/routers/project/branch.ts`).

### 1.5. Publishing, Custom Domains & Hosting
* **One-Click Deployments**: Integration with Freestyle sandboxes / hosting API (`freestyle-sandboxes`, `apps/web/client/src/server/api/routers/publish/index.ts`, `apps/web/client/src/server/api/routers/domain/freestyle.ts`).
* **Custom Domain Verification**: CNAME and TXT DNS verification for custom user domains (`apps/web/client/src/server/api/routers/domain/custom.ts`, `packages/db/src/schema/domain/custom/index.ts`).

### 1.6. Teams, Billing & Collaboration
* **Team Members & Invitations**: Role-based access control (Admin, Member, Viewer) with email invite workflows via Resend (`apps/web/client/src/server/api/routers/project/member.ts`, `apps/web/client/src/server/api/routers/project/invitation.ts`, `packages/db/src/schema/project/invitation.ts`).
* **Stripe Subscriptions & Usage Limits**: Tiered subscriptions, webhook processors, and token/message usage metering (`packages/stripe/package.json`, `apps/web/client/src/app/webhook/stripe/route.ts`, `packages/db/src/schema/subscription/index.ts`).
* **Realtime State & Presence**: Supabase Realtime integration with RLS (`apps/backend/supabase/migrations/0007_realtime_rls.sql`) and feature flag `NEXT_PUBLIC_FEATURE_COLLABORATION` (`apps/web/client/src/env.ts:77`).

---

## 2. Monorepo Architecture: Directory by Directory

The repository is structured as a Bun Monorepo (`package.json:13-19`):

```
onlook/
├── apps/
│   ├── web/
│   │   ├── client/       # Main Next.js 16 App Router full-stack web application
│   │   ├── preload/      # Injected browser bundle for iframe DOM manipulation
│   │   └── server/       # Standalone Fastify WebSocket/tRPC server (deprecated/legacy)
│   └── backend/          # Local Supabase configuration, schema migrations, and Edge Functions
├── packages/
│   ├── ai/               # AI prompts, streaming logic, agents, tool execution, LLM providers
│   ├── code-provider/    # Sandbox provider abstraction (CodeSandbox SDK, NodeFs)
│   ├── constants/        # System-wide constants, templates, URLs, and ports
│   ├── db/               # Drizzle ORM schema, migrations, seeders, and PG connection
│   ├── email/            # Resend email templates and delivery helpers
│   ├── file-system/      # In-browser virtual file system (@zenfs/core, IndexedDB)
│   ├── fonts/            # Web font loader and Google Font indexers
│   ├── git/              # isomorphic-git wrappers for client-side git operations
│   ├── github/           # GitHub App REST API integration and Octokit authentication
│   ├── growth/           # Growth tracking, marketing, and onboarding helpers
│   ├── image-server/     # Sharp-based image optimization and processing (Node.js)
│   ├── models/           # Shared TypeScript models, DTOs, AST types, and chat schemas
│   ├── parser/           # Babel AST parser/transformer for JSX/TSX/Tailwind
│   ├── penpal/           # PostMessage RPC wrapper connecting Canvas host and Preview iframe
│   ├── rpc/              # Shared tRPC interfaces between web-client and web-server
│   ├── scripts/          # Interactive CLI for environment setup (`bun run setup:env`)
│   ├── stripe/           # Stripe billing SDK, product plans, and customer helpers
│   ├── types/            # Global TypeScript utilities and shared interfaces
│   ├── ui/               # Reusable Tailwind + Radix UI component library (Shadcn pattern)
│   └── utility/          # Common helpers (UUID, string manipulation, error formatting)
└── docs/                 # Documentation website built with Fumadocs + Next.js
```

### Detailed Breakdown of Key Modules

#### `apps/web/client`
* **Framework**: Next.js 16 (React 19, Turbopack, Tailwind CSS 4).
* **Role**: Primary user-facing web app and host for both client UI and full-stack API.
* **Architecture**:
  * **Frontend UI**: Canvas rendering, MobX state management (`apps/web/client/src/components/store/editor/engine.ts`), Monaco/CodeMirror editors, panels for layers, styles, chat, and settings.
  * **Backend API**: Next.js Route Handlers at `/api/trpc/[trpc]` (`apps/web/client/src/app/api/trpc/[trpc]/route.ts`) and `/api/chat` (`apps/web/client/src/app/api/chat/route.ts`).
  * **Database Access**: Direct connection to Postgres/Supabase via `@onlook/db` and Drizzle ORM inside protected/public tRPC procedures (`apps/web/client/src/server/api/trpc.ts`).

#### `apps/web/preload`
* **Build Target**: Browser bundle outputted to `apps/web/client/public/onlook-preload-script.js` (`apps/web/preload/package.json:8`).
* **Role**: Script injected into the running user app inside the canvas iframe. It captures DOM events, computes bounding boxes, applies CSS stylesheet overrides, handles element drag/drop, text editing, and communicates back to Onlook's editor engine via Penpal postMessage RPC (`apps/web/preload/script/index.ts:37-68`).

#### `apps/web/server`
* **Framework**: Fastify 5 + `@fastify/websocket` + `fastifyTRPCPlugin` (`apps/web/server/package.json:26-30`, `apps/web/server/src/server.ts:1-20`).
* **Role & Status**: Standalone Fastify server running on port 8080.
* **Source Truth**: As stated in `docs/content/docs/developers/architecture.mdx:31`: *"Server-side code (Fastify.js - unused for now)"*. The route handlers in `apps/web/server/src/router/routes/sandbox.ts` only return mock/stub responses (`return 'hi ' + input`). The client has an optional forwarding router (`apps/web/client/src/server/api/routers/forward/editor.ts`) which is not active in the main router.

#### `apps/backend`
* **Tech Stack**: Supabase CLI, PostgreSQL 15+, GoTrue Auth, Storage, Kong Gateway, Deno Edge Functions (`apps/backend/package.json:17`, `apps/backend/supabase/config.toml`).
* **Role**: Local development backend harness. Provides local PostgreSQL database (port `54322`), Supabase API Gateway (port `54321`), Studio GUI (port `54323`), and S3 storage bucket `preview_images`.

---

## 3. Backend Architecture Analysis

### 3.1. Is a Separate Backend Server Needed?
**No.** A separate custom Node/Fastify application server is **NOT** needed. 

* The Next.js web application (`apps/web/client`) contains all server-side business logic using Next.js App Router Route Handlers and tRPC (`apps/web/client/src/server/api/root.ts`).
* In production (see `docker-compose.yml:4-12`), only the single `web-client` container is deployed.

### 3.2. Comparison: `apps/backend` vs `apps/web/server` vs `apps/web/client/src/server`

| Location | Type / Runtime | Actual Role & Status |
| :--- | :--- | :--- |
| **`apps/web/client/src/server`** | Next.js API Layer (tRPC + Route Handlers) | **The Real Backend**. Implements 16+ tRPC routers (`project`, `sandbox`, `chat`, `user`, `member`, `publish`, `domain`, `github`, `subscription`, etc.) and handles database queries directly with Drizzle ORM. |
| **`apps/backend`** | Supabase Local Infrastructure | **Database & Auth Services**. Configuration files (`config.toml`), SQL migrations (`migrations/`), and Supabase CLI scripts for starting local Postgres, Auth (GoTrue), and Storage. |
| **`apps/web/server`** | Fastify + WebSocket Server (port 8080) | **Unused / Legacy Prototype**. Contains stub sandbox routes. Not required for running Onlook locally or in production. |

### 3.3. What Backend Infrastructure is Actually Required?

To run Onlook in production or development, the following infrastructure services are required:

1. **Database & Auth (Supabase / PostgreSQL)**:
   * **PostgreSQL Database** (`SUPABASE_DATABASE_URL`): Stores users, projects, branches, canvas frames, conversations, messages, custom domains, and subscription records.
   * **Supabase GoTrue Auth** (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`): Handles JWT authentication, session cookies, OAuth (GitHub/Google), and user management.
   * **Supabase Storage**: Bucket `preview_images` for storing canvas screenshots and project thumbnails.
2. **Remote Sandbox Provider (CodeSandbox API)**:
   * `CSB_API_KEY`: Required for launching cloud development environments where user code runs, compiles, and renders in real-time.
3. **AI Model Provider (OpenRouter or Direct APIs)**:
   * `OPENROUTER_API_KEY`: Primary provider used for code generation, chat assistance, and fast edits.
   * Optional fallback providers: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_AI_STUDIO_API_KEY`, `AWS_ACCESS_KEY_ID` (Bedrock).
4. **Hosting / Deployment Provider (Optional)**:
   * `FREESTYLE_API_KEY`: Required if using Onlook's one-click deployment to Freestyle sandboxes / custom subdomains.
5. **Billing Provider (Optional)**:
   * `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`: Required for paid tiers and token rate limiting.

### 3.4. When is `apps/web/server` Used vs Next.js tRPC?

* **Next.js tRPC** (`/api/trpc` in `apps/web/client/src/server/api/root.ts`) is used for **100% of all current application operations**.
* **`apps/web/server`** is **never used** in normal operation. It represents an experimental Fastify WebSocket server for standalone desktop/RPC forwarding that is currently inactive.

---

## 4. Configuration & Environment Variables Matrix

All environment variables are declared and validated using `@t3-oss/env-nextjs` and Zod in `apps/web/client/src/env.ts`.

### 4.1. Core Required Variables (Minimum to Run)

| Variable Name | Scope | Description | Default / Example |
| :--- | :--- | :--- | :--- |
| `NODE_ENV` | Server | Runtime environment | `development` / `production` |
| `SUPABASE_DATABASE_URL` | Server | PostgreSQL direct connection string for Drizzle ORM | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| `SUPABASE_SERVICE_ROLE_KEY` | Server | Supabase admin service role key (bypasses RLS) | *Generated by Supabase* |
| `NEXT_PUBLIC_SUPABASE_URL` | Client | Public Supabase API URL | `http://127.0.0.1:54321` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Client | Public Supabase Anon/Publishable key | *Generated by Supabase* |
| `CSB_API_KEY` | Server | CodeSandbox API key for creating & running sandboxes | *Required for Sandboxes* |
| `OPENROUTER_API_KEY` | Server | OpenRouter API Key for AI chat & code edits | *Required for AI features* |
| `NEXT_PUBLIC_SITE_URL` | Client | Base URL of the Onlook web application | `http://localhost:3000` |

### 4.2. Feature-Specific Optional Variables

#### AI & Specialized LLM Providers
* `OPENROUTER_BASE_URL`: Custom OpenRouter gateway URL.
* `ANTHROPIC_API_KEY`: Direct Anthropic API access (Claude 3.5 Sonnet).
* `OPENAI_API_KEY`: Direct OpenAI API access (GPT-4o, o1, o3).
* `GOOGLE_AI_STUDIO_API_KEY`: Google Gemini Flash / Pro models.
* `MORPH_API_KEY` / `RELACE_API_KEY`: High-speed AST code apply engines.
* `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`: AWS Bedrock models.
* `GOOGLE_CLIENT_EMAIL`, `GOOGLE_PRIVATE_KEY`, `GOOGLE_PRIVATE_KEY_ID`: Google Vertex AI credentials.
* `FIRECRAWL_API_KEY`: Web scraping tool for AI context (`scrape-url`).
* `EXA_API_KEY`: Web search tool for AI research (`web-search`).
* `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_BASEURL`: LLM tracing and prompt monitoring.

#### GitHub Integration
* `GITHUB_APP_ID`: GitHub App ID for repository cloning and PR generation.
* `GITHUB_APP_PRIVATE_KEY`: Private RSA key (.pem) for GitHub App authentication.
* `GITHUB_APP_SLUG`: GitHub App URL slug.

#### Hosting & Custom Domains
* `FREESTYLE_API_KEY`: Cloud hosting deployment engine.
* `NEXT_PUBLIC_HOSTING_DOMAIN`: Base domain for published preview apps (e.g. `onlook.live`).

#### Payments & Subscriptions
* `STRIPE_SECRET_KEY`: Stripe API secret key.
* `STRIPE_WEBHOOK_SECRET`: Secret for verifying Stripe webhook events at `/webhook/stripe`.

#### Email & Notifications
* `RESEND_API_KEY`: Resend API key for sending team project invitations.
* `N8N_WEBHOOK_URL`, `N8N_API_KEY`, `N8N_LANDING_FORM_URL`: Webhooks for growth and form automation.

#### Analytics & Feature Flags
* `NEXT_PUBLIC_POSTHOG_KEY`, `NEXT_PUBLIC_POSTHOG_HOST`: Product analytics and session replay.
* `NEXT_PUBLIC_GLEAP_API_KEY`: User feedback and bug reporting widget.
* `NEXT_PUBLIC_FEATURE_COLLABORATION`: Boolean flag (`true`/`false`) to toggle multi-user real-time collaboration.

---

## 5. Architectural Diagram: Runtime & Data Flow

```
+---------------------------------------------------------------------------------------+
|                                    USER BROWSER                                       |
|                                                                                       |
|   +-------------------------------------------------------------------------------+   |
|   |                       Onlook Web Client (Next.js 16)                          |   |
|   |  - MobX Editor Engine (Canvas, Elements, Styles, AST, Chat, Branches)          |   |
|   |  - Virtual File System (@zenfs/core, IndexedDB Cache)                         |   |
|   |  - isomorphic-git (Local Branch Operations)                                   |   |
|   +---------------------------------------+---------------------------------------+   |
|                                           |                                           |
|                  Penpal RPC (postMessage) | [Canvas iFrames]                          |
|                                           v                                           |
|   +-------------------------------------------------------------------------------+   |
|   |                    User Running App (Preview Frame)                           |   |
|   |  - Injected `onlook-preload-script.js` (@onlook/web-preload)                   |   |
|   |  - DOM mutation observer, bounding rects, dynamic CSS stylesheet injection     |   |
|   +-------------------------------------------------------------------------------+   |
+-------------------------------------------+-------------------------------------------+
                                            |
                         HTTPS / tRPC / SSE |
                                            v
+---------------------------------------------------------------------------------------+
|                    NEXT.JS SERVER LAYER (apps/web/client/src/server)                  |
|                                                                                       |
|   +----------------------------------+     +--------------------------------------+   |
|   |    tRPC Router (/api/trpc/*)     |     |       AI Stream (/api/chat)          |   |
|   | - project, branch, frame, member |     | - @onlook/ai Root Agent              |   |
|   | - sandbox, domain, publish       |     | - Multi-tool execution (fs, bash)    |   |
|   +-----------------+----------------+     +------------------+-------------------+   |
|                     |                                         |                       |
|                     | Drizzle ORM                             | AI SDK / REST         |
|                     v                                         v                       |
+---------------------+-----------------------------------------+-----------------------+
|                     |                                         |                       |
|                     v                                         v                       |
|     +-------------------------------+         +-------------------------------+       |
|     |  SUPABASE / POSTGRESQL STACK  |         |   EXTERNAL CLOUD PROVIDERS    |       |
|     |                               |         |                               |       |
|     | - PostgreSQL (Drizzle Schema) |         | - CodeSandbox API (CSB_API)   |       |
|     | - Supabase GoTrue Auth        |         | - OpenRouter / Anthropic / AI |       |
|     | - Storage (preview_images)    |         | - Freestyle Hosting / Domains |       |
|     | - Realtime Subscriptions      |         | - GitHub App (Octokit)        |       |
|     |                               |         | - Stripe API & Webhooks       |       |
|     +-------------------------------+         +-------------------------------+       |
+---------------------------------------------------------------------------------------+
```

---

## 6. Primary Source Verification & Code References

1. **Monorepo Structure & Workspaces**: `package.json:13-19`.
2. **Next.js Client Config & Dependencies**: `apps/web/client/package.json:1-156`.
3. **Preload Script Build & Penpal RPC**: `apps/web/preload/package.json:8`, `apps/web/preload/script/index.ts:37-68`.
4. **Fastify Server & Unused Status**: `apps/web/server/src/server.ts:1-38`, `docs/content/docs/developers/architecture.mdx:31`.
5. **Main tRPC API Aggregator**: `apps/web/client/src/server/api/root.ts:1-55`.
6. **AI Agent & Chat Route**: `apps/web/client/src/app/api/chat/route.ts:1-122`, `packages/ai/src/tools/classes/index.ts`.
7. **Code Sandbox Integration**: `apps/web/client/src/server/api/routers/project/sandbox.ts:15-40`, `packages/code-provider/src/providers/codesandbox/index.ts`.
8. **Drizzle ORM Schema**: `packages/db/src/schema/index.ts:1-8`.
9. **Environment Configuration**: `apps/web/client/src/env.ts:1-169`.
10. **Docker Production Compose Deployment**: `docker-compose.yml:1-12`, `docs/content/docs/self-hosting/docker-compose.mdx:70-85`.
