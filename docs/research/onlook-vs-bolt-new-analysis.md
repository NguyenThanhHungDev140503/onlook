# Nghiên cứu & So sánh Chi tiết: Onlook vs Bolt.new (StackBlitz)

## 1. Tổng quan Bản chất 2 Dự án

| Tiêu chí | **Onlook** (Dự án này) | **Bolt.new** (StackBlitz) |
| :--- | :--- | :--- |
| **Định vị cốt lõi** | **Visual Code Editor & Design-to-Code Platform** (Kết hợp Figma Canvas + IDE). | **AI Full-stack App Builder / Prompt-to-App** (Chat prompt sinh toàn bộ web app). |
| **Đối tượng hướng tới** | Designer, Frontend Developer muốn chỉnh sửa trực quan code React/Tailwind có sẵn. | Developer, Builder muốn tạo nhanh prototype/full-stack app từ ý tưởng bằng prompt. |
| **Mô hình tương tác chính** | **Visual-first**: Click trực tiếp vào UI Canvas (DOM) để kéo thả, sửa style Tailwind, chèn component + Chat AI hỗ trợ. | **Chat-first**: Chat prompt -> AI sinh file/chạy command -> Xem kết quả preview + Code view bổ trợ. |
| **Giấy phép** | Open Source (Monorepo Bun/Next.js/Supabase). | Sản phẩm SaaS thương mại của StackBlitz (có bản mã nguồn mở cộng đồng `bolt.diy`). |

---

## 2. So sánh Kiến trúc Kỹ thuật (Technical Architecture)

### 2.1. Môi trường Thực thi (Execution Environment & Sandboxing)
* **Bolt.new**:
  * Sử dụng công nghệ độc quyền **StackBlitz WebContainers** (chạy Node.js runtime trực tiếp trong WebAssembly bên trong browser tab của user).
  * **Ưu điểm**: Không tốn chi phí compute server cho container, khởi động tức thì, chạy an toàn cô lập trong trình duyệt.
  * **Hạn chế**: Bị giới hạn bởi môi trường trình duyệt (không chạy được native binary C/C++, Docker hay một số database native nặng).
* **Onlook**:
  * Sử dụng **CodeSandbox SDK (`@codesandbox/sdk`)** chạy trên remote cloud VM microVMs + **Virtual Filesystem** (`@zenfs/core` + IndexedDB) trên browser.
  * **Ưu điểm**: Môi trường Linux thực tế, có thể chạy mọi build tool phức tạp, hỗ trợ dev server Next.js 16 đầy đủ.
  * **Hạn chế**: Phụ thuộc API key và hạ tầng cloud của CodeSandbox (`CSB_API_KEY`).

### 2.2. Cơ chế Đồng bộ & Sửa mã nguồn (Code Modification Engine)
* **Bolt.new**:
  * **Artifact & Full File Replacement**: LLM sinh các thẻ `<boltArtifact>` và `<boltAction type="file|shell">`.
  * `ActionRunner` nhận stream và ghi đè toàn bộ nội dung file qua `webcontainer.fs.writeFile`. Không phân tích cú pháp AST sâu cho từng thuộc tính visual.
* **Onlook**:
  * **Bidirectional AST Code Sync (Babel AST)**:
    * Injected Preload Script (`apps/web/preload`) chạy trong iframe preview lắng nghe click/hover DOM.
    * Gửi RPC PostMessage qua `@onlook/penpal` về Canvas Editor.
    * Editor sử dụng **Babel AST Parser / Traverse (`packages/parser`)** để sửa đúng node JSX/TSX hoặc thuộc tính Tailwind CSS tương ứng trong file mã nguồn mà không làm xáo trộn format các phần còn lại của file.
  * **AI Apply Engine**: Sử dụng fast-apply models (Morph, Relace) và agentic tools (`search-replace-edit`, `fuzzy-edit-file`).

### 2.3. Trải nghiệm Chỉnh sửa Giao diện (UI/UX Editing)
* **Bolt.new**:
  * Preview iframe hiển thị trang web hoàn chỉnh. Muốn sửa UI thường phải gõ prompt mô tả cho AI ("đổi nút này sang màu xanh", "thêm form login") hoặc mở tab Code để gõ code thủ công.
* **Onlook**:
  * Canvas vô cực (Infinite Canvas) như Figma: zoom, pan, hiển thị đồng thời nhiều kích thước thiết bị (Responsive frames).
  * Panel thuộc tính trực quan (Properties Panel): chỉnh Padding, Margin, Flexbox, Grid, Typography, Colors, Tailwind utilities bằng thanh trượt/color picker và tự động map thành code.

---

## 3. Bảng so sánh Tính năng Chi tiết

| Tính năng | Onlook | Bolt.new |
| :--- | :--- | :--- |
| **Runtime Container** | Cloud CodeSandbox VM (`@codesandbox/sdk`) | WebAssembly WebContainers (In-browser) |
| **Click-to-Edit Visual DOM** | **Có** (DOM Inspector -> Sửa Tailwind -> Map sang AST JSX) | **Không** (Chỉ xem preview, sửa bằng prompt/code) |
| **Babel AST Engine** | **Có** (`packages/parser`) | Không (ghi file trực tiếp từ AI artifact) |
| **Prompt-to-App AI** | Có (Hỗ trợ OpenRouter, Claude, GPT, Bedrock, Vertex) | Rất mạnh (Tối ưu chuyên sâu cho prompt sinh dự án mới) |
| **Quản lý Git / Branch** | Tích hợp `isomorphic-git` + Branching DB + GitHub App | Tích hợp Push to GitHub, Export ZIP |
| **Deploy / Hosting** | Freestyle Sandboxes + Custom Domains CNAME/TXT | Netlify, Cloudflare Pages, Vercel, Expo EAS |
| **Backend & Database** | Supabase (PostgreSQL + Drizzle ORM + GoTrue Auth) | Supabase integration / Local WebContainer storage |
| **Khả năng Self-host** | Hoàn toàn self-host được bằng Docker / Docker Compose | Bản gốc đóng mã nguồn; bản `bolt.diy` self-host được |

---

## 4. Tổng kết

* **Chọn Bolt.new khi**: Cần tạo nhanh một ứng dụng full-stack hoàn chỉnh từ con số 0 chỉ bằng một vài câu prompt mô tả tính năng.
* **Chọn Onlook khi**: Đã có sẵn dự án React/Next.js/Tailwind hoặc muốn thiết kế UI/UX với độ chính xác cao bằng thao tác visual kéo thả trực tiếp như Figma nhưng xuất ra code thật chuẩn AST vào repo Git.
