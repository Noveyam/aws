@echo off
REM =============================================================================
REM Resume Website Infrastructure Deployment Script (Windows)
REM Deploys AWS infrastructure using Terraform with validation and error handling
REM =============================================================================

setlocal enabledelayedexpansion

REM Script configuration
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "TERRAFORM_DIR=%PROJECT_ROOT%\terraform"
set "LOG_FILE=%PROJECT_ROOT%\deployment.log"

REM Initialize log file
echo === Resume Website Infrastructure Deployment === > "%LOG_FILE%"
echo Started at: %date% %time% >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo Starting infrastructure deployment...
echo Log file: %LOG_FILE%

REM Check prerequisites
echo Checking prerequisites...

REM Check if Terraform is installed
terraform version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Terraform is not installed. Please install Terraform ^>= 1.0
    exit /b 1
)

REM Check if AWS CLI is installed
aws --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: AWS CLI is not installed. Please install AWS CLI
    exit /b 1
)

REM Check AWS credentials
aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo ERROR: AWS credentials not configured. Please run 'aws configure'
    exit /b 1
)

echo ✓ Prerequisites check completed

REM Change to Terraform directory
cd /d "%TERRAFORM_DIR%"

REM Validate Terraform configuration
echo Validating Terraform configuration...
terraform validate
if errorlevel 1 (
    echo ERROR: Terraform configuration validation failed
    exit /b 1
)
echo ✓ Terraform configuration is valid

REM Initialize Terraform
echo Initializing Terraform...
terraform init -upgrade
if errorlevel 1 (
    echo ERROR: Terraform initialization failed
    exit /b 1
)
echo ✓ Terraform initialized successfully

REM Handle command line arguments
set "ACTION=%1"
if "%ACTION%"=="" set "ACTION=deploy"

if "%ACTION%"=="plan" goto PLAN
if "%ACTION%"=="destroy" goto DESTROY
if "%ACTION%"=="output" goto OUTPUT
if "%ACTION%"=="deploy" goto DEPLOY

echo Usage: %0 [deploy^|plan^|destroy^|output]
echo.
echo Commands:
echo   deploy   - Deploy the infrastructure (default)
echo   plan     - Show what would be deployed
echo   destroy  - Destroy all infrastructure
echo   output   - Show deployment outputs
exit /b 1

:PLAN
echo Creating Terraform execution plan...
terraform plan -out=tfplan
if errorlevel 1 (
    echo ERROR: Terraform plan failed
    exit /b 1
)
echo ✓ Terraform plan created successfully
echo Plan completed. Run with 'deploy' to apply changes.
goto END

:DEPLOY
echo Creating Terraform execution plan...
terraform plan -out=tfplan
if errorlevel 1 (
    echo ERROR: Terraform plan failed
    exit /b 1
)
echo ✓ Terraform plan created successfully

echo.
set /p CONFIRM="Do you want to apply these changes? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo Deployment cancelled by user
    del tfplan 2>nul
    goto END
)

echo Applying Terraform configuration...
terraform apply tfplan
if errorlevel 1 (
    echo ERROR: Terraform apply failed
    exit /b 1
)
del tfplan 2>nul
echo ✓ Infrastructure deployed successfully

echo Retrieving deployment outputs...
terraform output -json > "%PROJECT_ROOT%\terraform-outputs.json"

echo.
echo === Deployment Summary ===
terraform output
echo.
echo ✓ Outputs retrieved successfully

echo.
echo 🎉 Infrastructure deployment completed successfully!
echo Next steps:
echo   1. Update your domain's name servers with the Route53 name servers shown above
echo   2. Wait for DNS propagation (up to 24 hours)
echo   3. Run 'scripts\deploy-website.bat' to upload your website content
goto END

:DESTROY
echo.
echo ⚠️  WARNING: This will destroy all infrastructure resources!
set /p CONFIRM="Are you sure you want to destroy the infrastructure? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo Destroy cancelled by user
    goto END
)

terraform destroy
if errorlevel 1 (
    echo ERROR: Terraform destroy failed
    exit /b 1
)
echo ✓ Infrastructure destroyed successfully
goto END

:OUTPUT
echo Retrieving deployment outputs...
terraform output -json > "%PROJECT_ROOT%\terraform-outputs.json"
terraform output
echo ✓ Outputs retrieved successfully
goto END

:END
echo.
echo Completed at: %date% %time% >> "%LOG_FILE%"
echo ✓ Script completed successfully

endlocal