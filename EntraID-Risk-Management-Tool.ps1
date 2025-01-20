# Requires -Modules Microsoft.Graph

<#
.SCRIPT NAME
    Interactive Entra ID Application Management Script

.SYNOPSIS
    PowerShell script to manage enterprise applications and app registrations in Entra ID (Azure AD).

.DESCRIPTION
    This interactive script provides functionality to:
    1. List and search enterprise applications
    2. Register new applications
    3. Manage application permissions and consent
    4. Configure authentication settings
    5. Monitor application usage and sign-ins
    6. Manage app secrets and certificates
    7. Configure app roles and assignments

.AUTHOR
    Mezba Uddin

.VERSION
    1.1

.LASTUPDATED
    2024-12-29

.NOTES
    - Requires the Microsoft.Graph module
    - Required permissions:
        * Application.ReadWrite.All
        * Directory.Read.All
        * AppRoleAssignment.ReadWrite.All
#>

# Function to ensure proper Microsoft Graph connection
function Connect-EntraGraph {
    try {
        $context = Get-MgContext
        if (-not $context) {
            Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.Read.All", "AppRoleAssignment.ReadWrite.All"
            $context = Get-MgContext
        }
        return $true
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to write error logs
function Write-ErrorLog {
    param (
        [string]$ErrorMessage,
        [string]$ErrorDetails
    )
    
    $logPath = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath | Out-Null
    }
    
    $logFile = Join-Path $logPath "AppManagement_Error.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $ErrorMessage - $ErrorDetails" | Add-Content $logFile
}

function Show-Banner {
    $banner = @"
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║              ENTRA ID APPLICATION MANAGEMENT                     ║
    ║                                                                  ║
    ║                      By: Mezba Uddin                            ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
"@
    Write-Host $banner -ForegroundColor Cyan
}

function Show-MainMenu {
    Write-Host "`nMain Menu" -ForegroundColor Green
    Write-Host "=========" -ForegroundColor Green
    Write-Host "1. List/Search Applications" -ForegroundColor Yellow
    Write-Host "2. Register New Application" -ForegroundColor Yellow
    Write-Host "3. Manage Application Permissions" -ForegroundColor Yellow
    Write-Host "4. Configure Authentication Settings" -ForegroundColor Yellow
    Write-Host "5. View Application Usage & Sign-ins" -ForegroundColor Yellow
    Write-Host "6. Manage App Secrets/Certificates" -ForegroundColor Yellow
    Write-Host "7. Configure App Roles" -ForegroundColor Yellow
    Write-Host "8. Exit" -ForegroundColor Yellow
}

function Show-AppManagementMenu {
    param (
        [Parameter(Mandatory = $true)]
        $SelectedApp
    )
    
    do {
        Clear-Host
        Write-Host "`nManaging Application: $($SelectedApp.DisplayName)" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "1. View App Details" -ForegroundColor Yellow
        Write-Host "2. Update App Settings" -ForegroundColor Yellow
        Write-Host "3. Manage API Permissions" -ForegroundColor Yellow
        Write-Host "4. Manage Authentication Settings" -ForegroundColor Yellow
        Write-Host "5. Manage App Secrets/Certificates" -ForegroundColor Yellow
        Write-Host "6. View Sign-in Logs" -ForegroundColor Yellow
        Write-Host "7. Delete Application" -ForegroundColor Red
        Write-Host "8. Back to Main Menu" -ForegroundColor Yellow
        
        $choice = Read-Host "`nEnter your choice (1-8)"
        
        switch ($choice) {
            "1" { 
                Write-Host "`nApplication Details:" -ForegroundColor Cyan
                Write-Host "===================" -ForegroundColor Cyan
                Write-Host "Display Name: $($SelectedApp.DisplayName)"
                Write-Host "Application ID: $($SelectedApp.AppId)"
                Write-Host "Object ID: $($SelectedApp.Id)"
                Write-Host "Sign-in Audience: $($SelectedApp.SignInAudience)"
                Write-Host "Created: $($SelectedApp.CreatedDateTime)"
                if ($SelectedApp.Web) {
                    Write-Host "`nRedirect URIs:" -ForegroundColor Cyan
                    $SelectedApp.Web.RedirectUris | ForEach-Object { Write-Host "- $_" }
                }
                Read-Host "`nPress Enter to continue"
            }
            "2" {
                Write-Host "`nUpdate App Settings" -ForegroundColor Cyan
                Write-Host "1. Update Display Name" -ForegroundColor Yellow
                Write-Host "2. Update Sign-in Audience" -ForegroundColor Yellow
                Write-Host "3. Back" -ForegroundColor Yellow
                
                $updateChoice = Read-Host "`nEnter your choice (1-3)"
                switch ($updateChoice) {
                    "1" {
                        $newName = Read-Host "Enter new display name"
                        try {
                            Update-MgApplication -ApplicationId $SelectedApp.Id -DisplayName $newName
                            Write-Host "Display name updated successfully!" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error updating display name: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                    "2" {
                        $newAudience = Read-Host "Enter new sign-in audience (AzureADMyOrg/AzureADMultipleOrgs/AzureADandPersonalMicrosoftAccount)"
                        try {
                            Update-MgApplication -ApplicationId $SelectedApp.Id -SignInAudience $newAudience
                            Write-Host "Sign-in audience updated successfully!" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error updating sign-in audience: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
            "3" {
                Write-Host "`nCurrent API Permissions:" -ForegroundColor Cyan
                try {
                    $permissions = Get-MgApplicationPermission -ApplicationId $SelectedApp.Id
                    if ($permissions) {
                        $permissions | Format-Table -Property ResourceAppId, ResourceAccess
                    }
                    else {
                        Write-Host "No API permissions found." -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "Error retrieving permissions: $($_.Exception.Message)" -ForegroundColor Red
                }
                Read-Host "`nPress Enter to continue"
            }
            "4" {
                Write-Host "`nAuthentication Settings" -ForegroundColor Cyan
                Write-Host "1. Add Redirect URI" -ForegroundColor Yellow
                Write-Host "2. Remove Redirect URI" -ForegroundColor Yellow
                Write-Host "3. Back" -ForegroundColor Yellow
                
                $authChoice = Read-Host "`nEnter your choice (1-3)"
                switch ($authChoice) {
                    "1" {
                        $newUri = Read-Host "Enter new redirect URI"
                        try {
                            $currentUris = @()
                            if ($SelectedApp.Web.RedirectUris) {
                                $currentUris = $SelectedApp.Web.RedirectUris
                            }
                            $currentUris += $newUri
                            Update-MgApplication -ApplicationId $SelectedApp.Id -Web @{
                                RedirectUris = $currentUris
                            }
                            Write-Host "Redirect URI added successfully!" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error adding redirect URI: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
            "5" {
                Write-Host "`nApp Secrets/Certificates" -ForegroundColor Cyan
                Write-Host "1. Add New Secret" -ForegroundColor Yellow
                Write-Host "2. View Existing Secrets" -ForegroundColor Yellow
                Write-Host "3. Back" -ForegroundColor Yellow
                
                $secretChoice = Read-Host "`nEnter your choice (1-3)"
                switch ($secretChoice) {
                    "1" {
                        try {
                            $endDate = (Get-Date).AddYears(1)
                            $secret = Add-MgApplicationPassword -ApplicationId $SelectedApp.Id -PasswordCredential @{
                                DisplayName = "Generated by Script"
                                EndDateTime = $endDate
                            }
                            Write-Host "`nNew secret created successfully!" -ForegroundColor Green
                            Write-Host "Secret Value: $($secret.SecretText)" -ForegroundColor Yellow
                            Write-Host "IMPORTANT: Copy this value now. You won't be able to see it again!" -ForegroundColor Red
                            Read-Host "`nPress Enter once you've copied the secret"
                        }
                        catch {
                            Write-Host "Error creating secret: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                    "2" {
                        try {
                            Write-Host "`nRetrieving application secrets..." -ForegroundColor Cyan
                            $app = Get-MgApplication -ApplicationId $SelectedApp.Id -Property "PasswordCredentials" -ErrorAction Stop
                            
                            if ($app.PasswordCredentials -and $app.PasswordCredentials.Count -gt 0) {
                                Write-Host "`nCurrent Secrets:" -ForegroundColor Green
                                $app.PasswordCredentials | ForEach-Object {
                                    Write-Host "`nSecret Details:" -ForegroundColor Yellow
                                    Write-Host "Display Name: $($_.DisplayName)"
                                    Write-Host "Key ID: $($_.KeyId)"
                                    Write-Host "Start DateTime: $($_.StartDateTime)"
                                    Write-Host "End DateTime: $($_.EndDateTime)"
                                    Write-Host "Created: $($_.CreatedDateTime)"
                                    
                                    # Check if secret is expired
                                    if ($_.EndDateTime -lt (Get-Date)) {
                                        Write-Host "Status: Expired" -ForegroundColor Red
                                    } else {
                                        Write-Host "Status: Active" -ForegroundColor Green
                                    }
                                    Write-Host "----------------------------------------"
                                }
                            } else {
                                Write-Host "`nNo secrets found for this application." -ForegroundColor Yellow
                            }
                            Read-Host "`nPress Enter to continue"
                        }
                        catch {
                            Write-Host "Error retrieving secrets: $($_.Exception.Message)" -ForegroundColor Red
                            Read-Host "`nPress Enter to continue"
                        }
                    }
                    "3" {
                        # Just return to previous menu
                        return
                    }
                    default {
                        Write-Host "Invalid choice. Please select 1, 2, or 3." -ForegroundColor Yellow
                        Read-Host "`nPress Enter to continue"
                    }
                }
            }
            "6" {
                Write-Host "`nViewing recent sign-in logs..." -ForegroundColor Cyan
                try {
                    $signInLogs = Get-MgAuditLogSignIn -Filter "appId eq '$($SelectedApp.AppId)'" -Top 10
                    if ($signInLogs) {
                        $signInLogs | Format-Table UserPrincipalName, CreatedDateTime, Status -AutoSize
                    }
                    else {
                        Write-Host "No recent sign-in logs found." -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "Error retrieving sign-in logs: $($_.Exception.Message)" -ForegroundColor Red
                }
                Read-Host "`nPress Enter to continue"
            }
            "7" {
                Write-Host "`nWARNING: This will permanently delete the application!" -ForegroundColor Red
                $confirm = Read-Host "Type 'YES' to confirm deletion"
                if ($confirm -eq 'YES') {
                    try {
                        Remove-MgApplication -ApplicationId $SelectedApp.Id
                        Write-Host "Application deleted successfully!" -ForegroundColor Green
                        return
                    }
                    catch {
                        Write-Host "Error deleting application: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            "8" { return }
        }
    } while ($true)
}

function Find-Application {
    try {
        Write-Host "`nSearch Applications" -ForegroundColor Green
        Write-Host "==================" -ForegroundColor Green
        $searchTerm = Read-Host "Enter application name to search (press Enter to show all)"
        
        # Get all applications
        $allApps = Get-MgApplication -ErrorAction Stop
        
        # If search term is empty, use all apps, otherwise filter
        $apps = if ([string]::IsNullOrWhiteSpace($searchTerm)) {
            $allApps
        } else {
            $allApps | Where-Object { $_.DisplayName -like "*$searchTerm*" }
        }
        
        if (-not $apps -or @($apps).Count -eq 0) {
            Write-Host "No applications found." -ForegroundColor Yellow
            return $null
        }
        
        Write-Host "`nFound Applications:" -ForegroundColor Cyan
        $index = 1
        $appList = @($apps) | Sort-Object DisplayName
        $appList | ForEach-Object {
            Write-Host "$index. $($_.DisplayName) (AppId: $($_.AppId))"
            $index++
        }
        
        $selection = Read-Host "`nSelect application number (1-$($appList.Count))"
        if ([int]$selection -ge 1 -and [int]$selection -le $appList.Count) {
            $selectedApp = $appList[$selection - 1]
            Show-AppManagementMenu -SelectedApp $selectedApp
            return $selectedApp
        }
        
        Write-Host "Invalid selection." -ForegroundColor Yellow
        return $null
    }
    catch {
        Write-Host "Error searching applications: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog -ErrorMessage "Failed to search applications" -ErrorDetails $_.Exception.Message
        return $null
    }
}

function Register-NewApplication {
    try {
        Write-Host "`nRegister New Application" -ForegroundColor Green
        Write-Host "======================" -ForegroundColor Green
        
        # Get display name with validation
        do {
            $displayName = Read-Host "Enter application name (minimum 3 characters)"
            if ([string]::IsNullOrWhiteSpace($displayName) -or $displayName.Length -lt 3) {
                Write-Host "Application name must be at least 3 characters long." -ForegroundColor Yellow
            }
        } while ([string]::IsNullOrWhiteSpace($displayName) -or $displayName.Length -lt 3)

        # Sign-in audience selection with menu
        Write-Host "`nSelect sign-in audience:" -ForegroundColor Cyan
        Write-Host "1. Single tenant (AzureADMyOrg) - For use in my organization only" -ForegroundColor Yellow
        Write-Host "2. Multiple tenants (AzureADMultipleOrgs) - For use in any Azure AD tenant" -ForegroundColor Yellow
        Write-Host "3. Azure AD and personal accounts (AzureADandPersonalMicrosoftAccount) - For use by any user" -ForegroundColor Yellow
        
        do {
            $audienceChoice = Read-Host "`nEnter your choice (1-3)"
            $signInAudience = switch ($audienceChoice) {
                "1" { "AzureADMyOrg" }
                "2" { "AzureADMultipleOrgs" }
                "3" { "AzureADandPersonalMicrosoftAccount" }
                default { $null }
            }
            
            if (-not $signInAudience) {
                Write-Host "Invalid choice. Please select 1, 2, or 3." -ForegroundColor Yellow
            }
        } while (-not $signInAudience)

        # Web platform configuration
        Write-Host "`nDo you want to configure web platform settings? (Y/N)" -ForegroundColor Cyan
        $configureWeb = Read-Host
        
        $params = @{
            DisplayName = $displayName
            SignInAudience = $signInAudience
        }
        
        if ($configureWeb -eq 'Y') {
            do {
                $webRedirectUri = Read-Host "`nEnter web redirect URI (e.g., https://localhost:44321)"
                if ([string]::IsNullOrWhiteSpace($webRedirectUri)) {
                    Write-Host "Skipping web platform configuration." -ForegroundColor Yellow
                    break
                }
                elseif (-not ($webRedirectUri -match '^https?://.*')) {
                    Write-Host "Invalid URI format. URI must start with http:// or https://" -ForegroundColor Yellow
                    continue
                }
                $params.Web = @{
                    RedirectUris = @($webRedirectUri)
                }
                break
            } while ($true)
        }

        Write-Host "`nCreating application..." -ForegroundColor Cyan
        $newApp = New-MgApplication @params
        
        Write-Host "`nApplication created successfully!" -ForegroundColor Green
        Write-Host "`nApplication Details:" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Cyan
        Write-Host "Display Name: $($newApp.DisplayName)"
        Write-Host "Application (Client) ID: $($newApp.AppId)"
        Write-Host "Object ID: $($newApp.Id)"
        Write-Host "Sign-in Audience: $($newApp.SignInAudience)"
        if ($newApp.Web.RedirectUris) {
            Write-Host "`nConfigured Redirect URIs:" -ForegroundColor Cyan
            $newApp.Web.RedirectUris | ForEach-Object { Write-Host "- $_" }
        }
        
        Write-Host "`nDo you want to create a client secret for this application now? (Y/N)" -ForegroundColor Cyan
        $createSecret = Read-Host
        
        if ($createSecret -eq 'Y') {
            try {
                $endDate = (Get-Date).AddYears(1)
                $secret = Add-MgApplicationPassword -ApplicationId $newApp.Id -PasswordCredential @{
                    DisplayName = "Initial Secret"
                    EndDateTime = $endDate
                }
                Write-Host "`nClient secret created successfully!" -ForegroundColor Green
                Write-Host "Secret Value: $($secret.SecretText)" -ForegroundColor Yellow
                Write-Host "IMPORTANT: Copy this value now. You won't be able to see it again!" -ForegroundColor Red
                Write-Host "Expiration Date: $endDate" -ForegroundColor Cyan
            }
            catch {
                Write-Host "Error creating client secret: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Read-Host "`nPress Enter to continue"
    }
    catch {
        Write-Host "Error creating application: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog -ErrorMessage "Failed to create application" -ErrorDetails $_.Exception.Message
        Read-Host "`nPress Enter to continue"
    }
}

function Manage-AppPermissions {
    try {
        $app = Find-Application
        if (-not $app) { return }
        
        Write-Host "`nManage Permissions for $($app.DisplayName)" -ForegroundColor Green
        Write-Host "1. Add API Permission" -ForegroundColor Yellow
        Write-Host "2. Remove API Permission" -ForegroundColor Yellow
        Write-Host "3. List Current Permissions" -ForegroundColor Yellow
        Write-Host "4. Back to Main Menu" -ForegroundColor Yellow
        
        $choice = Read-Host "`nEnter your choice (1-4)"
        switch ($choice) {
            "1" { 
                # Add permission logic
                $apiName = Read-Host "Enter API name (e.g., Microsoft Graph)"
                $permissionName = Read-Host "Enter permission name"
                # Implementation for adding permissions
            }
            "2" {
                # Remove permission logic
                # Implementation for removing permissions
            }
            "3" {
                # List current permissions
                $permissions = Get-MgApplicationPermission -ApplicationId $app.Id
                Write-Host "`nCurrent Permissions:" -ForegroundColor Cyan
                $permissions | Format-Table -AutoSize
            }
        }
    }
    catch {
        Write-Host "Error managing permissions: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog -ErrorMessage "Failed to manage permissions" -ErrorDetails $_.Exception.Message
    }
}

function Configure-AuthSettings {
    try {
        $app = Find-Application
        if (-not $app) { return }
        
        Write-Host "`nConfigure Authentication for $($app.DisplayName)" -ForegroundColor Green
        Write-Host "1. Add Redirect URI" -ForegroundColor Yellow
        Write-Host "2. Configure Token Settings" -ForegroundColor Yellow
        Write-Host "3. Configure Platform Settings" -ForegroundColor Yellow
        Write-Host "4. Back to Main Menu" -ForegroundColor Yellow
        
        $choice = Read-Host "`nEnter your choice (1-4)"
        # Implementation for authentication settings
    }
    catch {
        Write-Host "Error configuring authentication: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog -ErrorMessage "Failed to configure authentication" -ErrorDetails $_.Exception.Message
    }
}

function View-AppUsage {
    try {
        $app = Find-Application
        if (-not $app) { return }
        
        Write-Host "`nViewing Usage for $($app.DisplayName)" -ForegroundColor Green
        # Implementation for viewing app usage and sign-ins
    }
    catch {
        Write-Host "Error viewing app usage: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog -ErrorMessage "Failed to view app usage" -ErrorDetails $_.Exception.Message
    }
}

function Manage-AppSecrets {
    try {
        $app = Find-Application
        if (-not $app) { return }
        
        Write-Host "`nManage Secrets/Certificates for $($app.DisplayName)" -ForegroundColor Green
        Write-Host "1. Add New Secret" -ForegroundColor Yellow
        Write-Host "2. Add Certificate" -ForegroundColor Yellow
        Write-Host "3. List Current Secrets/Certificates" -ForegroundColor Yellow
        Write-Host "4. Back to Main Menu" -ForegroundColor Yellow
        
        $choice = Read-Host "`nEnter your choice (1-4)"
        # Implementation for managing secrets and certificates
    }
    catch {
        Write-Host "Error managing secrets: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog -ErrorMessage "Failed to manage secrets" -ErrorDetails $_.Exception.Message
    }
}

function Configure-AppRoles {
    try {
        $app = Find-Application
        if (-not $app) { return }
        
        Write-Host "`nConfigure App Roles for $($app.DisplayName)" -ForegroundColor Green
        Write-Host "1. Add App Role" -ForegroundColor Yellow
        Write-Host "2. Remove App Role" -ForegroundColor Yellow
        Write-Host "3. List Current App Roles" -ForegroundColor Yellow
        Write-Host "4. Back to Main Menu" -ForegroundColor Yellow
        
        $choice = Read-Host "`nEnter your choice (1-4)"
        # Implementation for configuring app roles
    }
    catch {
        Write-Host "Error configuring app roles: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog -ErrorMessage "Failed to configure app roles" -ErrorDetails $_.Exception.Message
    }
}

# Main script execution
Clear-Host
Show-Banner

if (-not (Connect-EntraGraph)) {
    Write-Host "Unable to proceed without Microsoft Graph connection." -ForegroundColor Red
    exit
}

do {
    Show-MainMenu
    $choice = Read-Host "`nEnter your choice (1-8)"
    
    switch ($choice) {
        "1" { Find-Application }
        "2" { Register-NewApplication }
        "3" { Manage-AppPermissions }
        "4" { Configure-AuthSettings }
        "5" { View-AppUsage }
        "6" { Manage-AppSecrets }
        "7" { Configure-AppRoles }
        "8" { 
            Write-Host "`nExiting script..." -ForegroundColor Green
            exit 
        }
        default {
            Write-Host "Invalid choice. Please enter a number between 1 and 8." -ForegroundColor Yellow
        }
    }
    
    if ($choice -ne "8") {
        Write-Host "`nPress Enter to continue..."
        Read-Host
        Clear-Host
        Show-Banner
    }
} while ($true)
