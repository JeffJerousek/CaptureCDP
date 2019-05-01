function Parse-LDPPacket {

<#

.SYNOPSIS

    Parse CDP packet returned from Capture-CDPPacket.

.DESCRIPTION

    Parse CDP packet to get port, switch, model, ipaddress and vlan.

.PARAMETER Packet

    Array of one or more byte arrays from Capture-CDPPacket.

.EXAMPLE

    PS> $Packet = Capture-CDPPacket
    PS> Parse-CDPPacket -Packet $Packet

    Port      : FastEthernet0/1 
    Switch    : SWITCH1.domain.example 
    Model     : cisco WS-C2960-48TT-L 
    IPAddress : 192.0.2.10
    VLAN      : 10

.EXAMPLE

    PS> Capture-CDPPacket -Computer COMPUTER1 | Parse-CDPPacket

    Port      : FastEthernet0/1 
    Switch    : SWITCH1.domain.example 
    Model     : cisco WS-C2960-48TT-L 
    IPAddress : 192.0.2.10
    VLAN      : 10

.EXAMPLE

    PS> 'COMPUTER1', 'COMPUTER2' | Capture-CDPPacket | Parse-CDPPacket

    Port      : FastEthernet0/1 
    Switch    : SWITCH1.domain.example 
    Model     : cisco WS-C2960-48TT-L 
    IPAddress : 192.0.2.10
    VLAN      : 10

    Port      : FastEthernet0/2 
    Switch    : SWITCH1.domain.example 
    Model     : cisco WS-C2960-48TT-L 
    IPAddress : 192.0.2.10
    VLAN      : 20

#>

    [CmdletBinding()]
    param(
        [Parameter(Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [object[]]$Packet
    )

    process {

        $Offset = 14
        $Hash = @{}

        while ($Offset -lt ($Packet.Length - 4)) {

            $LLDP = [BitConverter]::ToUInt16($Packet[13..12], 0)

            $Destination = '{0:X2}' -f $Packet[0] + ':' + '{0:X2}' -f $Packet[1] + ':' +'{0:X2}' -f $Packet[2] + ':' +'{0:X2}' -f $Packet[3] + ':' +'{0:X2}' -f $Packet[4] + ':' +'{0:X2}' -f $Packet[5]
            $Source = '{0:X2}' -f $Packet[6] + ':' + '{0:X2}' -f $Packet[7]+ ':' +'{0:X2}' -f $Packet[8]+ ':' +'{0:X2}' -f $Packet[9]+ ':' +'{0:X2}' -f $Packet[10]+ ':' +'{0:X2}' -f $Packet[11]
            #https://www.troliver.com/?p=348
            $Type   = [BitConverter]::ToUInt16($Packet[($Offset + 1)..$Offset], 0)
            $Length = [BitConverter]::ToUInt16($Packet[($Offset + 3)..($Offset + 2)], 0)

            switch ($Type)
            {
                1  { $Hash.Add('Switch',    [System.Text.Encoding]::ASCII.GetString($Packet[($Offset + 4)..($Offset + $Length)])) }
                2  { $Hash.Add('IPAddress', ([System.Net.IPAddress][byte[]]$Packet[($Offset + 13)..($Offset + 16)]).IPAddressToString) }
                3  { $Hash.Add('Port',      [System.Text.Encoding]::ASCII.GetString($Packet[($Offset + 4)..($Offset + $Length)])) }
                6  { $Hash.Add('Model',     [System.Text.Encoding]::ASCII.GetString($Packet[($Offset + 4)..($Offset + $Length)])) }
                10 { $Hash.Add('VLAN',      [BitConverter]::ToUInt16($Packet[($Offset + 5)..($Offset + 4)], 0)) }
            }

	        if ($Length -eq 0 ) {
		        $Offset = $Packet.Length
	        }

	        $Offset = $Offset + $Length

        }

        return [PSCustomObject]$Hash

    }

}
#endregion