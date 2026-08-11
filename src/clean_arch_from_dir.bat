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

for %%I in ("%user_dir%") do set "log_base_name=%%~nxI"
if not defined log_base_name set "log_base_name=folder"
set "log_file=logs\%log_base_name%_folder_deletion_log.csv"
if "%sim_mode%"=="True" set "log_file=logs\%log_base_name%_folder_deletion_log_sim.csv"

if exist "%log_file%" (
    echo.
    echo Log file already exists: "%log_file%"
    set /p "log_choice=Append to existing log? [A]ppend or [N]ew file: "
    if /i not "!log_choice!"=="N" (
        set "log_choice=A"
    ) else (
        set /p "new_log_name=Enter new log file name (for example: my_log.csv): "
        if not defined new_log_name set "new_log_name=!log_base_name!_my_log.csv"
        set "new_log_name=!new_log_name:"=!"
        echo New log file name set to: "!new_log_name!"
        if /i not "!new_log_name:~0,1!"=="\" (
            if /i not "!new_log_name:~0,1!"=="/" (
                set "log_file=logs\!new_log_name!"
            ) else (
                set "log_file=!new_log_name!"
            )
        ) else (
            set "log_file=!new_log_name!"
        )
        if /i not "!log_file:~-4!"==".csv" set "log_file=!log_file!.csv"
    )
)

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

:: Ensure the log directory exists (handles relative paths)
for %%I in ("%log_file%") do set "log_dir=%%~dpI"
if not exist "%log_dir%" (
    mkdir "%log_dir%" 2>nul
)

:: Write CSV header only if the log file does not already exist
if not exist "%log_file%" (
    (
        echo "Logged folder name","Logged folder path","Last modified date","Count of folder contents","Folder size in bytes","Content list","Simulation Flag"
    ) >> "%log_file%"
    echo Log file initialized at: "%log_file%"
    echo.
) else (
    echo Appending to existing log: "%log_file%"
    echo.
)

:: Prepare secondary CSV for folders containing 'prompt'
set "list_log_file=%log_dir%list_of_prompt_dirs.csv"
if not exist "%list_log_file%" (
    (
        echo "Logged folder name","Logged folder path","Last modified date","Count of folder contents","Folder size in bytes","Content list","Simulation Flag"
    ) >> "%list_log_file%"
    echo Prompt-folders log initialized at: "%list_log_file%"
) else (
    echo Appending to existing prompt-folders log: "%list_log_file%"
)

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
        set "has_prompt=0"
        set "skip_delete=0"

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

            :: detect if item name contains 'prompt' (case-insensitive)
            echo !item_name! | findstr /i "prompt" >nul 2>nul && set "has_prompt=1"
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

        :: If any content item contains 'prompt', log to the prompt-list CSV and rename the folder to 'Prompts'
        if "!has_prompt!"=="1" (
            set "csv_line2=!csv_line!"
            >> "%list_log_file%" echo !csv_line2!

            :: compute parent dir and target name
            for %%P in ("%%F") do set "parent_dir=%%~dpP"
            set "target_dir=!parent_dir!Prompts"
            if exist "!target_dir!" set "target_dir=!parent_dir!Prompts_!random!"

            :: attempt rename/move (do not delete this folder)
            move "%%F" "!target_dir!" >nul 2>&1
            echo Renamed "%%F" to "!target_dir!"
            set "skip_delete=1"
        )

        if "%sim_mode%"=="False" (
            if not "!skip_delete!"=="1" (
                rmdir /s /q "%%F"
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