# Phân tích lỗi Sandbox API & 400 Bad Request khi tạo/load Project

> **Tài liệu tham khảo**:
> - `apps/web/client/src/server/api/routers/project/sandbox.ts`
> - `packages/code-provider/src/codesandbox/index.ts`
> - `apps/web/client/src/components/store/editor/sandbox/session.ts`

---

## 1. Cơ chế hoạt động của Sandbox API trong Onlook

Khi mở một Project trên Onlook, client thực hiện 2 luồng:

1. **Load Frame (Live Preview via iframe)**:
   - Client nạp iframe với `frame.url`: `https://<sandboxId>-3000.csb.app/`.
   - Kết nối trực tiếp từ browser đến CodeSandbox preview server.

2. **Khởi tạo Editor Session & Terminal Sync (`sandbox.start`)**:
   - Client gọi tRPC mutation `api.sandbox.start({ sandboxId })`.
   - Backend gọi `createCodeProviderClient(CodeProvider.CodeSandbox)` -> CodeSandbox API (`https://api.codesandbox.io/v1/sandboxes/${sandboxId}/session`).
   - CodeSandbox trả về WebSocket URL (`wss://ctrl.fc-us-3.codesandbox.io/<sandboxId>/?token=...`).
   - Client dùng WebSocket này để đồng bộ file code real-time, chạy terminal command, hot-reload AST.

---

## 2. Phân tích nguyên nhân lỗi 400 Bad Request / Failed to start sandbox

### Trường hợp 1: Mở 2 project mẫu mặc định (`Preload Script Test` / `Mock Template`)
- Hai project này có `sandboxId: "123456"` (mock ID từ file seed).
- Khi gọi `sandbox.start({ sandboxId: "123456" })`, CodeSandbox API trả về `404/400: Sandbox not found`.
- **Giải pháp**: Chỉ mở các project được tạo mới hoặc xóa các project mock.

### Trường hợp 2: Token WebSocket hết hạn hoặc chưa khởi tạo xong microVM
- Khi tạo mới một project, CodeSandbox cần 2-5 giây để boot up microVM container.
- Request đầu tiên tới WebSocket `wss://ctrl.fc-us-3.codesandbox.io/...` có thể nhận handshake 400 nếu VM đang ở trạng thái `STARTING`.
- `SessionManager` (`apps/web/client/src/components/store/editor/sandbox/session.ts:47-70`) đã có sẵn cơ chế retry 3 lần (`MAX_RETRIES = 3, RETRY_DELAY_MS = 2000`). Sau 2s retry, VM chuyển sang trạng thái `RUNNING` và kết nối thành công.

### Trường hợp 3: OpenRouter / 9Router API Key (Lỗi 401 khi AI chat)
- Biến môi trường `OPENROUTER_API_KEY` trên VPS trước đó để giá trị placeholder dẫn đến AI chat trả về `401 Unauthorized`.
- Đã được cập nhật thành key hợp lệ của 9Router VPS (`sk-f6d6c996f51a861f-r3ogtf-9af781bc`).
