---
title: "Intune ACSC hardening with secedit"
date: 2023-02-28
draft: false
tags: ["intune", "windows"]
---

The [ACSC Windows Hardening guide](https://www.cyber.gov.au/acsc/view-all-content/publications/hardening-microsoft-windows-10-version-21h1-workstations) is widely used in Australian organisations, particularly government entities. However, it was originally written for Active Directory Group Policy, and some settings don't convert well to other management solutions like Microsoft Intune. So I built a set of Intune policies and scripts to speed up implementation. Recently Michael Dineen from Microsoft had a similar idea, and publicly released a [set of policies](https://github.com/microsoft/Intune-ACSC-Windows-Hardening-Guidelines/) on GitHub.

These policies are fantastic for anyone looking to implement ACSC best practices with Intune, but they don't cover some tricky edge cases like certain [local security policies](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/security-policy-settings). After a bit of digging, it turns out the built-in [`secedit`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/secedit) tool does exactly what I need. A Proactive Remediation with these PowerShell scripts worked out nicely.

### Security-ACSC_Hardening-secedit-Detect.ps1

```PowerShell
# Force audit policy subcategory settings to override audit policy category settings: Enabled
$SCENoApplyLegacyAuditPolicy = Get-ItemPropertyValue -Path HKLM:\System\CurrentControlSet\Control\Lsa -Name SCENoApplyLegacyAuditPolicy
# Amount of idle time required before suspending session: 15 minutes
$autodisconnect = Get-ItemPropertyValue -Path HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters -Name autodisconnect
# Allow LocalSystem NULL session fallback: Disabled
$allownullsessionfallback = Get-ItemPropertyValue -Path HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0 -Name allownullsessionfallback
# Force strong key protection for user keys stored on the computer: User must enter a password each time they use a key
$ForceKeyProtection = Get-ItemPropertyValue -Path HKLM:\Software\Policies\Microsoft\Cryptography -Name ForceKeyProtection

if ($SCENoApplyLegacyAuditPolicy -eq 1 -and $autodisconnect -eq 15 -and $allownullsessionfallback -eq 0 -and $ForceKeyProtection -eq 2) {
  secedit /export /cfg secedit.cfg
  $secedit = Get-Content secedit.cfg
  $settings = @(
    "LockoutDuration = -1", # Account lockout duration: 0 (until admin unlocks)
    "LockoutBadCount = 5", # Account lockout threshold: 5
    "ResetLockoutCount = 15", # Reset account lockout counter after: 15 minutes
    "SeServiceLogonRight = ", # Allow log on through Remote Desktop Services: <blank>
    "RequireSignOrSeal=4,1", # Digitally encrypt or sign secure channel data: Enabled
    "SealSecureChannel=4,1", # Digitally encrypt secure channel data: Enabled
    "SignSecureChannel=4,1", # Digitally sign secure channel data: Enabled
    "DisablePasswordChange=4,0", # Disable machine account password changes: Disabled
    "Parameters\\MaximumPasswordAge=4,30", # Maximum machine account password age: 30 days
    "RequireStrongKey=4,1", # Require strong (Windows 2000 or later) session key: Enabled
    'CachedLogonsCount=1,"1"', # Number of previous logons to cache: 1
    "LSAAnonymousNameLookup = 0", # Allow anonymous SID/Name translation: Disabled
    "DisableDomainCreds=4,1", # Do not allow storage of passwords and credentials for network authentication: Enabled
    "EveryoneIncludesAnonymous=4,0", # Let Everyone permissions apply to anonymous users: Disabled
    "ForceLogoffWhenHourExpire = 1", # Force logoff when logon hours expire: Enabled
    "ObCaseInsensitive=4,1", # Require case insensitivity for non-Windows subsystems: Enabled
    "ProtectionMode=4,1" # Strengthen default permissions of internal system objects: Enabled
    # FIPS app configuration overhead is too high
    # "FIPSAlgorithmPolicy\Enabled=4,1", # Use FIPS compliant algorithms for encryption, hashing, and signing: Enabled
  )

  if ($settings | where { $secedit -like "*$_*" }) {
    exit 0
  }
}

exit 1
```

### Security-ACSC_Hardening-secedit-Remediate.ps1

```PowerShell
# Force audit policy subcategory settings to override audit policy category settings: Enabled
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\Lsa -Name SCENoApplyLegacyAuditPolicy -Value 1 -Type DWord
# Amount of idle time required before suspending session: 15 minutes
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters -Name autodisconnect -Value 15 -Type DWord
# Allow LocalSystem NULL session fallback: Disabled
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0 -Name allownullsessionfallback -Value 0 -Type DWord
# Force strong key protection for user keys stored on the computer: User must enter a password each time they use a key
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Cryptography -Name ForceKeyProtection -Value 2 -Type DWord

secedit /export /cfg secedit.cfg
$secedit = Get-Content secedit.cfg
$secedit = $secedit -replace "LockoutDuration.*", "LockoutDuration = -1" <# Account lockout duration: 0 (until admin unlocks) #> `
-replace "LockoutBadCount.*", "LockoutBadCount = 5" <# Account lockout threshold: 5 #> `
-replace "ResetLockoutCount.*", "ResetLockoutCount = 15" <# Reset account lockout counter after: 15 minutes #> `
-replace "SeServiceLogonRight.*", "SeServiceLogonRight = " <# Allow log on through Remote Desktop Services: <blank> #> `
-replace "RequireSignOrSeal.*", "RequireSignOrSeal=4,1" <# Digitally encrypt or sign secure channel data: Enabled #> `
-replace "SealSecureChannel.*", "SealSecureChannel=4,1" <# Digitally encrypt secure channel data: Enabled #> `
-replace "SignSecureChannel.*", "SignSecureChannel=4,1" <# Digitally sign secure channel data: Enabled #> `
-replace "DisablePasswordChange.*", "DisablePasswordChange=4,0" <# Disable machine account password changes: Disabled #> `
-replace "Parameters\\MaximumPasswordAge.*", "Parameters\\MaximumPasswordAge=4,30" <# Maximum machine account password age: 30 days #> `
-replace "RequireStrongKey.*", "RequireStrongKey=4,1" <# Require strong (Windows 2000 or later) session key: Enabled #> `
-replace "CachedLogonsCount.*", 'CachedLogonsCount=1,"1"' <# Number of previous logons to cache: 1 #> `
-replace "LSAAnonymousNameLookup.*", "LSAAnonymousNameLookup = 0" <# Allow anonymous SID/Name translation: Disabled #> `
-replace "DisableDomainCreds.*", "DisableDomainCreds=4,1" <# Do not allow storage of passwords and credentials for network authentication: Enabled #> `
-replace "EveryoneIncludesAnonymous.*", "EveryoneIncludesAnonymous=4,0" <# Let Everyone permissions apply to anonymous users: Disabled #> `
-replace "ForceLogoffWhenHourExpire.*", "ForceLogoffWhenHourExpire = 1" <# Force logoff when logon hours expire: Enabled #> `
-replace "ObCaseInsensitive.*", "ObCaseInsensitive=4,1" <# Require case insensitivity for non-Windows subsystems: Enabled #> `
-replace "ProtectionMode.*", "ProtectionMode=4,1" <# Strengthen default permissions of internal system objects: Enabled #>
# FIPS app configuration overhead is too high
# -replace "FIPSAlgorithmPolicy\\Enabled.*", "FIPSAlgorithmPolicy\\Enabled=4,1" <# Use FIPS compliant algorithms for encryption, hashing, and signing: Enabled #> `

$secedit | Out-File seceditnew.cfg
secedit /import /db seceditnew.db /cfg seceditnew.cfg
secedit /configure /db seceditnew.db
gpupdate /force
```