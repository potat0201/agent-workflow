@echo off
rem Chay ship.ps1 ke ca khi PowerShell dang chan chay script (ExecutionPolicy).
rem Dung giong het ship.ps1, vd:  ship.cmd -KiemTra   hoac   ship.cmd -TiepTuc
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ship.ps1" %*
exit /b %ERRORLEVEL%
