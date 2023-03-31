---
title: "Allowing Microsoft 365 traffic with Azure NSGs"
date: 2023-03-31
draft: false
tags: ["azure", "M365"]
---

Azure [network security groups](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview) (NSGs) provide IP-based traffic filtering for subnets and VM network interfaces (NICs). But services like Microsoft 365 use a large and frequently-changing IP space, so writing IP-based rules is challenging. Azure Firewall can provide HTTP filtering (and DNS with the Premium SKU), but it's an expensive and often overkill solution.

Recently I deployed a hybrid Exchange environment in Azure, which requires inbound SMTP and HTTPS traffic. Within minutes I received hundreds of malicious requests from all over the internet (observed via [NSG traffic analytics](https://learn.microsoft.com/en-us/azure/network-watcher/traffic-analytics)). So I wrote a quick script to create inbound NSG rules for the required Exchange Online IP ranges. This could easily be repurposed for other services or outbound rules too.

```PowerShell
$EXCLUDE_IPV6 = $false

# Get Exchange IPv4 CIDRs, filtering out the Common ServiceArea. Note that NSGs don't support v4 and v6 in the same rule as of writing, and PowerShell doesn't have a built-in parser to differentiate
# https://learn.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-ip-web-service#endpoints-web-method
$ips = (Invoke-RestMethod "https://endpoints.office.com/endpoints/worldwide?clientrequestid=$(New-Guid)&Instance=Worldwide&ServiceAreas=Exchange&NoIPv6=$EXCLUDE_IPV6") | where { $_.ServiceArea -eq "Exchange" -and $_.ips -ne $null } | select -ExpandProperty ips -Unique
$v4 = $ips | where { $_.contains(":") }
$v6 = $ips | where { -not $_.contains(":") }

# https://learn.microsoft.com/en-us/exchange/hybrid-deployment-prerequisites#hybrid-deployment-protocols-ports-and-endpoints
$rules = @(New-AZNetworkSecurityRuleConfig -Name "AllowExchangeOnlineSMTPInBoundV4" -Direction Inbound -Priority 100 -Access Allow -Protocol Tcp -SourceAddressPrefix $v4 -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 25)
$rules += New-AZNetworkSecurityRuleConfig -Name "AllowExchangeOnlineHTTPSInBoundV4" -Direction Inbound -Priority 101 -Access Allow -Protocol Tcp -SourceAddressPrefix $v4 -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443

if (-not $EXCLUDE_IPV6) {
	$rules += New-AZNetworkSecurityRuleConfig -Name "AllowExchangeOnlineSMTPInBoundV6" -Direction Inbound -Priority 100 -Access Allow -Protocol Tcp -SourceAddressPrefix $v6 -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 25
	$rules += New-AZNetworkSecurityRuleConfig -Name "AllowExchangeOnlineHTTPSInBoundV6" -Direction Inbound -Priority 101 -Access Allow -Protocol Tcp -SourceAddressPrefix $v6 -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
}

$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName 'your-rg' -Name 'your-nsg'
$nsg.SecurityRules = $rules
$nsg | Set-AzNetworkSecurityGroup

# New-AzNetworkSecurityGroup -SecurityRules $rules
```
