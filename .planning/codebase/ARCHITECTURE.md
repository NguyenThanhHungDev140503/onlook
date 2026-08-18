# System Architecture & Design Patterns

## 1. Architectural Pattern Overview
Onlook uses a **Unified Full-Stack Monorepo Architecture** centered around Next.js App Router, tRPC, MobX, Babel AST transforms, and Penpal postMessage RPC.

```
+-----------------------------------------------------------------------------------+
|                              ONLOOK HOST APPLICATION                              |
|                          (apps/web/client: Next.js 16)                            |
|                                                                                   |
|  +-------------------------+  +-------------------------+  +-------------------+  |
|  |     MobX Editor Store   |  |   Babel AST Transformer |  |    tRPC Router    |  |
|  | (Canvas, Frames, Style) |  |   (@onlook/parser)      |  |  (root.ts -> DB)  |  |
|  +------------+------------+  +------------+------------+  +---------+---------+  |
|               |                            |                         |            |
|               | RPC (@onlook/penpal)       | File Writes             | Drizzle    |
|               v                            v                         v            |
|  +-------------------------+  +-------------------------+  +-------------------+  |
|  |    Preview Frame DOM    |  |  Virtual FS / Sandbox   |  | Postgres/Supabase |  |
|  | (onlook-preload-script) |  | (ZenFS / CodeSandbox)   |  |  (Database / RLS) |  |
|  +-------------------------+  +-------------------------+  +-------------------+  |
+-----------------------------------------------------------------------------------+
```

## 2. Core Layers & Subsystems

### 2.1. Presentation & Editor Engine (`apps/web/client/src/components/store/editor`)
- **Engine Store (`engine.ts`)**: The central MobX coordinator aggregating specialized store domains:
  - `canvas/`: Infinite canvas coordinates, zoom levels, panning.
  - `frames/`: Multi-viewport iframe management, dimensions, responsive presets.
  - `element/`: Selected element tracking, bounding box computation, hover outlines.
  - `style/`: Tailwind CSS class parser, color pickers, typography and layout inspector.
  - `chat/`: Streaming chat state with AI agents.
  - `history/`: Undo/redo stack for AST modifications.

### 2.2. Preload & DOM-to-AST Synchronization (`apps/web/preload` & `packages/parser`)
- **Preload Script**: Built into `public/onlook-preload-script.js`. Injected directly into the child iframe.
  - Attaches listeners to DOM nodes.
  - Identifies elements using `data-oid` (Onlook ID) generated at compilation/runtime.
  - Measures element rects and intercepts click/drag events, forwarding them over Penpal postMessage RPC.
- **AST Transformer (`packages/parser`)**:
  - Receives visual edits (e.g. style change, node reordering, text edit).
  - Traverses the JSX/TSX Babel AST matching the node's `data-oid` or sourcemap coordinates.
  - Performs safe code rewrite, preserving comments and formatting via Prettier.

### 2.3. Code Providers & Execution Sandboxes (`packages/code-provider`)
- Provides a polymorphic abstraction (`CodeProvider` interface):
  - **Local Browser Mode**: Powered by `@zenfs/core` & IndexedDB for instant, client-side execution.
  - **Cloud VM Mode**: Powered by `@codesandbox/sdk` for Node.js backend execution, running dev servers, and terminal commands.

### 2.4. Data Access & tRPC Layer (`apps/web/client/src/server/api`)
- tRPC v11 router (`root.ts`) exposing typed endpoints for:
  - Project CRUD, branching, and workspace settings (`routers/project/`).
  - GitHub App authentication, repository clone, and commit operations (`routers/github.ts`).
  - Stripe subscription management (`routers/subscription.ts`).
  - Custom domain DNS checks and publishing (`routers/domain/`, `routers/publish/`).
- Direct integration with Drizzle ORM queries using connection pooling from `@onlook/db`.

## 3. Data Flow Pathways
1. **Visual Edit**: User drags/edits UI -> Preload captures DOM Rect -> Penpal sends message to Editor Store -> Babel modifies AST in CodeProvider -> App hot-reloads in Iframe.
2. **AI Chat Code Generation**: User prompts in Chat -> Request hits `/api/chat` -> LLM executes tools (`read-file`, `write-file`, `search-replace-edit`) -> CodeProvider updates filesystem -> Iframe refreshes.
