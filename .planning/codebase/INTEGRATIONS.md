# External Integrations & Services

## 1. Supabase (Authentication, Database, Storage & Realtime)
- **Local Dev**: `apps/backend/supabase/config.toml` (PostgreSQL `54322`, REST/Auth Gateway `54321`, Studio `54323`).
- **Client SDK**: `@supabase/ssr` via `apps/web/client/src/utils/supabase/client/index.ts` (browser) and `apps/web/client/src/utils/supabase/server.ts` (Next.js server-side cookies/headers).
- **Features**: User authentication (Email/Password, GitHub, Google OAuth), PostgreSQL RLS security policies, S3 preview bucket storage (`preview_images`), and Supabase Realtime broadcast channels.

## 2. LLM & AI Providers (`packages/ai` & `apps/web/client/src/app/api/chat/route.ts`)
- **OpenRouter**: Gateway for multi-model access (Claude 3.5 Sonnet, GPT-4o, DeepSeek, etc.) via `@openrouter/ai-sdk-provider`.
- **Direct Providers**: Anthropic Claude, OpenAI, AWS Bedrock, Google Vertex AI.
- **Diff Models**: Fast Apply / Morph / Relace models configured in `apps/web/client/src/env.ts`.
- **Search & Web Agents**:
  - Exa (`exa-js`): AI search index for web knowledge.
  - Firecrawl (`@mendable/firecrawl-js`): Clean markdown extraction from URLs.

## 3. GitHub App Integration (`packages/github`)
- **Authentication**: Octokit App authentication via `apps/web/client/src/server/api/routers/github.ts`.
- **Capabilities**: Repository discovery, cloning into sandboxes, branch creation, commit push, and pull request creation.

## 4. Sandboxes & Cloud Hosting
- **CodeSandbox SDK**: Remote microVM execution engine for running Next.js user applications in isolated containers.
- **Freestyle Hosting**: One-click preview and production publishing (`freestyle-sandboxes`, `apps/web/client/src/server/api/routers/publish/`).
- **Custom Domains**: Automated DNS CNAME & TXT verification with SSL provisioning (`apps/web/client/src/server/api/routers/domain/custom.ts`).

## 5. Stripe Billing (`packages/stripe` & `apps/web/client/src/app/webhook/stripe/route.ts`)
- **Subscriptions**: Tiered pricing models (Free, Pro, Enterprise).
- **Webhooks**: Automated subscription provisioning, cancellation, payment failure alerts, and usage token balance adjustments.

## 6. Communication & Analytics
- **Resend Email (`packages/email`)**: Transactional team invitations and workspace sharing notices.
- **PostHog**: In-app event telemetry, user feature adoption tracking, error monitoring.
- **Langfuse**: LLM generation token metrics, prompt latency, input/output cost telemetry.
