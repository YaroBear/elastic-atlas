$CONFIG = Get-Content "$(Split-Path $MyInvocation.MyCommand.Path -Parent)\config.json" | ConvertFrom-Json

function Get-AccessToken
{
	$fabricUser = "fabric-installer"
	$scopes = "dos/metadata dos/metadata.serviceAdmin fabric/authorization.read"
	$url = "$($CONFIG.IDENTITY_SERVICE_URL)/connect/token"
	$body = @{
		client_id = "$fabricUser"
		grant_type = "client_credentials"
		scope	  = "$scopes"
		client_secret = $CONFIG.DECRYPTED_INSTALLER_SECRET
	}
	$accessTokenResponse = Invoke-RestMethod -Method Post -Uri $url -Body $body
	return $accessTokenResponse.access_token
}
function Get-DosData
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$uri,
		[Parameter(Mandatory = $false)]
		[string]$objName
	)
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
				$pageInfo = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ "Authorization" = "Bearer $($CONFIG.Token)" } -ContentType "application/json" -ErrorAction Stop;
				$output += if ($pageInfo.PSobject.Properties.Name -contains "value") { $pageInfo.value }
				else { $pageInfo };
				$uri = $pageInfo.'@odata.nextLink';
			}
			while ($uri);
		}
		catch
		{
			Write-Error $Error
		}
	}
	end
	{
		if ($objName)
		{
			return New-Object PSObject -Property @{ $objName = $output };
		}
		else
		{
			return $output;
		}
	}
}
function Get-Datamarts
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$metadataServiceUrl,
		[Parameter(Mandatory = $true)]
		[string]$outputDirectory,
		[Parameter(Mandatory = $false)]
		[array]$dataMartIds
	)
	begin
	{
		$rawMarts = if ($dataMartIds) { Get-DosData -Uri "$($metadataServiceUrl)/DataMarts" | Where-Object { $_.Id -in $dataMartIds } }
		else { Get-DosData -Uri "$($metadataServiceUrl)/DataMarts" };
		$rawNotes = Get-DosData -Uri "$($metadataServiceUrl)/Notes"
		#$rawSummaryBindingDependencies = Get-DosData -Uri "$($metadataServiceUrl)/SummaryBindingDependencies"
		#region FUNCTIONS FOR EMPTY DATAMART OBJECT CREATION
		function CreateEmpty-DatamartObject
		{
			$datamart = New-Object PSObject
			$datamart | Add-Member -Type NoteProperty -Name permissions -Value @()
			$datamart | Add-Member -Type NoteProperty -Name name -Value $Null
			$datamart | Add-Member -Type NoteProperty -Name description -Value $Null
			$datamart | Add-Member -Type NoteProperty -Name type -Value $Null
			$datamart | Add-Member -Type NoteProperty -Name is-hidden -Value $Null
			$datamart | Add-Member -Type NoteProperty -Name notes -Value @()
			$datamart | Add-Member -Type NoteProperty -Name entities -Value @()
			
			return $datamart
		}
		function CreateEmpty-PermissionObject
		{
			$permission = New-Object PSObject
			$permission | Add-Member -Type NoteProperty -Name permission -Value $Null
			
			return $permission
		}
		function CreateEmpty-NoteObject
		{
			$note = New-Object PSObject
			$note | Add-Member -Type NoteProperty -Name description -Value $Null
			$note | Add-Member -Type NoteProperty -Name text -Value $Null
			$note | Add-Member -Type NoteProperty -Name user -Value $Null
			
			return $note
		}
		function CreateEmpty-EntityObject
		{
			$entity = New-Object PSObject
			$entity | Add-Member -Type NoteProperty -Name permissions -Value @()
			$entity | Add-Member -Type NoteProperty -Name name -Value $Null
			$entity | Add-Member -Type NoteProperty -Name business-description -Value $Null
			$entity | Add-Member -Type NoteProperty -Name technical-description -Value $Null
			$entity | Add-Member -Type NoteProperty -Name is-public -Value $Null
			$entity | Add-Member -Type NoteProperty -Name allows-data-entry -Value $Null
			$entity | Add-Member -Type NoteProperty -Name last-successful-load -Value $Null
			$entity | Add-Member -Type NoteProperty -Name database -Value $Null
			$entity | Add-Member -Type NoteProperty -Name schema -Value $Null
			$entity | Add-Member -Type NoteProperty -Name notes -Value @()
			$entity | Add-Member -Type NoteProperty -Name source-entity -Value $Null
			$entity | Add-Member -Type NoteProperty -Name source-schema -Value $Null
			$entity | Add-Member -Type NoteProperty -Name fields -Value @()
			
			return $entity
		}
		function CreateEmpty-SourceEntityObject
		{
			$sourceEntity = New-Object PSObject
			$sourceEntity | Add-Member -Type NoteProperty -Name permissions -Value @()
			$sourceEntity | Add-Member -Type NoteProperty -Name name -Value $Null
			$sourceEntity | Add-Member -Type NoteProperty -Name business-description -Value $Null
			$sourceEntity | Add-Member -Type NoteProperty -Name technical-description -Value $Null
			$sourceEntity | Add-Member -Type NoteProperty -Name is-public -Value $Null
			$sourceEntity | Add-Member -Type NoteProperty -Name allows-data-entry -Value $Null
			$sourceEntity | Add-Member -Type NoteProperty -Name last-successful-load -Value $Null
			
			return $sourceEntity
		}
		function CreateEmpty-FieldObject
		{
			$field = New-Object PSObject
			$field | Add-Member -Type NoteProperty -Name name -Value @()
			$field | Add-Member -Type NoteProperty -Name business-description -Value $Null
			$field | Add-Member -Type NoteProperty -Name technical-description -Value $Null
			$field | Add-Member -Type NoteProperty -Name status -Value $Null
			$field | Add-Member -Type NoteProperty -Name data-type -Value $Null
			$field | Add-Member -Type NoteProperty -Name notes -Value $Null
			$field | Add-Member -Type NoteProperty -Name source-field -Value $Null
			
			return $field
		}
		function CreateEmpty-SourceBindingObject
		{
			$sourceBinding = New-Object PSObject
			$sourceBinding | Add-Member -Type NoteProperty -Name name -Value @()
			$sourceBinding | Add-Member -Type NoteProperty -Name description -Value $Null
			$sourceBinding | Add-Member -Type NoteProperty -Name sql -Value $Null
			$sourceBinding | Add-Member -Type NoteProperty -Name status -Value $Null
			$sourceBinding | Add-Member -Type NoteProperty -Name notes -Value $Null
			
			return $sourceBinding
		}
		function CreateEmpty-DestinationBindingObject
		{
			$destinationBinding = New-Object PSObject
			$destinationBinding | Add-Member -Type NoteProperty -Name name -Value @()
			$destinationBinding | Add-Member -Type NoteProperty -Name description -Value $Null
			$destinationBinding | Add-Member -Type NoteProperty -Name sql -Value $Null
			$destinationBinding | Add-Member -Type NoteProperty -Name status -Value $Null
			$destinationBinding | Add-Member -Type NoteProperty -Name notes -Value $Null
			
			return $destinationBinding
		}
		function Y
		{
			$true
		}
		function N
		{
			$false
		}
		#endregion
	}
	process
	{
		foreach ($rawMart in $rawMarts)
		{
			#region CREATE A RAW OBJECT OF THE DATA MART AS IT CAME FROM METADATA SERVICE
			$rawDataMart = $rawMart;
			$rawDataMart | Add-Member -Type NoteProperty -Name Entities -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Entities")
			$rawDataMart | Add-Member -Type NoteProperty -Name Bindings -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Bindings")
			$rawDataMart | Add-Member -Type NoteProperty -Name Connections -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Connections")
			$rawDataMart | Add-Member -Type NoteProperty -Name RelatedResources -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/RelatedResources")
			$rawDataMart | Add-Member -Type NoteProperty -Name Notes -Value @($rawNotes | Where-Object { $_.AnnotatedObjectId -eq $rawDataMart.Id -and $_.AnnotatedObjectType -eq "DataMart" })
			foreach ($rawEntity in $rawDataMart.Entities)
			{
				$rawEntity | Add-Member -Type NoteProperty -Name Fields -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Entities($($rawEntity.Id))/Fields")
				$rawEntity | Add-Member -Type NoteProperty -Name Indexes -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Entities($($rawEntity.Id))/Indexes")
				$rawEntity | Add-Member -Type NoteProperty -Name Notes -Value @($rawNotes | Where-Object { $_.AnnotatedObjectId -eq $rawEntity.Id -and $_.AnnotatedObjectType -eq "Entity" })
			}
			foreach ($rawBinding in $rawDataMart.Bindings)
			{
				$rawBinding | Add-Member -Type NoteProperty -Name BindingDependencies -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Bindings($($rawBinding.Id))/BindingDependencies")
				$rawBinding | Add-Member -Type NoteProperty -Name IncrementalConfigurations -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Bindings($($rawBinding.Id))/IncrementalConfigurations")
				$rawBinding | Add-Member -Type NoteProperty -Name ObjectRelationships -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Bindings($($rawBinding.Id))/ObjectRelationships")
				$rawBinding | Add-Member -Type NoteProperty -Name Notes -Value @($rawNotes | Where-Object { $_.AnnotatedObjectId -eq $rawBinding.Id -and $_.AnnotatedObjectType -eq "Binding" })
				
				foreach ($rawBindingDependency in $rawBinding.BindingDependencies)
				{
					$rawBindingDependency | Add-Member -Type NoteProperty -Name FieldMappings -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($rawDataMart.Id))/Bindings($($rawBinding.Id))/BindingDependencies($($rawBindingDependency.Id))/FieldMappings")
				}
			}
			
			foreach ($rawField in $rawEntity.Fields)
			{
				$rawField | Add-Member -Type NoteProperty -Name Notes -Value @($rawNotes | Where-Object { $_.AnnotatedObjectId -eq $rawField.Id -and $_.AnnotatedObjectType -eq "Field" })
			}
			
			$rawDataMart | ConvertTo-Json -Depth 100 -Compress | Out-File "$($outputDirectory)\$($rawDataMart.Id)_datamart.json" -Encoding Default -Force | Out-Null;
			#endregion
			
			##region CREATE A NEW ELASTIC SEARCH VERSION OF THE DATA MART
			#$datamart = New-Object PSObject;
			#$datamart | Add-Member -Type NoteProperty -Name data-mart -Value (CreateEmpty-DatamartObject);
			#
			#$dataMart.'data-mart'.name = $rawDataMart.Name;
			#$dataMart.'data-mart'.description = $rawDataMart.Description;
			#$dataMart.'data-mart'.type = $rawDataMart.DataMartType;
			#$dataMart.'data-mart'.'is-hidden' = & $rawDataMart.IsHidden;
			#
			#foreach($rawEntity in $rawDataMart.Entities)
			#{
			#    $entity = CreateEmpty-EntityObject;
			#    $entity.name = $rawEntity.EntityName;
			#    $entity.'business-description' = $rawEntity.BusinessDescription;
			#    $entity.'technical-description' = $rawEntity.TechnicalDescription;
			#    $entity.'is-public' = $rawEntity.IsPublic;
			#    $entity.'allows-data-entry' = $rawEntity.AllowsDataEntry;
			#    $entity.'last-successful-load' = $rawEntity.LastSuccessfulLoadTimestamp;
			#    $entity.database = $rawEntity.AttributeValues[$rawEntity.AttributeValues.AttributeName.IndexOf('DatabaseName')].AttributeValue;
			#    $entity.schema = $rawEntity.AttributeValues[$rawEntity.AttributeValues.AttributeName.IndexOf('SchemaName')].AttributeValue;
			#
			#    foreach($rawField in $rawEntity.Fields)
			#    {
			#        $field = CreateEmpty-FieldObject;
			#        $field.name = $rawField.FieldName;
			#        $field.'business-description' = $rawField.BusinessDescription;
			#        $field.'technical-description' = $rawField.TechnicalDescription;
			#        $field.status = $rawField.Status;
			#        $field.'data-type' = $rawField.DataType;
			#
			#        $entity.fields += $field;        
			#    }
			#
			#    $dataMart.'data-mart'.entities += $entity;
			#}
			#$dataMart | ConvertTo-Json -Depth 100 | Out-File "$($outputDirectory)\$($rawDataMart.Id)_datamart_elastic_doc.json" -Force
			##endregion
		}
	}
}

$CONFIG | Add-Member -Type NoteProperty -Name TOKEN -Value (Get-AccessToken);
Get-Datamarts -metadataServiceUrl $CONFIG.METADATA_SERVICE_URL -outputDirectory $CONFIG.OUTPUT_DIRECTORY -dataMartIds $CONFIG.DATAMARTS_ARRAY