@echo off
setlocal enabledelayedexpansion

set REMINT_HOME=%~dp0

set args=

:loop
if not "%1"=="" (
  if "%1"=="-b" (
    set remint_opts=!remint_opts! -b %2
    shift
    shift
    goto :loop
  )
  if "%1"=="--begin" (
    set remint_opts=!remint_opts! -b %2
    shift
    shift
    goto :loop
  )
  if "%1"=="-e" (
    set remint_opts=!remint_opts! -e %2
    shift
    shift
    goto :loop
  )
  if "%1"=="--end" (
    set remint_opts=!remint_opts! -e %2
    shift
    shift
    goto :loop
  )
  set args=!args! %1
  shift
  goto :loop
)

for %%d in (!args!) do (
  echo %%d

  set remint_outputs=
  pushd %%d
  for /d /r %%i in (coin_log_*) do (
    echo %%i

    pushd %%i
    ruby %REMINT_HOME%\remint.rb !remint_opts! -o coin_stat -c MPSTAT,MEMINFO,IOSTAT,IPROUTE,NETSTAT,MEMORY_DYNAMIC_COMPONENTS,SYSTEM_EVENT,OSSTAT,SGASTAT,SYSSTAT,KSMSS %%i\osstat\osstat* %%i\dbstat\dbstat*

    set remint_outputs=!remint_outputs! %%i\coin_stat.xlsx
    popd
  )

  ruby %REMINT_HOME%remint.rb --compare -o %%~nd.xlsx -c MPSTAT,MEMINFO,IOSTAT,IPROUTE,NETSTAT,MEMORY_DYNAMIC_COMPONENTS,SYSTEM_EVENT,OSSTAT,SGASTAT,SYSSTAT,KSMSS !remint_outputs!
  popd
)

endlocal
