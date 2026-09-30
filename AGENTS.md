# Quy ước dự án (dùng chung cho mọi AI agent)

## Dự án
Sổ tay học tập: CLI Python ghi lại giờ học theo chủ đề.
- Mã nguồn: `so_tay_hoc.py`
- Test: `tests/` (pytest)

## Lệnh
- Chạy test: `python -m pytest -q`
- Chạy thử chương trình: `python so_tay_hoc.py --help`

## Quy ước code
- Python 3.12+, chỉ dùng thư viện chuẩn (riêng test dùng pytest).
- Có type hint; hàm ngắn, mỗi hàm mới có docstring một dòng.
- Tên hàm/biến: tiếng Việt không dấu, dạng snake_case, theo đúng kiểu code hiện có.
- Thông báo cho người dùng viết tiếng Việt có dấu.
- Đầu vào sai: in thông báo rõ ràng ra stderr, trả mã thoát khác 0, không để lộ traceback.
- Hàm phụ thuộc thời gian (ngày hôm nay…) nên nhận giá trị đó qua tham số để test được.

## An toàn (bắt buộc với mọi agent)
- Không chạy `git push`, `git merge`, `git reset --hard`, không xoá nhánh.
- Không xoá/sửa file ngoài thư mục dự án. Không đọc hay in nội dung `.env`, khoá, mật khẩu.
- Không cài thêm thư viện, trừ khi kế hoạch ghi rõ.
- Không tải hay chạy script từ Internet.

## Dây chuyền 4 agent
Người điều phối là `ship.ps1`. Các agent không nói chuyện trực tiếp mà bàn giao qua thư mục `.bangiao/`:

`yeu-cau.md` → `ke-hoach.md` (Planner) → `thay-doi.md` (Coder) → `ket-qua-test.md` (Tester) → `danh-gia.md` (Reviewer)

Phản hồi cần sửa của vòng trước nằm ở `.bangiao/phan-hoi.md`. Mỗi agent chỉ làm đúng vai của mình và luôn trả lời bằng tiếng Việt.
