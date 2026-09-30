"""Sổ tay học tập: ghi lại giờ học theo chủ đề (dự án mẫu cho dây chuyền 4 agent).

Ví dụ:
    python so_tay_hoc.py them "Python cơ bản" 1.5 --ghi-chu "vòng lặp for"
    python so_tay_hoc.py ds
    python so_tay_hoc.py tong
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path

TEP_MAC_DINH = Path(__file__).with_name("du_lieu.json")


@dataclass
class BuoiHoc:
    """Một buổi học."""

    chu_de: str
    so_gio: float
    ngay: str  # dạng YYYY-MM-DD
    ghi_chu: str = ""


def doc_du_lieu(tep: Path) -> list[BuoiHoc]:
    """Đọc các buổi học từ file JSON; chưa có file thì trả về danh sách rỗng."""
    if not tep.exists():
        return []
    du_lieu = json.loads(tep.read_text(encoding="utf-8"))
    return [BuoiHoc(**muc) for muc in du_lieu]


def ghi_du_lieu(tep: Path, ds: list[BuoiHoc]) -> None:
    """Ghi các buổi học ra file JSON."""
    noi_dung = json.dumps([asdict(b) for b in ds], ensure_ascii=False, indent=2)
    tep.write_text(noi_dung, encoding="utf-8")


def them_buoi(
    tep: Path, chu_de: str, so_gio: float, ngay: str | None = None, ghi_chu: str = ""
) -> BuoiHoc:
    """Thêm một buổi học; báo ValueError nếu dữ liệu không hợp lệ."""
    chu_de = chu_de.strip()
    if not chu_de:
        raise ValueError("Chủ đề không được để trống.")
    if not 0 < so_gio <= 24:
        raise ValueError("Số giờ phải lớn hơn 0 và không quá 24.")
    if ngay is None:
        ngay = date.today().isoformat()
    else:
        try:
            ngay = date.fromisoformat(ngay).isoformat()
        except ValueError as loi:
            raise ValueError("Ngày phải có dạng YYYY-MM-DD, ví dụ 2026-10-01.") from loi
    buoi = BuoiHoc(chu_de=chu_de, so_gio=round(so_gio, 2), ngay=ngay, ghi_chu=ghi_chu.strip())
    ds = doc_du_lieu(tep)
    ds.append(buoi)
    ghi_du_lieu(tep, ds)
    return buoi


def tong_theo_chu_de(ds: list[BuoiHoc]) -> dict[str, float]:
    """Cộng tổng số giờ theo chủ đề, sắp xếp giảm dần theo số giờ."""
    tong: dict[str, float] = {}
    for buoi in ds:
        tong[buoi.chu_de] = tong.get(buoi.chu_de, 0.0) + buoi.so_gio
    return dict(sorted(tong.items(), key=lambda cap: cap[1], reverse=True))


def tao_parser() -> argparse.ArgumentParser:
    """Tạo bộ phân tích tham số dòng lệnh."""
    parser = argparse.ArgumentParser(description="Sổ tay học tập: ghi lại giờ học theo chủ đề.")
    parser.add_argument("--tep", type=Path, default=TEP_MAC_DINH, help="file dữ liệu JSON")
    lenh = parser.add_subparsers(dest="lenh", required=True)

    p_them = lenh.add_parser("them", help="thêm một buổi học")
    p_them.add_argument("chu_de", help="chủ đề đã học, ví dụ: 'Python cơ bản'")
    p_them.add_argument("so_gio", type=float, help="số giờ học, ví dụ: 1.5")
    p_them.add_argument("--ngay", help="ngày học dạng YYYY-MM-DD (mặc định: hôm nay)")
    p_them.add_argument("--ghi-chu", default="", help="ghi chú ngắn")

    lenh.add_parser("ds", help="liệt kê các buổi học")
    lenh.add_parser("tong", help="tổng số giờ theo chủ đề")
    return parser


def main(argv: list[str] | None = None) -> int:
    """Điểm vào của chương trình; trả về mã thoát."""
    args = tao_parser().parse_args(argv)
    try:
        if args.lenh == "them":
            buoi = them_buoi(args.tep, args.chu_de, args.so_gio, args.ngay, args.ghi_chu)
            print(f"Đã thêm: {buoi.ngay} | {buoi.chu_de} | {buoi.so_gio:g} giờ")
        elif args.lenh == "ds":
            ds = doc_du_lieu(args.tep)
            if not ds:
                print("Chưa có buổi học nào.")
            for i, buoi in enumerate(ds, start=1):
                ghi_chu = f" | {buoi.ghi_chu}" if buoi.ghi_chu else ""
                print(f"{i}. {buoi.ngay} | {buoi.chu_de} | {buoi.so_gio:g} giờ{ghi_chu}")
        elif args.lenh == "tong":
            tong = tong_theo_chu_de(doc_du_lieu(args.tep))
            if not tong:
                print("Chưa có buổi học nào.")
            for chu_de, so_gio in tong.items():
                print(f"{chu_de}: {so_gio:g} giờ")
    except ValueError as loi:
        print(f"Lỗi: {loi}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
