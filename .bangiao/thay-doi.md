TRANG_THAI: KET

## Đã làm
1. Đã đọc [coder-v1.md](file:///D:/day-chuyen-4-agent/.bangiao/nhiem-vu/coder-v1.md), [AGENTS.md](file:///D:/day-chuyen-4-agent/AGENTS.md), [ke-hoach.md](file:///D:/day-chuyen-4-agent/.bangiao/ke-hoach.md), cũng như kiểm tra toàn bộ mã nguồn hiện tại tại [so_tay_hoc.py](file:///D:/day-chuyen-4-agent/so_tay_hoc.py) và [test_so_tay_hoc.py](file:///D:/day-chuyen-4-agent/tests/test_so_tay_hoc.py).
2. Đã phân tích chi tiết kế hoạch thêm lệnh con `tuan`, hằng số `SO_NGAY_TUAN = 7`, hàm `loc_buoi_trong_tuan(ds: list[BuoiHoc], hom_nay: date) -> list[BuoiHoc]`, subparser `tuan` và 5 ca kiểm thử pytest tương ứng.
3. **Phát hiện sự cố môi trường thực thi khiến Coder bị kẹt**:
   - Vai `coder` được gọi thông qua Antigravity CLI (`agy`) với cấu hình trong [.agents/agents/coder/agent.md](file:///D:/day-chuyen-4-agent/.agents/agents/coder/agent.md).
   - Tuy nhiên, phần YAML frontmatter của [.agents/agents/coder/agent.md](file:///D:/day-chuyen-4-agent/.agents/agents/coder/agent.md) không khai báo danh sách `tools:` cho phép chỉnh sửa tệp hoặc thực thi lệnh (`replace_file_content`, `write_file`, `run_command`). Do đó, Antigravity CLI chỉ cấp các công cụ đọc (`view_file`, `search_web`, `send_message`, ...), không cấp quyền ghi tệp hay chạy lệnh terminal cho agent trong phiên này.
   - Do thiếu công cụ chỉnh sửa file và chạy lệnh, Coder không thể trực tiếp ghi mã nguồn mới vào [so_tay_hoc.py](file:///D:/day-chuyen-4-agent/so_tay_hoc.py) cũng như chạy lệnh `python -m pytest -q`.

## File đã thay đổi
- Chưa thể ghi đè file nào do môi trường thiếu công cụ sửa file / chạy lệnh.

## Đã sửa theo phản hồi
Không có (đây là Vòng 1, chưa có `.bangiao/phan-hoi.md`).

## Kết quả tự chạy test
- Chưa thể chạy lệnh `python -m pytest -q` do phiên chạy của `agy` không có công cụ thực thi terminal (`run_command`).

## Ghi chú cho Tester
### Hướng dẫn khắc phục sự cố kẹt môi trường:
Người dùng có thể chọn một trong hai cách xử lý nhanh sau:

- **Cách 1 (Khuyên dùng - Chuyển Coder sang Claude)**:
  Claude đã được [ship.ps1](file:///D:/day-chuyen-4-agent/ship.ps1) cấu hình đầy đủ công cụ ghi file và chạy lệnh (`$ClaudeRunTools`). Người dùng chỉ cần chạy lệnh tiếp tục:
  ```powershell
  .\ship.ps1 -TiepTuc -Coder claude -Tester claude
  ```

- **Cách 2 (Bổ sung cấu hình tools cho agy)**:
  Mở [.agents/agents/coder/agent.md](file:///D:/day-chuyen-4-agent/.agents/agents/coder/agent.md) và [.agents/agents/tester/agent.md](file:///D:/day-chuyen-4-agent/.agents/agents/tester/agent.md), thêm khai báo công cụ vào frontmatter:
  ```yaml
  ---
  name: coder
  description: Lập trình viên của dây chuyền 4 agent. Triển khai đúng theo .bangiao/ke-hoach.md và sửa theo .bangiao/phan-hoi.md.
  model: pro
  tools:
    - view_file
    - replace_file_content
    - write_file
    - run_command
  ---
  ```
  Sau đó chạy:
  ```powershell
  .\ship.ps1 -TiepTuc
  ```

### Nội dung code sẵn sàng triển khai theo kế hoạch:
Khi công cụ được cấp đủ, Coder/người điều phối có thể áp dụng chính xác các thay đổi sau:

1. **Trong [so_tay_hoc.py](file:///D:/day-chuyen-4-agent/so_tay_hoc.py)**:
- Import `timedelta`: `from datetime import date, timedelta`
- Thêm hằng số: `SO_NGAY_TUAN = 7`
- Thêm hàm:
```python
def loc_buoi_trong_tuan(ds: list[BuoiHoc], hom_nay: date) -> list[BuoiHoc]:
    """Lọc các buổi học trong 7 ngày gần nhất, tính cả ngày hôm nay."""
    moc_dau = hom_nay - timedelta(days=SO_NGAY_TUAN - 1)
    ket_qua: list[BuoiHoc] = []
    for buoi in ds:
        try:
            ngay_buoi = date.fromisoformat(buoi.ngay)
        except ValueError as loi:
            raise ValueError(f"Dữ liệu có ngày không hợp lệ: {buoi.ngay!r}") from loi
        if moc_dau <= ngay_buoi <= hom_nay:
            ket_qua.append(buoi)
    return ket_qua
```
- Trong `tao_parser()`:
```python
p_tuan = lenh.add_parser("tuan", help="tổng số giờ 7 ngày gần nhất theo chủ đề")
p_tuan.add_argument("--ngay", help="ngày mốc dạng YYYY-MM-DD (mặc định: hôm nay)")
```
- Trong `main()`:
```python
elif args.lenh == "tuan":
    if args.ngay is None:
        hom_nay = date.today()
    else:
        try:
            hom_nay = date.fromisoformat(args.ngay)
        except ValueError as loi:
            raise ValueError("Ngày phải có dạng YYYY-MM-DD, ví dụ 2026-10-01.") from loi
    trong_tuan = loc_buoi_trong_tuan(doc_du_lieu(args.tep), hom_nay)
    tong = tong_theo_chu_de(trong_tuan)
    if not tong:
        print("Chưa có buổi học nào trong 7 ngày qua.")
    else:
        for chu_de, so_gio in tong.items():
            print(f"{chu_de}: {so_gio:g} giờ")
        print(f"Tổng: {round(sum(tong.values()), 2):g} giờ")
```

2. **Các test cần kiểm thử kỹ cho Tester**:
- `loc_buoi_trong_tuan`: Kiểm tra mốc biên `hom_nay - 6 ngày` (được giữ) so với `hom_nay - 7 ngày` (bị loại), và buổi tương lai `> hom_nay` (bị loại).
- CLI `tuan`: Kiểm tra thứ tự giảm dần theo giờ, dòng `Tổng: X giờ`, trường hợp không có buổi nào trong 7 ngày in `Chưa có buổi học nào trong 7 ngày qua.` (không in dòng `Tổng:`, mã thoát `0`), và tham số `--ngay` không đúng định dạng thoát mã `1` ra stderr.
