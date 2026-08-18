# Testing Strategy & Verification

## 1. Test Frameworks
- **Unit & Integration Testing**: Vitest (`vitest: ^4.0.7`, `apps/web/client/vitest.config.ts`, Bun test runner `bun test`).
- **Browser & Component Testing**: Playwright (`@vitest/browser-playwright: ^4.0.7`, `playwright: ^1.56.1`).
- **UI Visual Testing**: Storybook 10 (`@storybook/nextjs-vite`, `@storybook/addon-vitest`, `chromatic`).

## 2. Test Suites Across Monorepo
- **AST Parsing (`packages/parser/test`)**: Tests Babel JSX traversal, element insertion, style updates, and template parsing.
- **AI Agent & Tools (`packages/ai/test`)**: Tests tool parameter schemas, context generation, and stream handlers.
- **UI Components (`packages/ui/test`)**: Validates design tokens, gradient math, and component rendering.
- **Utilities (`packages/utility/test`)**: Comprehensive tests for URL parsing, color conversions, Tailwind class merging, and path manipulation.
- **Client App (`apps/web/client/test`)**: Integration and end-to-end tests for canvas state and tRPC interactions.

## 3. Running Tests & Quality Checks
```bash
bun test                    # Run unit tests across all workspace packages
bun run typecheck           # Run TypeScript typechecks across packages
bun run lint                # Run ESLint linting
bun run format              # Format codebase with ESLint/Prettier
```
