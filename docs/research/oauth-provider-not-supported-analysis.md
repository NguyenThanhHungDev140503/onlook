# Nghiên cứu Codebase & Phân tích lỗi OAuth "Provider not supported"

## 1. Tổng quan Kiến trúc Codebase (Onlook)

- **Cấu trúc Monorepo**: Quản lý bởi Bun Workspaces.
  - `apps/web/client`: Next.js 15 (App Router), TailwindCSS, tRPC, MobX, Supabase SSR client.
  - `apps/backend`: Supabase local stack (PostgreSQL, GoTrue/Auth, Storage, Edge Functions).
  - `packages/*`: `@onlook/db` (Drizzle ORM & migrations), `@onlook/models` (Type definitions & Enums), `@onlook/ui`, v.v.
- **Hệ thống Authentication**:
  - Tầng Client / Server Action: `apps/web/client/src/app/login/actions.tsx` gọi `supabase.auth.signInWithOAuth({ provider, options: { redirectTo } })`.
  - Quản trị phiên & Người dùng: `apps/web/client/src/app/auth/callback/route.ts` bắt `code`, gọi `supabase.auth.exchangeCodeForSession(code)` và upsert user vào database qua tRPC.
  - Auth Provider backend: Quản lý bởi Supabase Auth (GoTrue).

## 2. Phân tích nguyên nhân lỗi: `provider not supported` / `provider is not enabled`

Lỗi xuất hiện khi ấn đăng nhập Google hoặc GitHub:
- Mã lỗi từ Supabase GoTrue API khi nhận request tới `/auth/v1/authorize?provider=google` hoặc `/auth/v1/authorize?provider=github`.
- **Nguyên nhân chính**:
  1. **Supabase Local**: Trong file `apps/backend/supabase/config.toml`:
     ```toml
     [auth.external.github]
     enabled = true
     client_id = "env(GITHUB_CLIENT_ID)"
     secret = "env(GITHUB_SECRET)"

     [auth.external.google]
     enabled = true
     client_id = "env(GOOGLE_CLIENT_ID)"
     secret = "env(GOOGLE_SECRET)"
     ```
     Khi chạy Supabase local (`bun run start` / `supabase start`), nếu các biến môi trường `GITHUB_CLIENT_ID`, `GITHUB_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_SECRET` không được định nghĩa hoặc để trống trong môi trường chạy Supabase CLI (file `apps/backend/.env` hoặc env hệ thống), Supabase Auth tự động vô hiệu hóa (disable) các provider này. Kết quả trả về từ GoTrue là: `provider is not supported` / `provider not enabled`.
  2. **Supabase Cloud / Hosted**: Nếu kết nối tới project Supabase trên Cloud (`NEXT_PUBLIC_SUPABASE_URL`), các provider GitHub / Google chưa được bật trong Supabase Dashboard (`Authentication -> Providers -> GitHub / Google`).

## 3. Hướng dẫn khắc phục

### Đối với môi trường Local Development (Supabase Local CLI):
1. Tạo hoặc chỉnh sửa file `apps/backend/.env`:
   ```bash
   GOOGLE_CLIENT_ID=your_google_client_id
   GOOGLE_SECRET=your_google_client_secret
   GITHUB_CLIENT_ID=your_github_client_id
   GITHUB_SECRET=your_github_client_secret
   ```
2. Cấu hình Redirect URL trong GitHub OAuth App và Google Cloud Console:
   - URL: `http://127.0.0.1:54321/auth/v1/callback` hoặc `http://localhost:54321/auth/v1/callback`
3. Khởi động lại Supabase local để nạp biến môi trường:
   ```bash
   cd apps/backend
   bun run stop
   bun run start
   ```
4. Để test nhanh mà không cần tạo OAuth App, sử dụng tài khoản phát triển:
   - Nút **"Continue with Dev User"** (gọi `devLogin()` trong `apps/web/client/src/app/login/actions.tsx` với thông tin `SEED_USER`).

### Đối với môi trường Supabase Cloud / Self-hosted:
1. Vào Supabase Dashboard -> **Authentication** -> **Providers**.
2. Bật Toggle **GitHub** và **Google**.
3. Điền `Client ID` và `Client Secret`.
4. Điền URL Callback của Supabase vào trang quản lý OAuth của GitHub / Google.
