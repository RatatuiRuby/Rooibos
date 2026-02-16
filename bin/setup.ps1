# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
  Write-Error "mise isn't installed. Please install it to continue: https://mise.jdx.dev"
  exit 1
}

# Read the Ruby version from mise.toml so we install the matching RubyInstaller.
$rubyVersion = (Select-String -Path mise.toml -Pattern 'ruby\s*=\s*"([^"]+)"').Matches.Groups[1].Value
$rubyMajorMinor = ($rubyVersion -split '\.')[0..1] -join '.'

# mise cannot compile Ruby from source on Windows (ruby-build produces broken
# native extension support). Install Ruby via RubyInstaller, which bundles the
# MSYS2 devkit for native gem compilation.
if (-not (Get-Command ruby -ErrorAction SilentlyContinue) -or -not ((ruby --version) -match $rubyMajorMinor)) {
  Write-Host "Ruby $rubyMajorMinor is required but not installed."
  if ($env:CI -ne "true") {
    $answer = Read-Host "Install it now via RubyInstaller (winget)? This will require administrator privileges. [Y/n]"
    if ($answer -and $answer -notmatch '^[Yy]') {
      Write-Error "Cannot continue without Ruby."
      exit 1
    }
  }
  winget install --id "RubyInstallerTeam.RubyWithDevKit.$rubyMajorMinor" --accept-source-agreements --accept-package-agreements
  # Refresh PATH so ruby is available
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Create .mise.local.toml (gitignored) with Windows-specific overrides:
#   - disable_tools: prevents mise from installing its own (broken) Ruby
if (-not (Test-Path .mise.local.toml) -or -not (Select-String -Path .mise.local.toml -Pattern 'disable_tools' -Quiet)) {
  $localToml = @"

[settings]
disable_tools = ["ruby"]
"@
  Add-Content -Path .mise.local.toml -Value $localToml
}

# mise handles Python and pre-commit. Ruby is disabled above.
mise install
mise x -- python -m pip install reuse

# pip installs scripts (like reuse.exe) to Python's Scripts directory,
# which mise does not add to PATH.
if (-not (Select-String -Path .mise.local.toml -Pattern '\[env\]' -Quiet -ErrorAction SilentlyContinue)) {
  $scriptsDir = (mise x -- python -c "import sysconfig; print(sysconfig.get_path('scripts'))").Trim()
  $envToml = @"

[env]
_.path = ["$($scriptsDir -replace '\\', '/')"]
"@
  Add-Content -Path .mise.local.toml -Value $envToml
}
gem install bundler:4.0.3

if ($env:CI -eq "true") {
  bundle config set --local frozen true
}

bundle install

if ($env:CI -ne "true") {
  pre-commit install
  bundle exec rake rdoc
}
