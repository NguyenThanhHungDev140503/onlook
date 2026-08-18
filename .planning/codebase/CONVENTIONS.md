# Coding Standards & Conventions

## 1. Code Style & Tooling
- **Formatter & Linter**: ESLint 9 (`eslint.config.js`), Prettier configured via monorepo tooling (`tooling/prettier/`, `tooling/eslint/`).
- **Strict Types**: TypeScript `strict: true` across all packages (`tsconfig.json`).
- **Imports & Aliasing**: Path aliases `@/*` and `~/*` mapping to `apps/web/client/src/*`. Shared workspace packages referenced as `@onlook/*`.

## 2. Next.js App Router Rules
- **Server Components by Default**: Pages and layout components are Server Components unless interactivity is required.
- **Client Boundaries**: Add `'use client'` explicitly for hooks, DOM event listeners, and browser APIs.
- **MobX Integration**: Components wrapped with `observer` from `mobx-react-lite` must reside in client component files.
- **Store Instantiation**: Use `useState(() => new Store())` or `useRef` to maintain MobX store identity across renders. Avoid `useMemo` for store instances.
- **Environment Separation**: Never import server-only modules or `process.env` inside client components. Use typed `env` from `@/env`.

## 3. tRPC & API Design
- **Procedure Boundaries**: All tRPC procedures must use `publicProcedure` or `protectedProcedure` from `apps/web/client/src/server/api/trpc.ts`.
- **Validation**: All procedure inputs must be strictly validated using Zod schemas.
- **Root Aggregation**: Every new router must be registered in `apps/web/client/src/server/api/root.ts`.
- **Plain Data Transfer**: SuperJSON handles date/regex serialization; procedures return plain JSON objects.

## 4. UI & Styling Patterns
- **Tailwind-First**: Use Tailwind CSS utility classes; avoid raw inline styles unless dynamically calculated at runtime (e.g. canvas zoom transform).
- **Class Merging**: Combine conditional classes using `cn()` or `twMerge` (`packages/utility/src/tw-merge.ts`).
- **Component Primitives**: Build on top of `@onlook/ui` Radix-based primitives.
- **Internationalization**: Do not hardcode user-facing strings; use `next-intl` keys in `apps/web/client/messages/`.
