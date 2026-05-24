@echo off
setlocal

cd /d "%~dp0"

echo ====================================================
echo              AIRLoad Setup and Launch
echo ====================================================

where python >nul 2>nul
if errorlevel 1 (
    echo Python is not installed or not added to PATH.
    echo Please install Python 3.10 or newer, then run this file again.
    pause
    exit /b 1
)

if not exist ".venv" (
    echo Creating virtual environment...
    python -m venv .venv
)

echo Activating virtual environment...
call .venv\Scripts\activate.bat

echo Upgrading pip...
python -m pip install --upgrade pip

echo Installing AIRLoad dependencies...
python -m pip install -r requirements.txt

echo Launching AIRLoad dashboard...
python main\Interface\dashboard14.py

pause