TRANG_THAI: XONG

## Đã làm
- **Bước 1 & 2**: Cập nhật import `timedelta` từ module `datetime` trong [so_tay_hoc.py](file:///D:/day-chuyen-4-agent/so_tay_hoc.py); thêm hằng số `SO_NGAY_TUAN = 7` ngay dưới `TEP_MAC_DINH`; cập nhật docstring ví dụ ở đầu file.
- **Bước 3**: Triển khai hàm [`loc_buoi_trong_tuan(ds: list[BuoiHoc], hom_nay: date) -> list[BuoiHoc]`](file:///D:/day-chuyen-4-agent/so_tay_hoc.py#L78-L90) với type hint đầy đủ và docstring một dòng; lọc lấy các buổi học trong khoảng đóng `[hom_nay - 6 ngày, hom_nay]`; xử lý ngoại lệ khi trường ngày trong dữ liệu không đúng định dạng ISO và ném `ValueError` kèm thông báo tiếng Việt.
- **Bước 4**: Thêm subparser `tuan` hỗ trợ cờ tuỳ chọn `--ngay` trong [`tao_parser()`](file:///D:/day-chuyen-4-agent/so_tay_hoc.py#L93-L110); thêm xử lý `elif args.lenh == "tuan":` trong [`main()`](file:///D:/day-chuyen-4-agent/so_tay_hoc.py#L113-L151), chuyển đổi tham số `--ngay` nếu có hoặc mặc định `date.today()`, sử dụng lại [`tong_theo_chu_de`](file:///D:/day-chuyen-4-agent/so_tay_hoc.py#L72-L76), làm tròn tổng giờ và in ra đúng định dạng yêu cầu.
- **Bước 5**: Thêm các test case vào [tests/test_so_tay_hoc.py](file:///D:/day-chuyen-4-agent/tests/test_so_tay_hoc.py) bao gồm kiểm tra mốc đầu cửa sổ 7 ngày, loại bỏ buổi tương lai, in tổng giờ và thứ tự giảm dần, trường hợp không có buổi nào trong tuần, ngày sai định dạng và dữ liệu ngày hỏng.
- **Bước 6**: Chạy `python -m pytest -q` đảm bảo toàn bộ 16 test case (cũ và mới) đều pass.

## File đã thay đổi
- [so_tay_hoc.py](file:///D:/day-chuyen-4-agent/so_tay_hoc.py) → Thêm hằng số `SO_NGAY_TUAN`, hàm [`loc_buoi_trong_tuan`](file:///D:/day-chuyen-4-agent/so_tay_hoc.py#L78-L90), subparser `tuan` và nhánh xử lý CLI `tuan` trong [`main`](file:///D:/day-chuyen-4-agent/so_tay_hoc.py#L113-L151).
- [tests/test_so_tay_hoc.py](file:///D:/day-chuyen-4-agent/tests/test_so_tay_hoc.py) → Thêm 6 bài test cho chức năng lệnh `tuan` và hàm lọc theo tuần.

## Đã sửa theo phản hồi
Không có

## Kết quả tự chạy test
- `python -m pytest -q`: 16 passed in 0.07s
- `python so_tay_hoc.py --help`: Liệt kê đầy đủ subcommands `them, ds, tong, tuan`.
- `python so_tay_hoc.py tuan --help`: Hiển thị trợ giúp cho lệnh `tuan` và cờ `--ngay`.

## Ghi chú cho Tester
- Mốc biên đầu khoảng 7 ngày (`hom_nay - 6 ngày`): cần chắc chắn ngày này được tính vào tổng giờ, còn `hom_nay - 7 ngày` bị loại bỏ.
- Buổi học có ngày trong tương lai (`ngay > hom_nay`): không được tính vào kết quả của lệnh `tuan`.
- Trường hợp không có dữ liệu học trong 7 ngày: chương trình chỉ in duy nhất một dòng `Chưa có buổi học nào trong 7 ngày qua.`, không có dòng `Tổng:`, mã thoát là `0`.
- Kiểm tra các lỗi đầu vào (`--ngay` sai định dạng YYYY-MM-DD hoặc trường `ngay` trong file dữ liệu JSON bị hỏng): chương trình in thông báo lỗi bắt đầu bằng `Lỗi:` ra `stderr`, trả mã thoát `1` và không xuất hiện traceback.
