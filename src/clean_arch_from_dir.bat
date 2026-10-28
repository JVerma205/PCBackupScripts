@echo off
setlocal enabledelayedexpansion
call "%~dp0config.bat"

:: ==================================================
:: 1. USER INPUT & CONFIGURATION
:: ==================================================

:: Prompt user for target directory
set /p "user_dir=Enter directory path: "
set "user_dir=%user_dir:"=%"

if not exist "%user_dir%\" (
    echo.
    echo Error: The specified directory does not exist.
    echo.
    pause
    exit /b 1
)

:: Prompt user for Simulation Mode
echo.
echo Select Mode:
echo [1] SIMULATION MODE (Log folders and sizes without deleting)
echo [2] DELETE MODE (Log folders and contents, then PERMANENTLY delete)
set /p "mode_choice=Enter choice (1 or 2): "

if "%mode_choice%"=="1" (
    echo Running in SIMULATION MODE. No folders will be deleted.
    set "sim_mode=True"
) else (
    echo Running in DELETE MODE. Folders will be permanently deleted.
    set "sim_mode=False"
)

set "log_suffix=_folder_deletion_log"
call "%~dp0common.bat" :LogFileSetup "%log_suffix%"
set "temp_file=%temp%\arc_folders_list.tmp"

if exist "%temp_file%" del "%temp_file%"

echo.
if "%sim_mode%"=="True" (
    echo "*** RUNNING IN SIMULATION MODE (No folders will be deleted) ***"
) else (
    echo "*** WARNING: RUNNING IN DELETE MODE ***"
)
echo Searching for matching folders in: "%user_dir%"...

:: ==================================================
:: 2. SCAN FOR MATCHING FOLDERS
:: ==================================================

for /f "delims=" %%F in ('dir /b /s /ad "%user_dir%" 2^>nul') do (
    set "folder_name=%%~nxF"
    set "is_match=0"

    :: Check the configured names and names starting with 'arch'
    for %%N in (!match_folders!) do (
        if /i "!folder_name!"=="%%N" set "is_match=1"
    )
    if /i "!folder_name:~0,4!"=="arch" set "is_match=1"

    if "!is_match!"=="1" (
        echo %%F>> "%temp_file%"
    )
)

if not exist "%temp_file%" (
    echo No folders named 'arc' or starting with 'arch' were found.
    echo.
    pause
    exit /b 0
)

:: ==================================================
:: 3. INITIALIZE CSV LOG FILE
:: ==================================================
call "%~dp0common.bat" :CSVHeaderSetup


:: ==================================================
:: 4. LOG CONTENTS, CALCULATE SIZE, & PROCESS
:: ==================================================

for /f "delims=" %%F in ('type "%temp_file%"') do (
    if exist "%%F" (
        call "%~dp0common.bat" :writeRowToLogFile "%%F"

        if "%sim_mode%"=="False" (
            if not "!skip_delete!"=="1" (
                rmdir /s /q "%%F"
                if errorlevel 1 (
                    set "error_folder=%%F"
                    set "error_file_path="
                    set "error_detail=Unable to delete folder."
                    call "%~dp0common.bat" :LogError
                )
            )
        )
    )
)

if exist "%temp_file%" del "%temp_file%"

echo.
echo ==================================================
echo Process completed! Log saved to:
echo "%log_file%"
echo ==================================================
echo.
pause
exit /b 0