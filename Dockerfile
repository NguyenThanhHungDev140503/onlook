# Build Onlook web client
FROM oven/bun:1-debian AS builder

LABEL org.opencontainers.image.source="https://github.com/onlook-dev/onlook"

WORKDIR /app

# Set build and production environment
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV STANDALONE_BUILD=true
ENV SKIP_ENV_VALIDATION=true
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

# Copy everything (monorepo structure)
COPY . .

# Install dependencies and build
RUN bun install
RUN cd apps/web/client && bun run build:standalone

FROM oven/bun:1-debian AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

# The standalone output contains only the runtime files and traced dependencies.
COPY --from=builder /app/apps/web/client/.next/standalone/ ./

# Expose the application port
EXPOSE 3000

# Health check to ensure the application is running
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD bun -e "fetch('http://localhost:3000').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Start the Next.js standalone server
CMD ["bun", "apps/web/client/server.js"]
