# Clone the workload repo at the pinned commit into data/mockito (shallow, no line-ending conversion).
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$repo = 'mockito/mockito'
$sha = '10b31ba2a8252cf340bc154c9e05224802a84691'
$dir = 'data/mockito'
if (Test-Path $dir) {
  if ((git -C $dir rev-parse HEAD 2>$null) -eq $sha) { "already at $sha"; exit 0 }
  Write-Error "$dir exists but is not at $sha. Remove it yourself and run again."
}
git init -q $dir
git -C $dir config core.autocrlf false
git -C $dir remote add origin "https://github.com/$repo.git"
git -C $dir fetch -q --depth 1 origin $sha
git -C $dir checkout -q FETCH_HEAD
"cloned $repo at $(git -C $dir rev-parse HEAD)"
