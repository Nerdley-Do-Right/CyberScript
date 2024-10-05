# Path to the text file with authorized users
$authorizedUsersFile = "C:\path\to\authorized_users.txt"

# Read the authorized users from the file
$authorizedUsers = Get-Content -Path $authorizedUsersFile

# Get the current logged-in user
$currentLoggedInUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]

# Get a list of all local users
$allUsers = Get-LocalUser

foreach ($user in $allUsers) {
    if (-not ($authorizedUsers -contains $user.Name) -and $user.Name -ne $currentLoggedInUser) {
        # Remove unauthorized users
        Remove-LocalUser -Name $user.Name
        Write-Output "Removed user: $user.Name"
    }
}

# Check if winget is installed, if not, install it
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -Uri "https://aka.ms/get-winget" -OutFile "winget.msixbundle"
    Add-AppxPackage winget.msixbundle
}

# Update all apps with winget
winget upgrade --all

# Run a full scan with Windows Defender
Start-MpScan -ScanType FullScan

# Update Windows
Install-WindowsUpdate -AcceptAll -IgnoreReboot

#TODO: Check and update Group Policies

# Ensure all users have a password
Get-LocalUser | Where-Object { $_.PasswordRequired -eq $false -and $_.Name -ne $currentLoggedInUser } | ForEach-Object {
    Set-LocalUser -Name $_.Name -PasswordNeverExpires $false -Password (Read-Host -AsSecureString "Enter new password for $($_.Name)")
    Write-Output "Password set for user: $($_.Name)"
}

# Ensure no user has 'password never expires' set
Get-LocalUser | Where-Object { $_.PasswordNeverExpires -eq $true -and $_.Name -ne $currentLoggedInUser } | ForEach-Object {
    Set-LocalUser -Name $_.Name -PasswordNeverExpires $false
    Write-Output "Updated password settings for user: $($_.Name)"
}

# Ensure all necessary Group Policies are enforced
Invoke-Expression "gpupdate /force"
