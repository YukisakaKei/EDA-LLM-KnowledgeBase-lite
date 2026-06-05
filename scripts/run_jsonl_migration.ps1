param(
    [string]$SourceRoot = "D:\AI_Agent\EDA-LLM-KnowkedgeBase",
    [string]$TargetRoot = "D:\AI_Agent\EDA-LLM-KnowledgeBase-lite",
    [string]$InventoryPath = "workspace\jsonl-migration-inventory.json",
    [string[]]$Only = @(),
    [switch]$DryRun,
    [switch]$SkipValidate,
    [switch]$VerboseSlicer,
    [string]$DryRunOutputRoot = "workspace\jsonl-test\migration-dry-run",
    [string]$ReportPath = "workspace\jsonl-migration-run-report.md",
    [string]$LogPath = "workspace\jsonl-migration-run.log"
)

$ErrorActionPreference = "Stop"

function Resolve-UnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    return [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
}

function ConvertTo-NativePath {
    param([Parameter(Mandatory = $true)][string]$PathText)
    return $PathText -replace '/', [System.IO.Path]::DirectorySeparatorChar
}

function Get-TargetAlias {
    param([Parameter(Mandatory = $true)]$Entry)

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($Entry.target_jsonl)
    $aliases = @($Entry.id, $stem)

    switch ($Entry.id) {
        "innovus.legacy.dbSchema__211" { $aliases += "InnovusLegacyDbSchema" }
        "innovus.cui.DBcom__211" { $aliases += "InnovusCuiDBcom" }
        "voltus.legacy.voltusUG__211" { $aliases += "VoltusLegacyUG" }
        "innovus.legacy.optDesign_vs_timeDesign" { $aliases += "OptDesignVsTimeDesign" }
    }

    return $aliases
}

function Test-Selected {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [string[]]$OnlyList
    )

    if ($OnlyList.Count -eq 0) {
        return $true
    }

    $aliases = Get-TargetAlias $Entry
    foreach ($name in $OnlyList) {
        foreach ($alias in $aliases) {
            if ($name -ieq $alias) {
                return $true
            }
        }
    }
    return $false
}

function Get-DryRunDefaultSelection {
    return @(
        "innovus.legacy.dbSchema__211",
        "innovus.cui.DBcom__211",
        "voltus.legacy.voltusUG__211"
    )
}

function Get-OutputPath {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)][string]$TargetRootPath,
        [Parameter(Mandatory = $true)][bool]$IsDryRun,
        [Parameter(Mandatory = $true)][string]$DryRunRootPath
    )

    if (-not $IsDryRun) {
        return Resolve-UnderRoot $TargetRootPath (ConvertTo-NativePath $Entry.target_jsonl)
    }

    $relativeTarget = ConvertTo-NativePath $Entry.target_jsonl
    return Resolve-UnderRoot $TargetRootPath (Join-Path $DryRunRootPath $relativeTarget)
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string[]]$Command,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$LogFile,
        [Parameter(Mandatory = $true)][bool]$VerboseOutput
    )

    $exe = $Command[0]
    $arguments = @()
    if ($Command.Count -gt 1) {
        $arguments = $Command[1..($Command.Count - 1)]
    }

    Add-Content -LiteralPath $LogFile -Encoding UTF8 -Value ""
    Add-Content -LiteralPath $LogFile -Encoding UTF8 -Value "> $($Command -join ' ')"

    Push-Location $WorkingDirectory
    try {
        $output = & $exe @arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($output) {
        Add-Content -LiteralPath $LogFile -Encoding UTF8 -Value $output
        if ($VerboseOutput) {
            $output | ForEach-Object { Write-Host $_ }
        }
    }

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $($Command -join ' ')"
    }
}

function Get-SlicerCommand {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)][string]$SourceRootPath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $sourcePath = Resolve-UnderRoot $SourceRootPath (ConvertTo-NativePath $Entry.source.relative_path)
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Source path does not exist: $sourcePath"
    }

    $slicer = [string]$Entry.slicer.planned_jsonl_slicer
    $command = @("python", "-B", (ConvertTo-NativePath $slicer), $sourcePath, $OutputPath)

    foreach ($arg in $Entry.slicer.required_args) {
        $argText = [string]$arg
        if ($argText -like "knowledge/*") {
            $command += Resolve-UnderRoot $SourceRootPath (ConvertTo-NativePath $argText)
        } else {
            $command += $argText
        }
    }

    if ($Entry.source.type -eq "PDF") {
        foreach ($arg in $Entry.slicer.candidate_args_to_verify) {
            if ($arg -in @("--precise", "--strip-headers")) {
                $command += [string]$arg
            }
        }
    }

    return $command
}

function Get-JsonlLineCount {
    param([Parameter(Mandatory = $true)][string]$Path)

    $count = 0
    foreach ($line in [System.IO.File]::ReadLines($Path, [System.Text.Encoding]::UTF8)) {
        $count++
    }
    return $count
}

function Get-JsonFileCount {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return (Get-ChildItem -LiteralPath $Path -Filter "chapter_*.json" -File).Count
}

function New-ReportLines {
    param(
        [Parameter(Mandatory = $true)][array]$Results,
        [Parameter(Mandatory = $true)][bool]$IsDryRun,
        [Parameter(Mandatory = $true)][string]$SourceRootPath,
        [Parameter(Mandatory = $true)][string]$TargetRootPath
    )

    $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
    $mode = if ($IsDryRun) { "DryRun" } else { "Full" }
    $lines = @(
        "# JSONL Migration Run Report",
        "",
        "- Generated at: $generatedAt",
        "- Mode: $mode",
        "- SourceRoot: ``$SourceRootPath``",
        "- TargetRoot: ``$TargetRootPath``",
        "- Generated targets: $($Results.Count)",
        "",
        "| ID | Output | Lines | Expected | Legacy JSON | Validate | Notes |",
        "|---|---|---:|---:|---:|---|---|"
    )

    foreach ($result in $Results) {
        $validateText = if ($result.ValidateExitCode -eq $null) { "skipped" } elseif ($result.ValidateExitCode -eq 0) { "pass" } else { "fail:$($result.ValidateExitCode)" }
        $notes = if ($result.LineCount -eq $result.ExpectedLineCount) { "" } else { "line count mismatch" }
        if ($result.LegacyJsonCount -ne $null -and $result.LegacyJsonCount -ne $result.LineCount) {
            if ($notes) {
                $notes += "; "
            }
            $notes += "legacy/json count differs"
        }

        $outputRel = $result.OutputPath
        try {
            $outputRel = [System.IO.Path]::GetRelativePath($TargetRootPath, $result.OutputPath)
        } catch {
            $outputRel = $result.OutputPath
        }

        $lines += "| $($result.Id) | ``$outputRel`` | $($result.LineCount) | $($result.ExpectedLineCount) | $($result.LegacyJsonCount) | $validateText | $notes |"
    }

    return $lines
}

$sourceRootFull = [System.IO.Path]::GetFullPath($SourceRoot)
$targetRootFull = [System.IO.Path]::GetFullPath($TargetRoot)
$inventoryFull = Resolve-UnderRoot $targetRootFull (ConvertTo-NativePath $InventoryPath)
$reportFull = Resolve-UnderRoot $targetRootFull (ConvertTo-NativePath $ReportPath)
$logFull = Resolve-UnderRoot $targetRootFull (ConvertTo-NativePath $LogPath)

if (-not (Test-Path -LiteralPath $sourceRootFull)) {
    throw "SourceRoot does not exist: $sourceRootFull"
}
if (-not (Test-Path -LiteralPath $targetRootFull)) {
    throw "TargetRoot does not exist: $targetRootFull"
}
if (-not (Test-Path -LiteralPath $inventoryFull)) {
    throw "InventoryPath does not exist: $inventoryFull"
}

$inventory = Get-Content -LiteralPath $inventoryFull -Encoding UTF8 -Raw | ConvertFrom-Json
$includedEntries = @($inventory.entries | Where-Object { $_.status -eq "included" })

$Only = @(
    foreach ($item in $Only) {
        foreach ($name in ([string]$item -split ",")) {
            $trimmed = $name.Trim()
            if ($trimmed) {
                $trimmed
            }
        }
    }
)

if ($DryRun -and $Only.Count -eq 0) {
    $Only = Get-DryRunDefaultSelection
}

$selectedEntries = @($includedEntries | Where-Object { Test-Selected $_ $Only })
if ($selectedEntries.Count -eq 0) {
    throw "No inventory entries matched the requested selection: $($Only -join ', ')"
}

Write-Host "SourceRoot: $sourceRootFull"
Write-Host "TargetRoot: $targetRootFull"
Write-Host "Mode: $(if ($DryRun) { 'DryRun' } else { 'Full' })"
Write-Host "Selected entries: $($selectedEntries.Count)"
Write-Host "Log: $logFull"

$logDir = Split-Path -Parent $logFull
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
Set-Content -LiteralPath $logFull -Encoding UTF8 -Value @(
    "# JSONL migration log",
    "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
    "Mode: $(if ($DryRun) { 'DryRun' } else { 'Full' })"
)

$results = @()
foreach ($entry in $selectedEntries) {
    $outputPath = Get-OutputPath $entry $targetRootFull ([bool]$DryRun) (ConvertTo-NativePath $DryRunOutputRoot)
    $outputDir = Split-Path -Parent $outputPath
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    Write-Host ""
    Write-Host "==> $($entry.id)"
    Write-Host "Output: $outputPath"

    $command = Get-SlicerCommand $entry $sourceRootFull $outputPath
    Invoke-CheckedCommand $command $targetRootFull $logFull ([bool]$VerboseSlicer)

    if (-not (Test-Path -LiteralPath $outputPath)) {
        throw "Expected output was not created: $outputPath"
    }

    $lineCount = Get-JsonlLineCount $outputPath
    $expected = [int]$entry.expected_jsonl.line_count
    if ($lineCount -ne $expected) {
        throw "Line count mismatch for $($entry.id): actual=$lineCount expected=$expected"
    }

    $legacyPath = Resolve-UnderRoot $targetRootFull (ConvertTo-NativePath $entry.legacy_json.path)
    $legacyCount = Get-JsonFileCount $legacyPath

    $validateExit = $null
    if (-not $SkipValidate) {
        $validationTargetRoot = $targetRootFull
        if ($DryRun) {
            $validationTargetRoot = Resolve-UnderRoot $targetRootFull (ConvertTo-NativePath $DryRunOutputRoot)
        }

        $validateCommand = @(
            "python",
            "-B",
            "scripts\validate_jsonl\validate_jsonl.py",
            $outputPath,
            "--check-source-file",
            "--source-root",
            $sourceRootFull,
            "--target-root",
            $validationTargetRoot,
            "--quiet"
        )
        & $validateCommand[0] @($validateCommand[1..($validateCommand.Count - 1)])
        $validateExit = $LASTEXITCODE
        if ($validateExit -ne 0) {
            throw "Validation failed for $($entry.id) with exit code $validateExit"
        }
    }

    $results += [pscustomobject]@{
        Id = [string]$entry.id
        OutputPath = $outputPath
        LineCount = $lineCount
        ExpectedLineCount = $expected
        LegacyJsonCount = $legacyCount
        ValidateExitCode = $validateExit
    }
}

$reportLines = New-ReportLines $results ([bool]$DryRun) $sourceRootFull $targetRootFull
$reportDir = Split-Path -Parent $reportFull
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
Set-Content -LiteralPath $reportFull -Encoding UTF8 -Value $reportLines

Write-Host ""
Write-Host "Done: $($results.Count) JSONL target(s) generated."
Write-Host "Report: $reportFull"
