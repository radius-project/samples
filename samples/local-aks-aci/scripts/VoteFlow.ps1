function Get-DemoScoresFromPacket {
    param([string]$Packet)
    if (-not $Packet.StartsWith('42')) { return $null }
    $event = ConvertFrom-Json -InputObject $Packet.Substring(2) -AsHashtable -NoEnumerate
    if ($event.Count -lt 2 -or $event[0] -ne 'scores') { return $null }
    $scores = if ($event[1] -is [string]) { ConvertFrom-Json -InputObject $event[1] -AsHashtable } else { $event[1] }
    foreach ($key in @('a', 'b')) {
        if (-not $scores.ContainsKey($key) -or $scores[$key] -isnot [long] -and $scores[$key] -isnot [int] -or $scores[$key] -lt 0) {
            throw "Invalid $key count in the result service's scores event."
        }
    }
    return $scores
}

function Send-DemoSocketPacket {
    param([Net.WebSockets.ClientWebSocket]$Socket, [string]$Packet, [Threading.CancellationToken]$Token)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Packet)
    $null = $Socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $Token).GetAwaiter().GetResult()
}

function Receive-DemoScores {
    param([Net.WebSockets.ClientWebSocket]$Socket, [Threading.CancellationToken]$Token)
    while (-not $Token.IsCancellationRequested) {
        $stream = [IO.MemoryStream]::new()
        try {
            do {
                $buffer = [byte[]]::new(4096)
                $part = $Socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $Token).GetAwaiter().GetResult()
                if ($part.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'The result service closed the WebSocket before the vote was verified.' }
                $stream.Write($buffer, 0, $part.Count)
                if ($stream.Length -gt 1048576) { throw 'Unexpectedly large Socket.IO packet.' }
            } while (-not $part.EndOfMessage)
            $packet = [Text.Encoding]::UTF8.GetString($stream.ToArray())
        }
        finally { $stream.Dispose() }
        if ($packet.StartsWith('0')) { Send-DemoSocketPacket $Socket '40' $Token }
        elseif ($packet -eq '2') { Send-DemoSocketPacket $Socket '3' $Token }
        elseif ($packet.StartsWith('44')) { throw "Socket.IO connection error: $packet" }
        else {
            $scores = Get-DemoScoresFromPacket $packet
            if ($null -ne $scores) { return $scores }
        }
    }
    throw 'Timed out waiting for the result service scores.'
}

function Invoke-DemoVoteProof {
    param([uri]$VoteUrl, [uri]$ResultUrl, [ValidateRange(5, 180)][int]$TimeoutSeconds = 60,
        [string]$ConnectionHint = '')
    foreach ($url in @($VoteUrl, $ResultUrl)) {
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 5
            if ($response.StatusCode -ne 200) { throw "HTTP $($response.StatusCode)" }
        }
        catch { throw "Cannot reach demo endpoint $url. $ConnectionHint Details: $($_.Exception.GetBaseException().Message)" }
    }
    $socket = [Net.WebSockets.ClientWebSocket]::new()
    $timeout = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
    try {
        $endpoint = [UriBuilder]::new($ResultUrl)
        $endpoint.Scheme = if ($ResultUrl.Scheme -eq 'https') { 'wss' } else { 'ws' }
        $endpoint.Path = '/socket.io/'
        $endpoint.Query = 'EIO=4&transport=websocket'
        try { $null = $socket.ConnectAsync($endpoint.Uri, $timeout.Token).GetAwaiter().GetResult() }
        catch { throw "Cannot connect to the result WebSocket $($endpoint.Uri). $ConnectionHint Details: $($_.Exception.GetBaseException().Message)" }
        $before = Receive-DemoScores $socket $timeout.Token
        $voterId = "demo-$([guid]::NewGuid().ToString('N'))"
        $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        $session.Cookies.Add($VoteUrl, [Net.Cookie]::new('voter_id', $voterId, '/'))
        $response = Invoke-WebRequest -Uri $VoteUrl -Method Post -Body @{ vote = 'b' } -WebSession $session -TimeoutSec $TimeoutSeconds
        if ($response.StatusCode -ne 200) { throw "The vote endpoint returned HTTP $($response.StatusCode)." }
        do {
            $after = Receive-DemoScores $socket $timeout.Token
        } while ($after.b -lt ($before.b + 1) -or ($after.a + $after.b) -lt ($before.a + $before.b + 1))
        return @{ before = $before; after = $after; voterId = $voterId; verifiedAt = [DateTimeOffset]::UtcNow.ToString('o') }
    }
    finally {
        $socket.Dispose()
        $timeout.Dispose()
    }
}
