## EntraID-Risk-Management-Tool

A comprehensive script for analyzing risky sign-ins and managing conditional access policies in Microsoft Entra ID.

### Features

- Analyzes risky sign-ins and their sources
- Identifies high-risk users requiring MFA or remediation
- Provides insights into Conditional Access policies
- Automates response actions for compromised accounts
- Generates detailed HTML reports

### Prerequisites

- PowerShell 5.1 or higher
- Microsoft Graph PowerShell SDK
- Appropriate Microsoft Entra ID permissions:
  - AuditLog.Read.All
  - Directory.Read.All
  - User.ReadWrite.All

### Installation

The script will automatically install required modules if they're not present:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Usage

1. Run the script:
```powershell
.\EntraID-Risk-Management-Tool.ps1
```

2. Authenticate when prompted with an account that has the required permissions
3. Review the generated HTML report that opens automatically

### Output

- Console output showing progress and detected risks
- HTML report with detailed analysis of:
  - Risky sign-ins
  - Conditional Access policies
  - High-risk users
  - Remediation actions taken

### Notes

- The script automatically disables accounts detected as high-risk
- Reports are generated in the same directory as the script
- Default analysis period is 7 days
