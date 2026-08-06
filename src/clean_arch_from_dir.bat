@echo off
setlocal enabledelayedexpansion

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

set "log_file=%user_dir%\folder_deletion_log.csv"
echo Log file will be created at: "%log_file%"
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

    :: Check if folder name is 'arc' or starts with 'arch'
    if /i "!folder_name!"=="arc" set "is_match=1"
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

(
    echo "Logged folder name","Logged folder path","Last modified date","Count of folder contents","Folder size in bytes","Content list","Simulation Flag"
) > "%log_file%"

echo Log file initialized at: "%log_file%"
echo.

:: ==================================================
:: 4. LOG CONTENTS, CALCULATE SIZE, & PROCESS
:: ==================================================

for /f "delims=" %%F in ('type "%temp_file%"') do (
    if exist "%%F" (
        set "folder_name=%%~nxF"
        set "folder_path=%%F"
        set "last_mod=%%~tF"
        set "content_count=0"
        set "folder_size=0"
        set "content_list="

        for /f "tokens=3 delims= " %%S in ('dir /s /a /-c "%%F" 2^>nul ^| findstr /i /c:"File(s)"') do (
            set "folder_size=%%S"
        )

        for /f "delims=" %%C in ('dir /b /s /a "%%F" 2^>nul') do (
            set /a content_count+=1
            set "item_name=%%~nxC"
            set "item_name=!item_name:"='!"
            if defined content_list (
                set "content_list=!content_list!;!item_name!"
            ) else (
                set "content_list=!item_name!"
            )
        )

        if "%sim_mode%"=="True" (
            echo [SIMULATION] Logging: "%%F"
        ) else (
            echo Logging and deleting: "%%F"
        )

        set "folder_path_esc=!folder_path:"=""!"
        set "last_mod_esc=!last_mod:"=""!"
        set "content_list_esc=!content_list:"=""!"
        set "csv_line="!folder_name!","!folder_path_esc!","!last_mod_esc!","!content_count!","!folder_size!","!content_list_esc!","!sim_mode!""

        >> "%log_file%" echo !csv_line!

        if "%sim_mode%"=="False" (
            rmdir /s /q "%%F"
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