CAU_HOI_MO: KHONG

# Kế hoạch: Thêm lệnh `tuan` cho sổ tay học tập

## Mục tiêu
Thêm lệnh con `tuan` vào `so_tay_hoc.py`: tổng hợp số giờ học trong cửa sổ 7 ngày gần nhất (tính cả hôm nay), gộp theo chủ đề, in giảm dần theo số giờ với định dạng `Chủ đề: X giờ`, rồi in dòng cuối `Tổng: X giờ`. Nếu không có buổi học nào trong cửa sổ thì in `Chưa có buổi học nào trong 7 ngày qua.` Buổi học cũ hơn 7 ngày không được tính.

## Giả định
1. **Cửa sổ 7 ngày** là khoảng đóng `[hom_nay - 6 ngày, hom_nay]`. Ví dụ hôm nay là `2026-10-01` thì tính các ngày `2026-09-25` → `2026-10-01`; ngày `2026-09-24` bị loại.
2. **Buổi học có ngày trong tương lai** (lớn hơn `hom_nay`) nằm ngoài cửa sổ nên **không được tính**. Người dùng có thể tạo buổi như vậy qua `them --ngay`.
3. **Mốc "hôm nay" phải truyền vào được** để test ổn định: hàm lọc nhận tham số `hom_nay: date`; CLI có cờ tùy chọn `--ngay` (mặc định `date.today()`), giống cách lệnh `them` đã dùng tên `--ngay`.
4. Khi không có buổi học nào trong cửa sổ: in đúng một dòng thông báo, **không in dòng `Tổng:`**, mã thoát vẫn là `0` (giống cách lệnh `ds`/`tong` xử lý danh sách rỗng hiện nay).
5. Định dạng số giờ dùng `:g` giống code hiện có (`2` chứ không phải `2.0`, `1.5` giữ nguyên).
6. Hai chủ đề bằng nhau về số giờ giữ nguyên thứ tự xuất hiện lần đầu trong dữ liệu (`sorted` của Python ổn định — đúng hành vi sẵn có của `tong_theo_chu_de`).
7. Tổng được làm tròn 2 chữ số thập phân trước khi in, để tránh sai số cộng dồn float kiểu `2.9999999999999996`.
8. Bản ghi trong file dữ liệu có trường `ngay` sai định dạng là lỗi dữ liệu: báo `ValueError` với thông báo tiếng Việt rõ ràng → stderr + mã thoát 1, không để lộ traceback (theo AGENTS.md).

## File cần tạo / sửa
| Đường dẫn | Việc cần làm |
|---|---|
| `so_tay_hoc.py` | Thêm hằng `SO_NGAY_TUAN = 7`; thêm hàm `loc_buoi_trong_tuan(...)`; thêm subparser `tuan` trong `tao_parser()`; thêm nhánh `elif args.lenh == "tuan":` trong `main()`. Dùng lại `tong_theo_chu_de` đã có, **không sửa** hàm này. |
| `tests/test_so_tay_hoc.py` | Thêm các test cho hàm lọc và cho CLI `tuan` (xem mục Các bước triển khai, bước 5). |
| `README` / tài liệu khác | Không có file nào cần sửa thêm. Docstring đầu `so_tay_hoc.py` có mục "Ví dụ": thêm một dòng `python so_tay_hoc.py tuan`. |

## Chữ ký hàm / giao diện dòng lệnh

### Hằng số (đặt ngay dưới `TEP_MAC_DINH`)
```python
SO_NGAY_TUAN = 7
```

### Hàm mới (đặt ngay sau `tong_theo_chu_de`)
```python
def loc_buoi_trong_tuan(ds: list[BuoiHoc], hom_nay: date) -> list[BuoiHoc]:
    """Lọc các buổi học trong 7 ngày gần nhất, tính cả ngày hôm nay."""
```
Hành vi:
- `moc_dau = hom_nay - timedelta(days=SO_NGAY_TUAN - 1)`
- Giữ lại buổi thoả `moc_dau <= date.fromisoformat(buoi.ngay) <= hom_nay`.
- Nếu `date.fromisoformat(buoi.ngay)` ném `ValueError`, bắt lại và ném:
  `raise ValueError(f"Dữ liệu có ngày không hợp lệ: {buoi.ngay!r}") from loi`
- Giữ nguyên thứ tự các buổi trong danh sách đầu vào.
- Cần `from datetime import date, timedelta` (sửa dòng import `datetime` hiện có).

### Subparser (trong `tao_parser()`, đặt sau dòng `lenh.add_parser("tong", ...)`)
```python
p_tuan = lenh.add_parser("tuan", help="tổng số giờ 7 ngày gần nhất theo chủ đề")
p_tuan.add_argument("--ngay", help="ngày mốc dạng YYYY-MM-DD (mặc định: hôm nay)")
```

### Nhánh trong `main()` (đặt sau nhánh `tong`, trước `except ValueError`)
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

### Thông báo in ra (chính xác từng ký tự)
- Mỗi chủ đề: `Python: 2.5 giờ`  → mẫu `f"{chu_de}: {so_gio:g} giờ"`
- Dòng cuối: `Tổng: 4 giờ`  → mẫu `f"Tổng: {tong_gio:g} giờ"`
- Khi rỗng: `Chưa có buổi học nào trong 7 ngày qua.`
- Lỗi ngày sai định dạng (đi ra **stderr**, mã thoát 1): `Lỗi: Ngày phải có dạng YYYY-MM-DD, ví dụ 2026-10-01.`
- Lỗi dữ liệu ngày hỏng (stderr, mã thoát 1): `Lỗi: Dữ liệu có ngày không hợp lệ: '01/10/2026'`

## Các bước triển khai
1. Trong `so_tay_hoc.py`, sửa import: `from datetime import date, timedelta`.
2. Thêm hằng `SO_NGAY_TUAN = 7` ngay dưới `TEP_MAC_DINH`.
3. Thêm hàm `loc_buoi_trong_tuan` ngay sau `tong_theo_chu_de`, đúng chữ ký và hành vi ở mục trên (có type hint, docstring một dòng).
4. Thêm subparser `tuan` trong `tao_parser()` và nhánh `elif args.lenh == "tuan"` trong `main()` như mô tả ở trên.
5. Thêm một dòng ví dụ `python so_tay_hoc.py tuan` vào docstring đầu file.
6. Thêm test vào `tests/test_so_tay_hoc.py` (theo đúng phong cách sẵn có: dùng `tmp_path`, `capsys`, gọi `st.main([...])`):
   - `test_loc_buoi_trong_tuan_bo_buoi_cu`: danh sách có các ngày `2026-10-01` (hôm nay), `2026-09-25` (đúng mốc đầu, **phải giữ**), `2026-09-24` (**phải loại**) với `hom_nay = date(2026, 10, 1)`.
   - `test_loc_buoi_trong_tuan_bo_buoi_tuong_lai`: buổi ngày `2026-10-02` bị loại khi `hom_nay = date(2026, 10, 1)`.
   - `test_cli_tuan_in_tong`: thêm vài buổi bằng `them --ngay`, chạy `main(["--tep", tep, "tuan", "--ngay", "2026-10-01"])`, so sánh `capsys.readouterr().out.splitlines()` với danh sách dòng mong đợi, kể cả dòng `Tổng: ... giờ`, và kiểm tra thứ tự giảm dần.
   - `test_cli_tuan_khong_co_buoi`: dữ liệu rỗng hoặc chỉ có buổi cũ hơn 7 ngày → stdout đúng một dòng `Chưa có buổi học nào trong 7 ngày qua.` và mã thoát `0`.
   - `test_cli_tuan_ngay_sai_dinh_dang`: `main([... , "tuan", "--ngay", "01/10/2026"])` trả `1` và `"Lỗi"` nằm trong stderr.
7. Chạy `python -m pytest -q` cho tới khi tất cả test xanh.
8. Chạy `python so_tay_hoc.py --help` và `python so_tay_hoc.py tuan --help` để xác nhận lệnh mới hiện ra đúng.

## Trường hợp biên và lỗi cần xử lý
- **File dữ liệu chưa tồn tại** → `doc_du_lieu` trả `[]` → in `Chưa có buổi học nào trong 7 ngày qua.`, mã thoát 0.
- **Có dữ liệu nhưng toàn buổi cũ hơn 7 ngày** → vẫn in dòng thông báo rỗng, không in `Tổng:`.
- **Đúng mốc biên `hom_nay - 6 ngày`** → được tính (khoảng đóng).
- **Buổi học đúng hôm nay** → được tính.
- **Buổi học ngày tương lai** → không được tính.
- **`--ngay` sai định dạng** → thông báo tiếng Việt ra stderr, mã thoát 1, không lộ traceback.
- **Trường `ngay` trong file JSON hỏng** → `ValueError` có thông báo rõ → stderr, mã thoát 1, không lộ traceback.
- **Sai số float khi cộng** → làm tròn tổng về 2 chữ số thập phân trước khi in.
- **Nhiều chủ đề cùng số giờ** → giữ thứ tự xuất hiện lần đầu, không được ném lỗi.

## Tiêu chí hoàn thành
- [ ] `so_tay_hoc.py` có hằng `SO_NGAY_TUAN = 7`.
- [ ] `so_tay_hoc.py` có hàm `loc_buoi_trong_tuan(ds: list[BuoiHoc], hom_nay: date) -> list[BuoiHoc]` với type hint đầy đủ và docstring một dòng.
- [ ] `python so_tay_hoc.py --help` liệt kê lệnh con `tuan`.
- [ ] `python so_tay_hoc.py tuan --help` hiện cờ `--ngay`.
- [ ] Với dữ liệu chứa buổi `2026-09-24` và `hom_nay=2026-10-01`, buổi đó **không** xuất hiện trong kết quả `tuan`.
- [ ] Với dữ liệu chứa buổi `2026-09-25` và `hom_nay=2026-10-01`, buổi đó **có** được tính.
- [ ] Buổi có ngày lớn hơn `hom_nay` không được tính.
- [ ] Mỗi dòng chủ đề in đúng dạng `Chủ đề: X giờ`, sắp xếp giảm dần theo số giờ.
- [ ] Dòng cuối cùng in đúng dạng `Tổng: X giờ`, bằng tổng các dòng phía trên.
- [ ] Khi không có buổi nào trong 7 ngày: stdout đúng một dòng `Chưa có buổi học nào trong 7 ngày qua.`, không có dòng `Tổng:`, mã thoát `0`.
- [ ] `tuan --ngay 01/10/2026` trả mã thoát `1`, in thông báo bắt đầu bằng `Lỗi:` ra **stderr**, không có traceback.
- [ ] `tests/test_so_tay_hoc.py` có đủ 5 test mới nêu ở bước 6.
- [ ] `python -m pytest -q` chạy xanh toàn bộ, kể cả các test cũ.
- [ ] Không thêm thư viện ngoài thư viện chuẩn; không sửa hàm `tong_theo_chu_de`, `them_buoi`, `doc_du_lieu`, `ghi_du_lieu`.