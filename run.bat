@echo off
:: Blauplug Trading Platform — One-Click Runner
:: This file bypasses PowerShell execution policies to run the local setup.

pushd %~dp0
powershell -ExecutionPolicy Bypass -File .\run_local.ps1
pause
