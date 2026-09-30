# Dây chuyền 4 agent: hướng dẫn nhanh

Bạn chỉ cần viết yêu cầu. Bốn AI làm nối ca với nhau: lên kế hoạch → code → kiểm thử → duyệt, và tự sửa tối đa 3 vòng.

```
YEU-CAU.md
    │
    ▼
PLANNER  (Claude) ─────► .bangiao/ke-hoach.md
    │
    ▼
CODER    (agy) ────────► sửa code + .bangiao/thay-doi.md   ◄────────────┐
    │                                                                  │
    ▼                                                                  │ .bangiao/phan-hoi.md
TESTER   (agy) ────────► viết test + .bangiao/ket-qua-test.md          │ (tự quay lại,
    │     script tự chạy lại lệnh test thật để đối chiếu               │  tối đa 3 vòng)
    ├── test rớt ─────────────────────────────────────────────────────►┤
    ▼                                                                  │
REVIEWER (Claude) ─────► .bangiao/danh-gia.md                          │
    ├── CAN_SUA ──────────────────────────────────────────────────────►┘
    ├── CHAN ────► dừng, bạn quyết định
    └── CHOT ────► xong: bạn xem rồi tự gộp nhánh
```

- Các agent không nói chuyện trực tiếp với nhau. Chúng bàn giao qua **sổ bàn giao** `.bangiao/`.
- Mỗi bước là một tiến trình mới (`claude -p` hoặc `agy -p`), nên ngữ cảnh luôn sạch.
- Mọi thay đổi nằm trên nhánh `ship/...`, và mỗi bước có một commit snapshot, nên lúc nào cũng quay lại được.
- Script **không bao giờ** tự merge hay push.

## 1. Chuẩn bị (làm một lần)

Mở **PowerShell**, rồi:

```powershell
cd D:\day-chuyen-4-agent

# a) Đăng nhập Antigravity CLI bằng MỘT tài khoản Google
agy
#    → trình duyệt mở ra, chọn tài khoản, cho phép. Quay lại terminal gõ  /quit

# b) Kiểm tra mọi thứ (có gọi thử mỗi AI một câu rất ngắn)
.\ship.ps1 -KiemTra
```

Mọi dòng đều `[OK]` là xong phần chuẩn bị. Muốn xem dây chuyền chạy thế nào mà không tốn quota thì chạy `.\ship.ps1 -ChayThu` (chế độ giả lập).

## 2. Chạy

1. Viết yêu cầu vào `YEU-CAU.md` (đã có sẵn một yêu cầu mẫu để thử lần đầu).
2. Chạy `.\ship.ps1`, rồi đợi. Mỗi bước in tiến độ ra màn hình, nhật ký nằm ở `.bangiao\nhat-ky.md`.
3. Khi xong:
   - Đọc `.bangiao\danh-gia.md` (Reviewer nhận xét gì).
   - Xem code thay đổi: VS Code → Source Control, hoặc `git diff main --stat`.
   - Hài lòng thì gộp nhánh theo đúng lệnh script in ra (`git switch main` rồi `git merge ship/...`).

Yêu cầu ngắn cũng có thể truyền thẳng: `.\ship.ps1 -YeuCau "Thêm lệnh xoá buổi học theo số thứ tự"`.

## 3. Khi dây chuyền dừng giữa chừng

| Mã | Nghĩa | Làm gì |
|---|---|---|
| 2 | Planner có câu hỏi | Viết câu trả lời xuống cuối `YEU-CAU.md` → `.\ship.ps1 -TiepTuc` |
| 3 | Coder bị kẹt | Sửa `.bangiao\ke-hoach.md` hoặc bổ sung `YEU-CAU.md` → `-TiepTuc` |
| 4 | Reviewer CHẶN | Đọc `danh-gia.md`. Cho Coder sửa: `-TiepTuc`. Không thì bỏ nhánh, làm lại với yêu cầu rõ hơn |
| 5 | Hết số vòng | Xem `phan-hoi.md`. Cho thêm vòng: `.\ship.ps1 -TiepTuc -SoVong 5` |
| 6 | Lỗi của AI (hết quota, chưa đăng nhập…) | Đợi quota hồi rồi `-TiepTuc`, hoặc đổi AI cho vai đó: `-TiepTuc -Reviewer agy` |
| 7 | Agent trả lời sai định dạng | `-TiepTuc` để chạy lại đúng bước đó |

`-TiepTuc` chạy tiếp đúng từ bước bị dừng, không làm lại từ đầu.

## 4. Tuỳ biến

- **Đổi AI cho từng vai**: dùng `-Planner`, `-Coder`, `-Tester`, `-Reviewer` với giá trị `claude` hoặc `agy`.
  Ví dụ chạy toàn bộ bằng Claude: `.\ship.ps1 -Coder claude -Tester claude`.
- **Số vòng**: `-SoVong 5`. **Lệnh test**: `-LenhTest "python -m pytest -q"`.
- **Model**: sửa dòng `model:` trong `claude-agents\*.md` (`opus` / `sonnet` / `haiku`) hoặc `.agents\agents\*\agent.md` (`pro` / `flash`).
- **Luật chung của dự án**: `AGENTS.md`. Claude đọc file này qua `CLAUDE.md`, còn agy thì tự đọc.
- **Tính cách từng vai**: phần thân các file agent. Đây là chỗ học prompt engineering tốt nhất: sửa một câu, chạy lại, rồi so kết quả.
- **Dùng 4 vai trong phiên Claude Code thường** (gõ `claude --agent planner`…): tự chép chúng vào thư mục cấu hình của Claude:
  `New-Item -ItemType Directory .claude\agents -Force; Copy-Item claude-agents\*.md .claude\agents\`
  (Dây chuyền không cần bước này, vì `ship.ps1` tự đọc từ `claude-agents\`.)

## 5. Dùng cho dự án khác

Chép sang dự án đó các file: `ship.ps1`, `ship.cmd`, `YEU-CAU.md`, `AGENTS.md`, `CLAUDE.md`, thư mục `claude-agents\` và `.agents\`, cùng các dòng liên quan trong `.gitignore`.
Sửa `AGENTS.md` cho đúng dự án mới (mô tả, lệnh test, quy ước). Dự án phải là git repo và đã commit sạch.

## 6. An toàn, tài khoản, ổ C

- Coder và Tester chạy agy ở chế độ tự duyệt lệnh (`--dangerously-skip-permissions`), vì chế độ không giao diện của agy trên Windows chưa áp đúng danh sách quyền. Bù lại, mọi thứ nằm trên nhánh riêng và có snapshot. Muốn chặt hơn thì dùng `-AgyAnToan` (khi đó agy có thể không tự chạy được test).
- Planner và Reviewer chỉ được đọc. Nếu lỡ sửa file, script cất các thay đổi đó vào `git stash`.
- Chỉ dùng **một** tài khoản Google cho agy. Không dùng app đổi tài khoản hay proxy quota: điều khoản của Antigravity cấm, và tài khoản có thể bị khoá.
- Claude Code dùng tài khoản đang đăng nhập trên máy (`claude auth status`). Muốn đổi sang tài khoản khác: `claude auth logout`, rồi `claude auth login`.
- Để ổ C không đầy thêm: file tạm của dây chuyền nằm trong `.tmp\` của dự án, còn các lượt chạy tự động của Claude không lưu lịch sử phiên.

## 7. Cấu trúc thư mục

```
D:\day-chuyen-4-agent\
├── ship.ps1 / ship.cmd      ← nhạc trưởng (ship.cmd dùng khi PowerShell chặn chạy script)
├── YEU-CAU.md               ← bạn viết yêu cầu ở đây
├── AGENTS.md, CLAUDE.md     ← luật chung cho mọi agent
├── claude-agents\           ← 4 vai cho Claude Code (+ settings.json chặn lệnh nguy hiểm)
├── .agents\agents\          ← 4 vai cho Antigravity CLI (agy)
├── .bangiao\                ← sổ bàn giao (tự sinh mỗi lần chạy, có commit để xem lại)
├── so_tay_hoc.py, tests\    ← dự án mẫu: sổ tay học tập
└── .tmp\                    ← file tạm (không commit)
```
