"""Test cho sổ tay học tập."""

from pathlib import Path

import pytest

import so_tay_hoc as st


def test_them_va_doc_lai(tmp_path: Path) -> None:
    tep = tmp_path / "du_lieu.json"
    st.them_buoi(tep, "  Python  ", 1.5, ngay="2026-10-01", ghi_chu="vòng lặp")
    assert st.doc_du_lieu(tep) == [st.BuoiHoc("Python", 1.5, "2026-10-01", "vòng lặp")]


def test_doc_khi_chua_co_file(tmp_path: Path) -> None:
    assert st.doc_du_lieu(tmp_path / "chua-co.json") == []


@pytest.mark.parametrize("so_gio", [0, -1, 24.5])
def test_so_gio_khong_hop_le(tmp_path: Path, so_gio: float) -> None:
    with pytest.raises(ValueError):
        st.them_buoi(tmp_path / "du_lieu.json", "Python", so_gio)


def test_chu_de_rong(tmp_path: Path) -> None:
    with pytest.raises(ValueError):
        st.them_buoi(tmp_path / "du_lieu.json", "   ", 1)


def test_ngay_sai_dinh_dang(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="YYYY-MM-DD"):
        st.them_buoi(tmp_path / "du_lieu.json", "Python", 1, ngay="01/10/2026")


def test_tong_theo_chu_de_giam_dan() -> None:
    ds = [
        st.BuoiHoc("A", 1, "2026-10-01"),
        st.BuoiHoc("B", 3, "2026-10-01"),
        st.BuoiHoc("A", 0.5, "2026-10-02"),
    ]
    assert list(st.tong_theo_chu_de(ds).items()) == [("B", 3), ("A", 1.5)]


def test_cli_them_roi_tong(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    tep = str(tmp_path / "du_lieu.json")
    assert st.main(["--tep", tep, "them", "Python", "2"]) == 0
    assert st.main(["--tep", tep, "them", "Toán", "1"]) == 0
    capsys.readouterr()
    assert st.main(["--tep", tep, "tong"]) == 0
    assert capsys.readouterr().out.splitlines() == ["Python: 2 giờ", "Toán: 1 giờ"]


def test_cli_bao_loi_dau_vao(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert st.main(["--tep", str(tmp_path / "du_lieu.json"), "them", "Python", "0"]) == 1
    assert "Lỗi" in capsys.readouterr().err
