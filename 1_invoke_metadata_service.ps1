function Get-DosData
{
	#region PARAMETERS
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Uri,
		[Parameter(Mandatory = $false)]
		[string]$ObjName
	)
	#endregion
	begin
	{
		$output = @();
	}
	process
	{
		try
		{
			do
			{
				$pageInfo = Invoke-RestMethod -Uri $Uri -UseDefaultCredentials -ErrorAction Stop;
				$output += if ($pageInfo.PSobject.Properties.Name -contains "value") { $pageInfo.value }
				else { $pageInfo };
				$Uri = $pageInfo.'@odata.nextLink';
			}
			while ($Uri);
		}
		catch
		{
		}
	}
	end
	{
		if ($ObjName)
		{
			return New-Object PSObject -Property @{ $ObjName = $output };
		}
		else
		{
			return $output;
		}
	}
}


$root = "https://atlasdemo.hqcatalyst.local/MetadataService";

$uri = "$($root)/v1/DataMarts";
$dataMarts = Get-DosData -Uri $uri | Where-Object Id -eq 1103

foreach($dataMart in $dataMarts)
{
    $uri = "$($root)/v1/DataMarts($($dataMart.Id))";
    $dataMart = Get-DosData -Uri $uri
    $dataMart | Add-Member -Type NoteProperty -Name Entities -Value (Get-DosData -Uri "$root/v1/DataMarts($($dataMart.Id))/Entities")
    $dataMart | Add-Member -Type NoteProperty -Name Connections -Value (Get-DosData -Uri "$root/v1/DataMarts($($dataMart.Id))/Connections")
    foreach ($entity in $dataMart.Entities)
    {
	    $entity | Add-Member -Type NoteProperty -Name Fields -Value (Get-DosData -Uri "$root/v1/DataMarts($($dataMart.Id))/Entities($($entity.Id))/Fields")
	    $entity | Add-Member -Type NoteProperty -Name SourceBindings -Value (Get-DosData -Uri "$root/v1/DataMarts($($dataMart.Id))/Entities($($entity.Id))/SourceBindings")
	    $entity | Add-Member -Type NoteProperty -Name Indexes -Value (Get-DosData -Uri "$root/v1/DataMarts($($dataMart.Id))/Entities($($entity.Id))/Indexes")
	    $entity | Add-Member -Type NoteProperty -Name ParentEntityRelationships -Value (Get-DosData -Uri "$root/v1/DataMarts($($dataMart.Id))/Entities($($entity.Id))/ParentEntityRelationships")
		
	    foreach ($binding in $entity.SourceBindings)
	    {
		    $binding | Add-Member -Type NoteProperty -Name IncrementalConfigurations -Value (Get-DosData -Uri "$root/v1/DataMarts($($dataMart.Id))/Entities($($entity.Id))/SourceBindings($($binding.Id))/IncrementalConfigurations")
		    $binding | Add-Member -Type NoteProperty -Name SourcedByEntities -Value (Get-DosData -Uri "$root/v1/DataMarts($($dataMart.Id))/Entities($($entity.Id))/SourceBindings($($binding.Id))/SourcedByEntities")
	    }
    }

    $dataMart | ConvertTo-Json -Depth 100 -Compress | Out-File "C:\Users\spencer.nicol\Documents\github\elastic-atlas\output\$($dataMart.Id)_datamart.json" -Encoding Default -Force | Out-Null
}