# Phân tích nguyên nhân khi load Project web gọi sang `http://localhost:8084/`

> **Tài liệu tham khảo chính**: Mã nguồn `packages/db/src/seed/db.ts`, `packages/db/src/defaults/frame.ts`, `apps/web/client/src/app/project/[id]/_components/canvas/frame/view.tsx`, `packages/constants/src/csb.ts`.

---

## 1. Tóm tắt nguyên nhân gốc rễ (Root Cause)

1. **Dữ liệu Demo / Seed User được hardcode URL `http://localhost:8084`**:
   - Khi chạy script seed database (`packages/db/src/seed/db.ts:120` và `packages/db/src/seed/db.ts:128`):
     ```typescript
     const frame0 = createDefaultFrame({
         canvasId: canvas0.id,
         branchId: branch0.id,
         url: 'http://localhost:8084',
     });
     const frame1 = createDefaultFrame({
         canvasId: canvas1.id,
         branchId: branch2.id,
         url: 'http://localhost:8084',
     });
     ```
   - Hai project có sẵn của Seed User (`"Preload Script Test"` và `"Mock Template (This doesn't work)"`) được tạo với frame URL trỏ trực tiếp đến `http://localhost:8084`.

2. **Cơ chế hoạt động của Onlook Editor (Canvas & Iframe Frame View)**:
   - Trong Onlook, mỗi Project gồm 1 Canvas, trên Canvas có 1 hoặc nhiều **Frames** (cửa sổ view).
   - Mỗi Frame render một thẻ `<iframe>` trong `apps/web/client/src/app/project/[id]/_components/canvas/frame/view.tsx`:
     ```typescript
     <iframe
         ref={iframeRef}
         src={frame.url}
         className="w-full h-full border-0"
         ...
     />
     ```
   - Khi mở Project của Seed User trên trình duyệt, trình duyệt đọc `frame.url` từ database (giá trị là `http://localhost:8084`) và nạp vào thẻ `<iframe>`.

3. **Ý nghĩa của port `8084` trong kiến trúc Onlook Desktop vs Web**:
   - Trong bản Onlook Desktop / Local server (`apps/web/preload` và `apps/web/server`), server preview local chạy ở port `8084` (còn editor RPC server chạy ở `8080` / `8081`).
   - Trong bản Web Cloud production, project thật sử dụng **CodeSandbox microVMs** với URL dạng:
     `https://<sandbox-id>-<port>.csb.app` (xem `packages/constants/src/csb.ts:getSandboxPreviewUrl`).

---

## 2. Giải pháp

### 1. Khi tạo Project mới (Create blank project / Prompt create):
- Khi người dùng tạo một project mới trên Web, `apps/web/client/src/server/api/routers/project/project.ts` sẽ khởi tạo Sandbox trên CodeSandbox và gán `sandboxUrl` là `https://<sandboxId>-3000.csb.app`.
- Frame của project mới sẽ nạp đúng URL live của container CodeSandbox thay vì `localhost`.

### 2. Cập nhật dữ liệu Seed cho VPS / Demo:
- Nếu muốn 2 project mặc định của Seed User hiển thị một trang web demo thay vì cố kết nối `localhost:8084`, có thể cập nhật `packages/db/src/seed/db.ts` hoặc cập nhật trực tiếp bảng `frames` trên Supabase:
  - Thay `http://localhost:8084` bằng một URL preview hợp lệ hoặc URL template (ví dụ trang demo, Next.js starter preview, hoặc trang intro).
