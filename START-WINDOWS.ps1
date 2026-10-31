$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\backend"
if (!(Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
  Write-Host "Created backend\.env. Add your Supabase project URL and public key, then run this script again."
  exit 0
}
npm install
npm run check
npm run dev
