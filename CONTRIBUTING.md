# Contributing to Docker WSL VHDX Cleanup Toolkit

Thank you for your interest in contributing! This project aims to help developers manage Docker Desktop disk usage on Windows.

## How to Contribute

### Reporting Issues

Before creating an issue, please:

1. Check existing issues to avoid duplicates
2. Use the issue templates provided
3. Include your environment details:
   - Windows version (`winver`)
   - WSL version (`wsl --version`)
   - Docker Desktop version
   - PowerShell version (`$PSVersionTable.PSVersion`)

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test your changes on Windows with WSL2 and Docker Desktop
5. Commit with clear messages: `git commit -m "Add feature: description"`
6. Push to your fork: `git push origin feature/your-feature-name`
7. Open a Pull Request

### Code Style

#### PowerShell Scripts

- Use `PascalCase` for function names
- Use `$camelCase` for variables
- Include comment-based help for all functions
- Follow [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) recommendations
- Test on both PowerShell 5.1 and PowerShell 7+

Example:

```powershell
<#
.SYNOPSIS
    Brief description of the function.

.DESCRIPTION
    Detailed description.

.PARAMETER ParamName
    Parameter description.

.EXAMPLE
    Example-Function -ParamName "value"
#>
function Example-Function {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ParamName
    )
    
    # Implementation
}
```

#### Documentation

- Use clear, concise language
- Include code examples where helpful
- Keep the README focused on quick-start usage
- Put detailed information in `/docs`

### Testing

Before submitting:

1. Run the validation script: `.\scripts\validate-wsl-state.ps1`
2. Test the shrink script on a non-production environment
3. Verify no sensitive data is included in commits

### Areas for Contribution

We welcome contributions in these areas:

- **Bug fixes** for edge cases on different Windows versions
- **Documentation** improvements and translations
- **New features** that help with Docker/WSL disk management
- **Testing** on different Windows builds and configurations
- **CI/CD** improvements for automated testing

### Questions?

Feel free to open a discussion or reach out through issues.

---

Thank you for helping improve this toolkit!

