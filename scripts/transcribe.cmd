@echo off
REM Voice-note transcription wrapper for OpenClaw's audio.transcription/tools.media.audio hook.
REM Converts incoming audio to 16kHz mono WAV, then runs whisper.cpp locally (no cloud STT).
REM Adjust the two paths below to where you installed ffmpeg and whisper.cpp on your machine.

setlocal
set "IN=%~1"
set "TMPWAV=%TEMP%\oc-voice-%RANDOM%%RANDOM%.wav"

REM --- adjust this path to your ffmpeg.exe ---
set "FFMPEG=%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-essentials_build\bin\ffmpeg.exe"

"%FFMPEG%" -y -i "%IN%" -ar 16000 -ac 1 -f wav "%TMPWAV%" >nul 2>&1
if errorlevel 1 (
  echo [transcription failed: could not convert audio]
  exit /b 1
)

REM --- adjust these two paths to your whisper.cpp install + model ---
set "WHISPER_CLI=%USERPROFILE%\.openclaw\bin\whisper\Release\whisper-cli.exe"
set "WHISPER_MODEL=%USERPROFILE%\.openclaw\bin\whisper\ggml-small.bin"

"%WHISPER_CLI%" -m "%WHISPER_MODEL%" -f "%TMPWAV%" -l auto -nt -np 2>nul
set "RC=%ERRORLEVEL%"
del "%TMPWAV%" >nul 2>&1
exit /b %RC%
