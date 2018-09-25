function Download
{
    param(
        [Parameter(Mandatory=$true)]
        [String] $url,
        [Parameter(Mandatory=$false)]
        [String] $cookie,
        [Parameter(Mandatory=$true)]
        [String] $localFile
    )

    begin {
        $client = New-Object System.Net.WebClient

        If ($cookie -ne $null)
        {
            $client.Headers.Add([System.Net.HttpRequestHeader]::Cookie, $cookie) 
        }

        $Global:downloadComplete = $false

        $eventDataComplete = Register-ObjectEvent $client DownloadFileCompleted `
            -SourceIdentifier WebClient.DownloadFileComplete `
            -Action {$Global:downloadComplete = $true}
        $eventDataProgress = Register-ObjectEvent $client DownloadProgressChanged `
            -SourceIdentifier WebClient.DownloadProgressChanged `
            -Action { $Global:DPCEventArgs = $EventArgs }    
    }

    process {
        Write-Progress -Activity 'Downloading file' -Status $url

        $client.DownloadFileAsync($url, $localFile)

        while (!($Global:downloadComplete)) {                
            $pc = $Global:DPCEventArgs.ProgressPercentage
            if ($pc -ne $null) {
                Write-Progress -Activity 'Downloading file' -Status $url -PercentComplete $pc
            }
        }

        Write-Progress -Activity 'Downloading file' -Status $url -Complete
    }

    end {
        Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged
        Unregister-Event -SourceIdentifier WebClient.DownloadFileComplete
        $client.Dispose()
        $Global:downloadComplete = $null
        $Global:DPCEventArgs = $null
        Remove-Variable client
        Remove-Variable eventDataComplete
        Remove-Variable eventDataProgress
        [GC]::Collect()
    }
}

function Install-JRE
{
    $url = "http://download.oracle.com/otn-pub/java/jdk/10.0.2+13/19aef61b38124481863b1413dce1855f/jre-10.0.2_windows-x64_bin.exe"
    $destination = "$pwd\setup\install-jre.exe"
    $cookie = "oraclelicense=accept-securebackup-cookie"

    Download -url $url -cookie $cookie -localFile $destination

    Write-Host "Installing JRE. This may take several minutes"
    Start-Process $destination -ArgumentList "/s INSTALL_SILENT=1 STATIC=0 AUTO_UPDATE=0 WEB_JAVA=0 WEB_JAVA_SECURITY_LEVEL=H WEB_ANALYTICS=0 EULA=0 REBOOT=0 NOSTARTMENU=1 SPONSORS=0 /L $pwd\logs\java-install.log" -Wait
    Write-Host "JRE Install Finished"

    Write-Host "Setting JAVA_HOME env variable"
    $Env:JAVA_HOME = "C:\Program Files\Java\jre-10.0.2"
}

function Check-Java
{
    try
    {
        Write-Host "Checking JAVA JRE version"
        start-process java -ArgumentList "-version" -NoNewWindow
    }
    catch
    {
        Write-Host "JRE is not installed, downloading JRE from the Web"
        Install-JRE
    }
}

function Get-Elasticsearch
{
    $url = "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.4.1.zip"
    $zipDestination = "$pwd\setup\elasticsearch.zip"
    $elasticsearchPath = "$pwd\setup"

    Write-Host "Downloading Elasticsearch from web"
    Download -url $url -localFile $zipDestination

    Write-Host "Unzipping Elasticsearch"
    Expand-Archive -LiteralPath $zipDestination -DestinationPath $elasticsearchPath

    Write-Host "Installing Elasticsearch as a service"
    Start-Process "$elasticsearchPath\elasticsearch-6.4.1\bin\elasticsearch-service.bat" -Wait -ArgumentList "Install"

    Write-Host "Starting Elasticsearch service"
    Start-Service -Name "elasticsearch-service-x64"
}

function Install
{
    try
    {
        md -Name setup
        md -Name logs
        Check-Java
        Get-Elasticsearch
        Write-Host "Setup Complete"

    }
    catch
    {
        Write-Error "Error: $PSItem"
        Write-Error $PSItem.Exception.Message
        Write-Error $PSItem.Exception.InnerException
    }

}

Install