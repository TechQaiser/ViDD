# Parallel segmented downloader (fast)
param(
    [string]$downloadURL = "https://www.qsrtools.shop/vidd_beta.zip",
    [string]$archiveFile = "$env:TEMP\vidd_exe.zip",
    [int]$chunks = 8,                      # increase for more parallelism (don't set insanely high)
    [int]$timeoutSec = 60
)

# Ensure TLS modern
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Function Get-ContentLength {
    param($url)
    $req = [System.Net.WebRequest]::Create($url)
    $req.Method = "HEAD"
    try {
        $resp = $req.GetResponse()
        $len = $resp.Headers["Content-Length"]
        $resp.Close()
        return [int64]$len
    } catch {
        return $null
    }
}

Function DownloadRange {
    param($url, $from, $to, $outPath, $timeout)
    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.AddRange($from, $to)
        $req.Timeout = $timeout * 1000
        $resp = $req.GetResponse()
        $stream = $resp.GetResponseStream()
        $fs = [System.IO.File]::Open($outPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $buffer = New-Object byte[] 81920
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fs.Write($buffer, 0, $read)
        }
        $fs.Close()
        $stream.Close()
        $resp.Close()
        return $true
    } catch {
        Write-Host "Range $from-$to failed: $_"
        return $false
    }
}

# MAIN
$size = Get-ContentLength -url $downloadURL
if (-not $size) {
    Write-Host "Couldn't determine remote file size — falling back to single-stream download."
    Invoke-WebRequest -Uri $downloadURL -OutFile $archiveFile -UseBasicParsing
    return
}

Write-Host "Remote size: $size bytes"

# compute ranges
if ($chunks -gt $size) { $chunks = [int]$size }    # avoid >1-byte chunks
$chunkSize = [math]::Floor($size / $chunks)
$tempParts = @()
$jobs = @()

for ($i = 0; $i -lt $chunks; $i++) {
    $start = $i * $chunkSize
    if ($i -eq ($chunks - 1)) {
        $end = $size - 1
    } else {
        $end = (($i + 1) * $chunkSize) - 1
    }
    $partFile = "$env:TEMP\vidd_part_$i.part"
    if (Test-Path $partFile) { Remove-Item $partFile -Force }
    $tempParts += $partFile

    # Start background job for each part
    $scriptBlock = {
        param($u,$s,$e,$p,$t)
        # call the DownloadRange function in the job scope
        Function DownloadRangeLocal {
            param($url, $from, $to, $outPath, $timeout)
            try {
                $req = [System.Net.HttpWebRequest]::Create($url)
                $req.AddRange($from, $to)
                $req.Timeout = $timeout * 1000
                $resp = $req.GetResponse()
                $stream = $resp.GetResponseStream()
                $fs = [System.IO.File]::Open($outPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                $buffer = New-Object byte[] 81920
                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $fs.Write($buffer, 0, $read)
                }
                $fs.Close()
                $stream.Close()
                $resp.Close()
                return $true
            } catch {
                Write-Host "Range $from-$to failed in job: $_"
                return $false
            }
        }
        DownloadRangeLocal -url $u -from $s -to $e -outPath $p -timeout $t
    }

    $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList @($downloadURL, $start, $end, $partFile, $timeoutSec)
}

# Wait
Write-Host "Waiting for $($jobs.Count) download jobs..."
$allOk = $true
Receive-Job -Job $jobs -Keep -ErrorAction SilentlyContinue | Out-Null
Wait-Job -Job $jobs

foreach ($j in $jobs) {
    $res = Receive-Job -Job $j -ErrorAction SilentlyContinue
    if (-not $res) {
        $allOk = $false
    }
    Remove-Job -Job $j -Force
}

if (-not $allOk) {
    Write-Host "One or more parts failed — falling back to single-stream download."
    if (Test-Path $archiveFile) { Remove-Item $archiveFile -Force }
    Invoke-WebRequest -Uri $downloadURL -OutFile $archiveFile -UseBasicParsing
    return
}

# Combine
Write-Host "Combining parts..."
if (Test-Path $archiveFile) { Remove-Item $archiveFile -Force }
$fsOut = [System.IO.File]::Open($archiveFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
foreach ($p in $tempParts) {
    $fsIn = [System.IO.File]::OpenRead($p)
    $buffer = New-Object byte[] 81920
    while (($read = $fsIn.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $fsOut.Write($buffer, 0, $read)
    }
    $fsIn.Close()
    Remove-Item $p -Force
}
$fsOut.Close()

Write-Host "Downloaded to $archiveFile"
