# generate_catalog.ps1
# Script to generate a comprehensive, deduplicated, and collapsible README.md for the Skills Library.

$ErrorActionPreference = "Stop"

$rootPath = "workshop"
$outputFile = "README.md"

Write-Host "Scanning $rootPath for SKILL.md files..."

# Get all SKILL.md files
$skillFiles = Get-ChildItem -Path $rootPath -Filter "SKILL.md" -Recurse

$collections = [ordered]@{}

foreach ($file in $skillFiles) {
    # Determine the collection name (first directory under 'workshop')
    $relativePath = $file.FullName.Replace((Get-Item .).FullName + "\", "").Replace("\", "/")
    $parts = $relativePath.Split("/")
    if ($parts.Count -lt 2) { continue }
    $collectionName = $parts[1]

    if (-not $collections.Contains($collectionName)) {
        $collections[$collectionName] = @()
    }

    # Extract metadata
    $content = Get-Content $file.FullName -Raw
    
    $name = ""
    $description = ""

    # Try to match YAML frontmatter
    # Regex Explanation: Matches 'name: "Title"' or 'name: Title'
    if ($content -match '(?sm)^---\s*(.*?)\s*---') {
        $yamlContent = $Matches[1]
        if ($yamlContent -match 'name:\s*(?:"(.*?)"|''(.*?)''|(.*?))\r?\n') {
            $name = ($Matches[1], $Matches[2], $Matches[3] | Where-Object { $_ }) -join ""
        }
        if ($yamlContent -match 'description:\s*(?:"(.*?)"|''(.*?)''|([^#\r\n]*))') {
            $description = ($Matches[1], $Matches[2], $Matches[3] | Where-Object { $_ }) -join ""
        }
    }

    # Fallbacks
    if (-not $name) {
        # Try first # Header
        if ($content -match '(?m)^#\s*(.*?)\r?\n') {
            $name = $Matches[1].Trim()
        } else {
            # Use directory name
            $name = $file.Directory.Name
        }
    }

    if (-not $description) {
        # Find the first paragraph after the title or frontmatter
        $lines = $content.Split("`n")
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -and -not ($trimmed.StartsWith("#")) -and -not ($trimmed.StartsWith("---"))) {
                $description = $trimmed
                break
            }
        }
    }

    # Clean up name/description
    $name = $name.Replace("|", "\|").Trim()
    $description = $description.Replace("|", "\|").Replace("`r", "").Replace("`n", " ").Trim()

    $collections[$collectionName] += [PSCustomObject]@{
        Name        = $name
        Description = $description
        Path        = $relativePath
    }
}

# Generate README.md
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Multi-Agent Skills Library")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("A comprehensive, deduplicated collection of agentic skills, tools, and workflows for Claude Code and Antigravity.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Table of Contents")
[void]$sb.AppendLine("")

$sortedCollectionNames = $collections.Keys | Sort-Object

foreach ($cn in $sortedCollectionNames) {
    # Deduplicate within collection (by Name + Description)
    $uniqueSkills = $collections[$cn] | Group-Object -Property Name, Description
    [void]$sb.AppendLine("- [$cn](#$($cn.ToLower().Replace(" ","-"))) ($($uniqueSkills.Count) skills)")
}

[void]$sb.AppendLine("")

foreach ($cn in $sortedCollectionNames) {
    [void]$sb.AppendLine("## $cn")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("<details>")
    [void]$sb.AppendLine("<summary>Click to expand $cn catalog</summary>")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Skill Name | Description | Paths |")
    [void]$sb.AppendLine("| :--- | :--- | :--- |")

    # Deduplicate and sort skills
    $groupedSkills = $collections[$cn] | Group-Object -Property Name, Description | Sort-Object { $_.Group[0].Name }

    foreach ($group in $groupedSkills) {
        $skill = $group.Group[0]
        # Join all paths as markdown links, separated by <br> or listed
        $paths = $group.Group | ForEach-Object { "[$($_.Path)]($($_.Path))" }
        $pathsStr = $paths -join "<br>"
        
        [void]$sb.AppendLine("| **$($skill.Name)** | $($skill.Description) | $pathsStr |")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("</details>")
    [void]$sb.AppendLine("")
}

Write-Host "Writing to $outputFile..."
[System.IO.File]::WriteAllText($outputFile, $sb.ToString(), [System.Text.Encoding]::UTF8)

Write-Host "Done!"
