 #Capture-LDPPacket
 [Int16]$Duration = 62
 try {
                $CimSession = New-CimSession -ComputerName $env:COMPUTERNAME -ErrorAction Stop
            } catch {
                Write-Warning "Unable to create CimSession. Please make sure WinRM and PSRemoting is enabled on $Computer."
                continue
            }

            $ETLFile = Invoke-Command -ComputerName $env:COMPUTERNAME -ScriptBlock {
                $TempFile = New-TemporaryFile
                Rename-Item -Path $TempFile.FullName -NewName $TempFile.FullName.Replace('.tmp', '.etl') -PassThru
            }

            $Adapter = Get-NetAdapter -Physical -CimSession $CimSession | 
                Where-Object {$_.Status -eq 'Up' -and $_.InterfaceType -eq 6} | 
                Select-Object -First 1 -ExpandProperty Name

            if ($Adapter) {
                $Session = New-NetEventSession -Name LDP -LocalFilePath 'C:\temp\temp2.etl' -CaptureMode SaveToFile -CimSession $CimSession

                Add-NetEventPacketCaptureProvider -SessionName LDP -EtherType 0x88CC -TruncationLength 1024 -CaptureType BothPhysicalAndSwitch -CimSession $CimSession | Out-Null
                Add-NetEventNetworkAdapter -Name $Adapter -PromiscuousMode $True -CimSession $CimSession | Out-Null

                Start-NetEventSession -Name LDP -CimSession $CimSession

                $Seconds = $Duration
                $End = (Get-Date).AddSeconds($Seconds)
                while ($End -gt (Get-Date)) {
                    $SecondsLeft = $End.Subtract((Get-Date)).TotalSeconds
                    $Percent = ($Seconds - $SecondsLeft) / $Seconds * 100
                    Write-Progress -Activity "CDP Packet Capture" -Status "Capturing on $env:COMPUTERNAME..." -SecondsRemaining $SecondsLeft -PercentComplete $Percent
                    [System.Threading.Thread]::Sleep(500)
                }

                Stop-NetEventSession -Name LDP -CimSession $CimSession

                $Log = Invoke-Command -ComputerName $env:COMPUTERNAME -ScriptBlock {
                    Get-WinEvent -Path $args[0] -Oldest | 
                    Where-Object {$_.Id -eq 1001 -and [BitConverter]::ToUInt16($_.Properties[3].Value[13..10], 0) -eq [UInt16]0x88cc} |
                        Select-Object -Last 1 -ExpandProperty Properties
                } -ArgumentList $Session.LocalFilePath

                }