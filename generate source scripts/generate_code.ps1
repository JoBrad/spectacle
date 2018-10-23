<#
    Runs the docker swagger-codegen-cli image, with the provided swagger file, language, and output directory
    #>
Param(
    [Parameter(Mandatory=$true, HelpMessage="Path to the swagger file")] [ValidateNotNullOrEmpty()] [string] $SwaggerFile,
    [Parameter(Mandatory=$true, HelpMessage="Desired language to output")] [ValidateNotNullOrEmpty()] [string] $Language,
    [Parameter(Mandatory=$true, HelpMessage="Location where generated code should be placed")] [ValidateNotNullOrEmpty()] [string] $OutputLocation,
    [Parameter(Mandatory=$false, HelpMessage="A location where language-specific configuration files may be found.")] [ValidateNotNullOrEmpty()] [string] $ConfigsLocation
)

begin {
    # Strings -> Objects, for validation and ease-of-use
    $SwaggerFile = Get-Item "$SwaggerFile"
    if (-not $(Test-Path "$OutputLocation\$Language")) {
        mkdir "$OutputLocation\$Language" >$null
    }
    $OutputLocation = Get-Item -Path "$OutputLocation"
}

process {
    # These are separate so that docker commands are placed before swagger-codegen-cli commands
    $dockerOptions = @("docker", "run", "--rm")
    $cliOptions = @("swaggerapi/swagger-codegen-cli generate", "-a `"i2N2dZJdsMCqgvYjJDBuemCptjvBjGab:pEMX5ANi8oiyGsR0`"", "-l $Language")
    # Create a local volume for the docker container
    $localPath = New-Item -ItemType Directory -Force -Path "$PWD\$([System.IO.Path]::GetRandomFileName())"
    $tmpSource = New-Item -ItemType Directory "$localPath\source"
    $tmpOutput = New-Item -ItemType Directory "$localPath\$Language"
    
    $SwaggerFile=$SwaggerFile.CopyTo("$tmpSource\$($SwaggerFile.Name)")

    $dockerPath = "/local"
    $dockerSource = "$dockerPath/source"
    $dockerOutput = "$dockerPath/$Language"
    $dockerSwaggerFile = "$dockerSource/$($SwaggerFile.Name)"

    $dockerOptions += "-v `"${localPath}:${dockerPath}`""
    $cliOptions += @("-o `"$dockerOutput`"", "-i `"$dockerSwaggerFile`"")

    if ($ConfigsLocation -and $(Test-Path "${ConfigsLocation}\$Language.json")) {
        Copy-Item -Path "${ConfigsLocation}\$Language.json" -Destination "$tmpSource"
        $cliOptions += "-c `"$dockerSource/$Language.json`""
    }

    $dockerCmd = $($dockerOptions + $cliOptions) -join " "

    try {
        Invoke-Expression -Command $dockerCmd
        if ($(Get-ChildItem "$tmpOutput" | Measure-Object).Count -gt 0) {
            if (Test-Path "$OutputLocation\$Language") {
                Remove-Item -Recurse -Force "$OutputLocation\$Language" -Confirm
            }
            $tmpOutput.MoveTo("$OutputLocation\$($tmpOutput.Name)")
        } else {
            Write-Error "No files were output!"
        }
    } catch {
        Write-Error $_.Exception.Message
    }
}

end {
    if (Test-Path $localPath) {
        Remove-Item -Force -Recurse "$localPath"
    }
}

