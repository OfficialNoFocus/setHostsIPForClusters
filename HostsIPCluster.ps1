#!/bin/bash

# Version 1.0
param (
    [double]$psVersion =  $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor),
    [string]$Hostname = '{Hostnames}', 
    [bool]$CheckHostnameOnly = $false
)
# Function to get IP address based on interface priority and valid connections.
function Get-PrioritizedIPAddress {
    # Take the output of valid connections and store it.
    $connections = @()

    $adapters = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*", "Wi-Fi*" | Select-Object InterfaceAlias, IPAddress

    if ($psVersion -le 5.1) {
        $adapters | ForEach-Object {
            Test-Connection -ComputerName $_.IPAddress -ErrorAction SilentlyContinue | Out-Null
            if($?) {
                $connections += $_ 
            }
        }
    } else {
        $adapters | ForEach-Object {
            Test-Connection -TargetName $_.IPAddress -ErrorAction SilentlyContinue | Out-Null
            if($?) {
                $connections += $_ 
            }
        }
    }
    
    $ethernet = $connections | Where-Object { $_.InterfaceAlias -like 'Ethernet*' } | Select-Object -First 1
    if ($ethernet) {
        # If an valid Ethernet interface is found, display its details.
        Write-Host "Valid Ethernet found." -ForegroundColor Green
        return $ethernet.IPAddress
    } 
    else {
        # If no Ethernet interface is found, get the first Wi-Fi interface.
        $wifi = $connections | Where-Object { $_.InterfaceAlias -like 'Wi-Fi*' } | Select-Object -First 1
        if ($wifi) {
            # If a valid Wi-Fi interface is found
            Write-Host "Valid Wi-Fi connection found." -ForegroundColor Green
            return $wifi.IPAddress
        }
        else {
            Write-Host "No network connection detected. Exiting..." -ForegroundColor Red
            exit 1
        }
    }
}

# Get the prioritized IP address
[string]$DesiredIP = Get-PrioritizedIPAddress

# Adds entry to the hosts file.
#Requires -RunAsAdministrator
$hostsFilePath = "$($Env:WinDir)\system32\Drivers\etc\hosts"
$hostsFile = Get-Content $hostsFilePath

$escapedHostname = [Regex]::Escape($Hostname)
if ($hostsFile -match ".*\s+$escapedHostname.*")  {
    Write-Host "$Hostname - removing from hosts file... " -ForegroundColor Yellow -NoNewline
    $hostsFile -notmatch ".*\s+$escapedHostname.*" | Out-File $hostsFilePath 
    Write-Host " Done"

    $title    = 'Add new host IP?'
    $question = 'Do you want to add host with new IP?'

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0) {
        Write-Host 'Confirmed'
        Write-Host $DesiredIP.PadRight(20," ") "$Hostname - adding to hosts file... " -ForegroundColor Yellow -NoNewline
        Add-Content -Encoding UTF8 $hostsFilePath ("$DesiredIP".PadRight(20, " ") + "$Hostname")
        Write-Host " Done"
    } else {
        Write-Host 'Cancelled'
    }
} else {
    Write-Host $DesiredIP.PadRight(20," ") "$Hostname - adding to hosts file... " -ForegroundColor Yellow -NoNewline
    Add-Content -Encoding UTF8 $hostsFilePath ("$DesiredIP".PadRight(20, " ") + "$Hostname")
    Write-Host " Done"
}
