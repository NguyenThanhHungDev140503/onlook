# Technical Debt, Security & Architectural Concerns

## 1. Architectural Ambiguity & Legacy Code
- **`apps/web/server` (Fastify Server)**: Standalone Fastify WebSocket/tRPC server remains in monorepo despite being deprecated/unused (`docs/content/docs/developers/architecture.mdx`). Production exclusively runs `apps/web/client`.
- **Preload Bundle Synchronization**: Preload script (`apps/web/client/public/onlook-preload-script.js`) must be manually re-built whenever `apps/web/preload` changes. Risk of drift between editor host and preview frame if not built in CI/CD pipeline.

## 2. Sandbox Performance & File System Complexity
- **Two Parallel FS Abstractions**: Monorepo supports both `@zenfs/core` (browser IndexedDB) and `@codesandbox/sdk` (remote VM). Complex edge cases can occur when synchronizing Git branches across browser IndexedDB and cloud microVMs.
- **Large AST Transform Latency**: Complex Next.js applications with deep component trees may experience input lag during high-frequency visual dragging if Babel AST transformations block the main thread.

## 3. Security & Environment Variables
- **API Key Exposure**: Client and server code live in the same Next.js repository. Strict discipline is required with `@t3-oss/env-nextjs` to prevent leaking private LLM keys (OpenAI/Anthropic/OpenRouter) into browser bundles.
- **Iframe Sandboxing**: Preview iframes execute arbitrary user React code. Strict origin isolation and Penpal postMessage origin verification are critical to prevent XSS breakout into the host editor window.

## 4. Multi-Tenant Resource Limits
- Remote sandbox container lifecycles must be reaped promptly to avoid ballooning cloud infrastructure costs.
- Rate limiting on LLM chat endpoints (`/api/chat`) is required to prevent quota exhaustion from abusive or looping agent queries.
