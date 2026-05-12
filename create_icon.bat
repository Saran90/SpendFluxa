@echo off
REM Batch file to create Play Store icon - tries multiple methods

echo ========================================
echo Creating Play Store Icon (512x512)
echo ========================================
echo.

REM Method 1: Try Python script
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Trying Python method...
    python create_play_store_icon.py
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo Success! Icon created using Python.
        goto :end
    )
)

REM Method 2: Try PowerShell script
echo Trying PowerShell method...
powershell -ExecutionPolicy Bypass -File create_play_store_icon.ps1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Success! Icon created using PowerShell.
    goto :end
)

REM If all methods fail
echo.
echo ========================================
echo Automatic creation failed!
echo ========================================
echo.
echo Please use one of these manual methods:
echo.
echo 1. Online Tools (Easiest):
echo    - Visit: https://www.iloveimg.com/resize-image
echo    - Upload: assets\icons\app_icon.png
echo    - Resize to: 512 x 512 pixels
echo    - Download and save as: play_store_icon_512.png
echo.
echo 2. Install ImageMagick:
echo    winget install ImageMagick.ImageMagick
echo    Then run: create_play_store_icon.ps1
echo.
echo 3. Install Python + Pillow:
echo    pip install Pillow
echo    Then run: python create_play_store_icon.py
echo.
echo See CREATE_PLAY_STORE_ICON.md for more details.
echo.

:end
pause
