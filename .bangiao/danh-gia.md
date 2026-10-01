Đã đọc đủ: yêu cầu, kế hoạch, báo cáo Coder/Tester, `test-output.txt`, `diff.patch` và hai file nguồn `so_tay_hoc.py`, `tests/test_so_tay_hoc.py`.

PHAN_QUYET: CHOT

## Tóm tắt
Lệnh `tuan` được triển khai đúng như kế hoạch mô tả: hằng `SO_NGAY_TUAN`, hàm `loc_buoi_trong_tuan`, subparser `tuan --ngay` và nhánh xử lý trong `main()` khớp từng dòng với chữ ký đã thống nhất. Toàn bộ 15 tiêu chí hoàn thành đều có bằng chứng kiểm chứng được, 25/25 test xanh trong output thật (`exit code: 0`). Không phát hiện lỗi logic, rủi ro bảo mật hay thay đổi ngoài phạm vi trong mã sản phẩm.

## Đối chiếu tiêu chí hoàn thành

| # | Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|---|
| 1 | Có hằng `SO_NGAY_TUAN = 7` | Đạt | `so_tay_hoc.py:20`; test `test_hang_so_ngay_tuan` |
| 2 | Hàm `loc_buoi_trong_tuan` đủ type hint + docstring một dòng | Đạt | `so_tay_hoc.py:78-89`; test `test_loc_buoi_trong_tuan_chu_ky_va_docstring` kiểm tra bằng `typing.get_type_hints` |
| 3 | `--help` liệt kê lệnh `tuan` | Đạt | `so_tay_hoc.py:106`; test `test_cli_help_liet_ke_lenh_tuan` |
| 4 | `tuan --help` hiện cờ `--ngay` | Đạt | `so_tay_hoc.py:107`; test `test_cli_tuan_help_hien_co_ngay` |
| 5 | Buổi `2026-09-24` bị loại khi `hom_nay=2026-10-01` | Đạt | `test_loc_buoi_trong_tuan_bo_buoi_cu` (mức hàm) + `test_cli_tuan_in_tong` (chủ đề "Lịch sử" không có trong output CLI) |
| 6 | Buổi `2026-09-25` (mốc đầu) được tính | Đạt | Hai test trên; `moc_dau = hom_nay - timedelta(6)`, so sánh `<=` hai đầu → khoảng đóng |
| 7 | Buổi ngày tương lai không được tính | Đạt | `test_loc_buoi_trong_tuan_bo_buoi_tuong_lai` + `test_cli_tuan_bo_buoi_tuong_lai` |
| 8 | Dòng chủ đề đúng dạng `Chủ đề: X giờ`, giảm dần | Đạt | `so_tay_hoc.py:145`; `test_cli_tuan_in_tong` so khớp nguyên văn `["Python: 3.5 giờ", "Toán: 3 giờ", ...]` |
| 9 | Dòng cuối `Tổng: X giờ` bằng tổng phía trên | Đạt | `so_tay_hoc.py:146`; `3.5 + 3 = 6.5` khớp `"Tổng: 6.5 giờ"` |
| 10 | Rỗng → đúng một dòng, không có `Tổng:`, mã thoát 0 | Đạt | `so_tay_hoc.py:141-142` (nhánh `else` chặn dòng `Tổng:`); `test_cli_tuan_khong_co_buoi` phủ cả file chưa tồn tại lẫn file chỉ có buổi cũ |
| 11 | `--ngay 01/10/2026` → mã 1, `Lỗi:` ra stderr, không traceback | Đạt | `so_tay_hoc.py:135-138, 147-149`; `test_cli_tuan_ngay_sai_dinh_dang` khẳng định `err.strip()` nguyên văn và `"Traceback" not in err` |
| 12 | Có đủ 5 test mới nêu ở bước 6 | Đạt | Cả 5 tên hàm đều hiện diện, Tester bổ sung thêm 10 test nữa |
| 13 | `python -m pytest -q` xanh toàn bộ | Đạt | `.bangiao/test-output.txt`: `25 passed in 0.08s`, `exit code: 0`. Đếm thủ công khớp: 10 ca cũ (gồm `test_so_gio_khong_hop_le` parametrize ×3) + 15 ca mới = 25 |
| 14 | Không thêm thư viện ngoài chuẩn | Đạt | Chỉ thêm `timedelta` (stdlib) và `typing` trong test |
| 15 | Không sửa `tong_theo_chu_de`, `them_buoi`, `doc_du_lieu`, `ghi_du_lieu` | Đạt | `diff.patch` không có hunk nào chạm vào bốn hàm này |

Kiểm tra bổ sung ngoài danh sách tiêu chí:
- **Lỗi dữ liệu ngày hỏng**: `so_tay_hoc.py:85-86` ném `ValueError` tiếng Việt, được `main()` bắt → stderr + mã 1. Có test cả mức hàm (`test_loc_buoi_trong_tuan_ngay_du_lieu_hong`) lẫn mức CLI (`test_cli_tuan_ngay_du_lieu_hong`).
- **`--ngay` mặc định**: `test_cli_tuan_mac_dinh_hom_nay` monkeypatch `st.date` — test có giá trị thật, chứng minh nhánh `date.today()` chạy đúng.
- **Chủ đề cùng số giờ**: `test_cli_tuan_nhieu_chu_de_cung_so_gio` xác nhận thứ tự xuất hiện được giữ.
- **Bảo mật**: không có đầu vào chưa kiểm tra đi vào lệnh hệ thống, không lộ bí mật, không ghi file ngoài `--tep`. Việc `--tep` nhận đường dẫn tuỳ ý là hành vi có sẵn từ trước, không do thay đổi lần này tạo ra.

## Việc cần sửa
Không có.

## Gợi ý thêm
Ba điểm nhỏ, **không** cần sửa trước khi gộp nhánh:

1. **`test_cli_tuan_lam_tron_so_gio_float` không thật sự chứng minh được việc làm tròn.** `1.1 + 2.2 = 3.3000000000000003`, nhưng `f"{...:g}"` chỉ lấy 6 chữ số có nghĩa nên vẫn in `3.3` kể cả khi bỏ `round(..., 2)`. Test vẫn đúng và hữu ích (khoá định dạng đầu ra), chỉ là không phân biệt được hai cài đặt. Nếu muốn bảo vệ đúng ý đồ, cần một bộ số mà `:g` làm lộ sai số, ví dụ tổng 7 buổi `0.1` giờ. Tiêu chí hoàn thành không đòi hỏi điều này nên đây chỉ là gợi ý.

2. **`diff.patch` có thay đổi trong `.agents/agents/*.md`** (bỏ dấu tiếng Việt ở `description`, khai báo `tools`/`commandExecutionPolicy`). Đối chiếu git log, phần này thuộc commit `e09eff2 "Khai bao tools cho agent agy"` — là cấu hình hạ tầng do con người sửa sau khi vòng 1 bị kẹt, không phải Coder làm thừa ngoài kế hoạch. Nêu ra để người duyệt biết khi nhìn diff, không tính là lỗi.

3. **Dòng dài quá 100 ký tự** tại `tests/test_so_tay_hoc.py:172` (chuỗi JSON inline). Thuần văn phong, có thể tách chuỗi khi nào tiện.