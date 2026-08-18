# Technology Stack & Dependencies

## 1. Core Languages & Runtime
- **Runtime / Package Manager**: Bun 1.3.1 (`package.json:44`), Bun workspaces monorepo.
- **Language**: TypeScript 5.5.4 / 5.8.2 (`tsconfig.json`, `tooling/typescript/`).
- **Target Environments**: Node.js 20+, Modern Evergreen Browsers, Deno (Supabase Edge Functions).

## 2. Frontend Application (`apps/web/client`)
- **Framework**: Next.js 16.0.7 (React 19.2.0, React DOM 19.2.0, Turbopack `--turbo`).
- **Styling**: Tailwind CSS 4.0.15 (`@tailwindcss/postcss: ^4.0.15`, `tw-animate-css`, `tailwind-merge: ^3.2.0`).
- **State Management**: MobX + `mobx-react-lite: ^4.1.0` (central engine stores).
- **Client Components & UI**: Radix UI primitives, Lucide React (`lucide-react: ^0.486.0`), Motion (`motion: ^12.23.19`), React Arborist tree view (`react-arborist: ^3.4.3`).
- **Code & Terminal Editors**: CodeMirror 6 (`@uiw/react-codemirror`, `react-codemirror-merge`), XTerm.js (`@xterm/xterm`, `@xterm/addon-fit`).
- **I18n & Theming**: `next-intl: ^4.0.2`, `next-themes: ^0.4.6`.
- **Search & Storage**: `flexsearch: ^0.8.160`, `localforage: ^1.10.0`, `@zenfs/core` & `@zenfs/dom`.

## 3. Backend & API Services
- **API Protocol**: tRPC v11 (`@trpc/server: ^11.0.0`, `@trpc/client`, `@trpc/react-query`, `@tanstack/react-query: ^5.69.0`).
- **Data Validation & Serialization**: Zod 4 (`zod: ^4.1.3`), SuperJSON (`superjson: ^2.2.1`).
- **Database & ORM**: PostgreSQL, Drizzle ORM (`drizzle-orm: ^0.44.5`, `drizzle-kit: ^0.31.4`, `postgres: ^3.4.7`, `pg: ^8.16.3`).
- **Authentication & Backend Core**: Supabase (`@supabase/ssr: ^0.6.1`, GoTrue, PostgreSQL RLS, Storage).

## 4. AI & Code Engineering Packages
- **AI SDK**: Vercel AI SDK (`ai: 5.0.26` / `5.0.60`, `@ai-sdk/react: 2.0.60`).
- **AI Models & Providers**: OpenRouter (`@openrouter/ai-sdk-provider: 1.2.0`), OpenAI (`openai: ^4.103.0`), Anthropic, Google Vertex AI, AWS Bedrock.
- **Search & Scrape Tools**: Exa (`exa-js: ^1.8.26`), Firecrawl (`@mendable/firecrawl-js: ^1.29.1`).
- **AST Parsing & Code Transformation**: `@babel/parser`, `@babel/traverse`, `@babel/generator`, Prettier.
- **Sandboxes**: CodeSandbox SDK (`@codesandbox/sdk`), Freestyle Sandboxes (`freestyle-sandboxes: ^0.0.78`).
- **Git Operations**: `isomorphic-git`, Octokit (`octokit: ^5.0.3`).

## 5. Telemetry & Analytics
- **Telemetry**: OpenTelemetry (`@opentelemetry/api-logs`, `@opentelemetry/sdk-logs`, `@vercel/otel: ^1.13.0`).
- **LLM Tracing**: Langfuse (`langfuse-vercel: ^3.38.4`).
- **Product Analytics**: PostHog (`posthog-js: ^1.246.0`, `posthog-node: ^4.17.2`), Gleap (`gleap: ^14.8.8`).
