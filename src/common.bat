@echo off
if /i "%~1"==":LogFileSetup" goto :LogFileSetup
if /i "%~1"==":CSVHeaderSetup" goto :CSVHeaderSetup
if /i "%~1"==":LogError" goto :LogError
if /i "%~1"==":writeRowToLogFile" goto :writeRowToLogFile
exit /b 0

:LogFileSetup
set "log_suffix=%~2"
for %%I in ("%user_dir%") do set "log_base_name=%%~nxI"
if not defined log_base_name set "log_base_name=folder"
set "log_file=logs\%log_base_name%%log_suffix%.csv"
if "%sim_mode%"=="True" set "log_file=logs\%log_base_name%%log_suffix%_sim.csv"

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
for %%I in ("%log_file%") do set "log_dir=%%~dpI"
if not exist "%log_dir%" mkdir "%log_dir%" 2>nul
set "error_file=%log_dir%error.txt"

:: Prepare secondary CSV for folders containing 'prompt'
set "prompt_log_file=%log_dir%list_of_prompt_dirs.csv"
if not exist "%prompt_log_file%" (
	(
		echo "Logged folder name","Logged folder path","Last modified date","Count of folder contents","Folder size in bytes","Content list","Simulation Flag"
	) >> "%prompt_log_file%"
	echo Prompt-folders log initialized at: "%prompt_log_file%"
) else (
	echo Appending to existing prompt-folders log: "%prompt_log_file%"
)
exit /b 0


:CSVHeaderSetup
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
exit /b 0


:writeRowToLogFile
set "folder_path=%~2"
for %%P in ("%~2") do (
	set "folder_name=%%~nxP"
	set "last_mod=%%~tP"
)
set "content_count=0"
set "folder_size=0"
set "content_list="
set "has_prompt=0"
set "skip_delete=0"
set "size_found=0"
set "content_error_file=%temp%\arc_content_error_!RANDOM!.tmp"
set "content_scan_switch=/s"
if /i "%~4"=="True" set "content_scan_switch="

for /f "tokens=3 delims= " %%S in ('dir /s /a /-c "%~2" 2^>nul ^| findstr /i /c:"File(s)"') do (
	set "folder_size=%%S"
	set "size_found=1"
)
if "!size_found!"=="0" (
	set "error_folder=%~2"
	set "error_file_path="
	set "error_detail=Unable to calculate folder size."
	call :LogError
)

for /f "delims=" %%C in ('dir /b !content_scan_switch! /a "%~2" 2^>"!content_error_file!"') do (
	echo Content List item: "%%C"
	set /a content_count+=1
	set "item_name=%%~nxC"
	set "item_name=!item_name:"='!"
	if defined content_list (
		set "content_list=!content_list!;!item_name!"
	) else (
		set "content_list=!item_name!"
	)
	echo !item_name! | findstr /i "prompt" >nul 2>nul && set "has_prompt=1"
)
if exist "!content_error_file!" (
	set "error_folder=%~2"
	set "error_file_path="
	for /f "delims=" %%E in ('type "!content_error_file!"') do (
		set "error_detail=%%E"
		call :LogError
	)
	del /q "!content_error_file!" >nul 2>&1
)

if "%sim_mode%"=="True" (
	echo [SIMULATION] Logging: "%~2"
) else (
	echo Logging and executing: "%~2"
)
set "folder_path_esc=!folder_path:"=""!"
set "last_mod_esc=!last_mod:"=""!"
set "content_list=!content_list:~0,1000!"
set "content_list_esc=!content_list:"=""!"
set "csv_line="!folder_name!","!folder_path_esc!","!last_mod_esc!","!content_count!","!folder_size!","!content_list_esc!","!sim_mode!""
>> "%log_file%" echo !csv_line!

if "!has_prompt!"=="1" if /i not "%~3"=="NoPromptRename" (
	>> "%prompt_log_file%" echo !csv_line!
	for %%P in ("%~2") do set "parent_dir=%%~dpP"
	set "target_dir=!parent_dir!Prompts"
	if exist "!target_dir!" set "target_dir=!parent_dir!Prompts_!random!"
	move "%~2" "!target_dir!" >nul 2>&1
	if errorlevel 1 (
		set "error_folder=%~2"
		set "error_file_path="
		set "error_detail=Unable to rename folder to !target_dir!."
		call :LogError
	) else (
		echo Renamed "%~2" to "!target_dir!"
	)
	set "skip_delete=1"
)
exit /b 0

:LogError
>>"%error_file%" echo [%date% %time%] %error_detail%
>>"%error_file%" echo Archive folder: %error_folder%
>>"%error_file%" echo File path: %error_file_path%
>>"%error_file%" echo.
exit /b 0
