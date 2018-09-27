$CONFIG = Get-Content "$(Split-Path $MyInvocation.MyCommand.Path -Parent)\config.json" | ConvertFrom-Json;
$start = (Get-Date);
function Get-Timepsan ($start, $end)
{
	$runTime = New-Timespan -Start $start -End $end;
	return $("{0}:{1}:{2}:{3}" -f $runTime.Hours, $runTime.Minutes, $runTime.Seconds, $runTime.Milliseconds);
}
function Get-AccessToken
{
	$Msg = "Getting access token..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg;
	$fabricUser = "fabric-installer";
	$scopes = "dos/metadata dos/metadata.serviceAdmin fabric/authorization.read";
	$url = "$($CONFIG.IDENTITY_SERVICE_URL)/connect/token";
	$body = @{
		client_id = "$fabricUser"
		grant_type = "client_credentials"
		scope	  = "$scopes"
		client_secret = $CONFIG.DECRYPTED_INSTALLER_SECRET
	};
	$Msg = "$(" " * 4)$($CONFIG.IDENTITY_SERVICE_URL)..."; Write-Host $Msg -ForegroundColor White -NoNewline; Write-Verbose $Msg;
	$accessTokenResponse = Invoke-RestMethod -Method Post -Uri $url -Body $body; $end = (Get-Date);
	$Msg = "Success"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg;
	return $accessTokenResponse.access_token;
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
			Write-Error $Error;
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
		$_marts = if ($dataMartIds) { Get-DosData -Uri "$($metadataServiceUrl)/DataMarts?`$filter=Id eq $($dataMartIds -join ' or Id eq ')" }
		else { Get-DosData -Uri "$($metadataServiceUrl)/DataMarts" };
		#region FUNCTIONS FOR EMPTY DATAMART OBJECT CREATION
		function CreateEmpty-DatamartObject
		{
			$datamart = New-Object PSObject;
			$datamart | Add-Member -Type NoteProperty -Name Id -Value $Null;
			$datamart | Add-Member -Type NoteProperty -Name Name -Value $Null;
			$datamart | Add-Member -Type NoteProperty -Name Description -Value $Null;
			$datamart | Add-Member -Type NoteProperty -Name DataMartType -Value $Null;
			$datamart | Add-Member -Type NoteProperty -Name IsHidden -Value $Null;
			$datamart | Add-Member -Type NoteProperty -Name Entities -Value @();
			$datamart | Add-Member -Type NoteProperty -Name Bindings -Value @();
			$datamart | Add-Member -Type NoteProperty -Name Notes -Value @();
			$datamart | Add-Member -Type NoteProperty -Name Permissions -Value @();
			
			return $datamart;
		}
		function CreateEmpty-PermissionObject
		{
			$permission = New-Object PSObject;
			$permission | Add-Member -Type NoteProperty -Name Permission -Value $Null;
			
			return $permission;
		}
		function CreateEmpty-NoteObject
		{
			$note = New-Object PSObject;
			$note | Add-Member -Type NoteProperty -Name Id -Value $Null;
			$note | Add-Member -Type NoteProperty -Name NoteType -Value $Null;
			$note | Add-Member -Type NoteProperty -Name NoteText -Value $Null;
			$note | Add-Member -Type NoteProperty -Name User -Value $Null;
			$note | Add-Member -Type NoteProperty -Name NoteTimestamp -Value $Null;
			
			return $note;
		}
		function CreateEmpty-EntityObject
		{
			$entity = New-Object PSObject;
			$entity | Add-Member -Type NoteProperty -Name Id -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name EntityName -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name DatabaseName -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name SchemaName -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name BusinessDescription -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name TechnicalDescription -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name IsPublic -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name AllowsDataEntry -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name LastSuccessfulLoadTimestamp -Value $Null;
			$entity | Add-Member -Type NoteProperty -Name Fields -Value @();
			$entity | Add-Member -Type NoteProperty -Name SourceEntities -Value @();
			$entity | Add-Member -Type NoteProperty -Name Notes -Value @();
			$entity | Add-Member -Type NoteProperty -Name Permissions -Value @();
			
			return $entity;
		}
		function CreateEmpty-FieldObject
		{
			$field = New-Object PSObject;
			$field | Add-Member -Type NoteProperty -Name Id -Value $Null;
			$field | Add-Member -Type NoteProperty -Name FieldName -Value $Null;
			$field | Add-Member -Type NoteProperty -Name BusinessDescription -Value $Null;
			$field | Add-Member -Type NoteProperty -Name TechnicalDescription -Value $Null;
			$field | Add-Member -Type NoteProperty -Name Status -Value $Null;
			$field | Add-Member -Type NoteProperty -Name DataType -Value $Null;
			$field | Add-Member -Type NoteProperty -Name SourceFields -Value @();
			$field | Add-Member -Type NoteProperty -Name Notes -Value @();
			$field | Add-Member -Type NoteProperty -Name Permissions -Value @();
			
			return $field;
		}
		function CreateEmpty-BindingObject
		{
			$binding = New-Object PSObject;
			$binding | Add-Member -Type NoteProperty -Name Id -Value $Null;
			$binding | Add-Member -Type NoteProperty -Name Name -Value $Null;
			$binding | Add-Member -Type NoteProperty -Name Description -Value $Null;
			$binding | Add-Member -Type NoteProperty -Name Classification -Value $Null;
			$binding | Add-Member -Type NoteProperty -Name Status -Value $Null;
			$binding | Add-Member -Type NoteProperty -Name BindingType -Value $Null;
			$binding | Add-Member -Type NoteProperty -Name UserDefinedSQL -Value $Null;
			$binding | Add-Member -Type NoteProperty -Name Notes -Value @();
			$binding | Add-Member -Type NoteProperty -Name Permissions -Value @();
			
			return $binding;
		}
		function CreateEmpty-SourceEntityObject
		{
			$sourceEntity = New-Object PSObject;
			$sourceEntity | Add-Member -Type NoteProperty -Name Id -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name EntityName -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name DatabaseName -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name SchemaName -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name BusinessDescription -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name TechnicalDescription -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name IsPublic -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name AllowsDataEntry -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name LastSuccessfulLoadTimestamp -Value $Null;
			$sourceEntity | Add-Member -Type NoteProperty -Name Permissions -Value @();
			
			return $sourceEntity;
		}
		function CreateEmpty-SourceFieldObject
		{
			$sourceField = New-Object PSObject;
			$sourceField | Add-Member -Type NoteProperty -Name Id -Value $Null;
			$sourceField | Add-Member -Type NoteProperty -Name FieldName -Value $Null;
			$sourceField | Add-Member -Type NoteProperty -Name BusinessDescription -Value $Null;
			$sourceField | Add-Member -Type NoteProperty -Name TechnicalDescription -Value $Null;
			$sourceField | Add-Member -Type NoteProperty -Name Permissions -Value @();
			
			return $sourceField;
		}
		#endregion
        #region ANCILLARY FUNCTIONS
		function Y
		{
			$true;
		}
		function N
		{
			$false;
		}
		function Create-Directory ($Dir)
		{
			If (!(Test-Path $Dir))
			{
				New-Item -ItemType Directory -Force -Path $Dir -ErrorAction Stop | Out-Null;
			}
		}
        function IndexOfAll($arr,$val)
        {
            $indexes = @();
            $i = 0;
            foreach($obj in $arr){
                if($obj -eq $val){
                    $indexes += $i;
                }
                $i++;
            }
            if(!$indexes){
                $indexes += -1;
            }            
            return $indexes;    
        }
		#endregion
	}
	process
	{
		Create-Directory -Dir $outputDirectory;
		
		$toProcess = $($_marts | Measure).Count;
		
		$Msg = "Getting data from $($CONFIG.METADATA_SERVICE_URL)..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg;
		
		$i = 0;
		foreach ($_mart in $_marts)
		{
			$i++;
			$start = (Get-Date);
			$Msg = "$(" " * 4)[$($i)/$($toProcess)] $($_mart.Name)..."; Write-Host $Msg -ForegroundColor White -NoNewline; Write-Verbose $Msg;
			
			#region CREATE A RAW OBJECT OF THE DATA MART AS IT CAME FROM METADATA SERVICE
			$_dataMart = $_mart;
			$_dataMart | Add-Member -Type NoteProperty -Name Entities -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Entities");
			$_dataMart | Add-Member -Type NoteProperty -Name Bindings -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Bindings");
			#$_dataMart | Add-Member -Type NoteProperty -Name Connections -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Connections");
			#$_dataMart | Add-Member -Type NoteProperty -Name RelatedResources -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/RelatedResources");
			$_dataMart | Add-Member -Type NoteProperty -Name Notes -Value @(Get-DosData -Uri "$($metadataServiceUrl)/Notes?`$filter=(AnnotatedObjectId eq $($_dataMart.Id) and AnnotatedObjectType eq 'DataMart')");
			foreach ($_entity in $_dataMart.Entities)
			{
				$_entity | Add-Member -Type NoteProperty -Name Fields -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Entities($($_entity.Id))/Fields");
				#$_entity | Add-Member -Type NoteProperty -Name Indexes -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Entities($($_entity.Id))/Indexes");
				$_entity | Add-Member -Type NoteProperty -Name Notes -Value @(Get-DosData -Uri "$($metadataServiceUrl)/Notes?`$filter=(AnnotatedObjectId eq $($_entity.Id) and AnnotatedObjectType eq 'Entity')");
			}
			foreach ($_binding in $_dataMart.Bindings)
			{
				$_binding | Add-Member -Type NoteProperty -Name BindingDependencies -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Bindings($($_binding.Id))/BindingDependencies");
				#$_binding | Add-Member -Type NoteProperty -Name IncrementalConfigurations -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Bindings($($_binding.Id))/IncrementalConfigurations");
				#$_binding | Add-Member -Type NoteProperty -Name ObjectRelationships -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Bindings($($_binding.Id))/ObjectRelationships");
				$_binding | Add-Member -Type NoteProperty -Name Notes -Value @(Get-DosData -Uri "$($metadataServiceUrl)/Notes?`$filter=(AnnotatedObjectId eq $($_binding.Id) and AnnotatedObjectType eq 'Binding')");
				
				foreach ($_bindingDependency in $_binding.BindingDependencies)
				{
					$_bindingDependency | Add-Member -Type NoteProperty -Name FieldMappings -Value @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Bindings($($_binding.Id))/BindingDependencies($($_bindingDependency.Id))/FieldMappings");
				}
			}
			
			foreach ($_field in $_entity.Fields)
			{
				$_field | Add-Member -Type NoteProperty -Name Notes -Value @(Get-DosData -Uri "$($metadataServiceUrl)/Notes?`$filter=(AnnotatedObjectId eq $($_field.Id) and AnnotatedObjectType eq 'Field')");
			}
			#$_dataMart | ConvertTo-Json -Depth 100 -Compress | Out-File "$($outputDirectory)\$($_dataMart.Id)_datamart.json" -Encoding ascii -Force | Out-Null;
			#endregion

			#region CREATE A NEW ELASTIC SEARCH VERSION OF THE DATA MART
			$datamart = CreateEmpty-DatamartObject;			
			$datamart.Id = $_dataMart.Id;
			$datamart.Name = $_dataMart.Name;
			$datamart.Description = $_dataMart.Description;
			$datamart.DataMartType = $_dataMart.DataMartType;
			$datamart.IsHidden = & $_dataMart.IsHidden;

			#Bindings
			foreach($_binding in $_dataMart.Bindings)
			{
			    $binding = CreateEmpty-BindingObject;
			    $binding.Id = $_binding.Id;
			    $binding.Name = $_binding.Name;
			    $binding.Description = $_binding.Description;
			    $binding.Classification = $_binding.Classification;
			    $binding.Status = $_binding.Status;
			    $binding.BindingType = $_binding.BindingType;
			    $binding.UserDefinedSQL = try{$_binding.AttributeValues[$_binding.AttributeValues.AttributeName.IndexOf('UserDefinedSQL')].AttributeValue}catch{$null};

                #Notes
                foreach($_bindingNote in $_binding.Notes)
                {
                    $bindingNote = CreateEmpty-NoteObject;
			        $bindingNote.Id = $_bindingNote.Id;
			        $bindingNote.NoteType = $_bindingNote.NoteType;
			        $bindingNote.NoteText = $_bindingNote.NoteText;
			        $bindingNote.User = $_bindingNote.User;
			        $bindingNote.NoteTimestamp = $_bindingNote.NoteTimestamp;

                    $binding.Notes += $bindingNote;
                }

                <#Permissions
                #$bindingPermission = CreateEmpty-PermissionObject;
                #$binding.Permissions += $bindingPermission;
                #>

			    $dataMart.Bindings += $binding;
			}

			#Entities
			foreach($_entity in $_dataMart.Entities)
			{
			    $entity = CreateEmpty-EntityObject;
			    $entity.Id = $_entity.Id;
			    $entity.EntityName = $_entity.EntityName;
			    $entity.DatabaseName = try{$_entity.AttributeValues[$_entity.AttributeValues.AttributeName.IndexOf('DatabaseName')].AttributeValue}catch{$null};
			    $entity.SchemaName = try{$_entity.AttributeValues[$_entity.AttributeValues.AttributeName.IndexOf('SchemaName')].AttributeValue}catch{$null};
			    $entity.BusinessDescription = $_entity.BusinessDescription;
			    $entity.TechnicalDescription = $_entity.TechnicalDescription;
			    $entity.IsPublic = $_entity.IsPublic;
			    $entity.AllowsDataEntry = $_entity.AllowsDataEntry;
			    $entity.LastSuccessfulLoadTimestamp = $_entity.LastSuccessfulLoadTimestamp;

			    #SourceEntities
                #$_dentinationEntityIndexes = IndexOfAll -arr $_dataMart.Bindings.DestinationEntityId -val ;
                $sourceBindings = @(Get-DosData -Uri "$metadataServiceUrl/DataMarts($($_dataMart.Id))/Bindings?`$filter=DestinationEntityId eq $($_entity.Id)");
                $_sourceEntityIds = ($_dataMart.Bindings | Where-Object {$_.Id -in $sourceBindings.Id}).BindingDependencies | Select-Object SourceEntityId -Unique;

                foreach($_sourceEntityId in $_sourceEntityIds)
                {
                    $_sourceEntity = Get-DosData -Uri "$metadataServiceUrl/Entities($($_sourceEntityId.SourceEntityId))"
                    
			        $sourceEntity = CreateEmpty-SourceEntityObject;
			        $sourceEntity.Id = $_sourceEntity.Id;
			        $sourceEntity.EntityName = $_sourceEntity.EntityName;
			        $sourceEntity.DatabaseName = try{$_sourceEntity.AttributeValues[$_sourceEntity.AttributeValues.AttributeName.IndexOf('DatabaseName')].AttributeValue}catch{$null};
			        $sourceEntity.SchemaName = try{$_sourceEntity.AttributeValues[$_sourceEntity.AttributeValues.AttributeName.IndexOf('SchemaName')].AttributeValue}catch{$null};
			        $sourceEntity.BusinessDescription = $_sourceEntity.BusinessDescription;
			        $sourceEntity.TechnicalDescription = $_sourceEntity.TechnicalDescription;
			        $sourceEntity.IsPublic = $_sourceEntity.IsPublic;
			        $sourceEntity.AllowsDataEntry = $_sourceEntity.AllowsDataEntry;
			        $sourceEntity.LastSuccessfulLoadTimestamp = $_sourceEntity.LastSuccessfulLoadTimestamp;
                
			        <#Permissions
                    #$sourceEntityPermission = CreateEmpty-PermissionObject;
                    #$sourceEntity.Permissions += $sourceEntityPermission;
                    #>
                
			        $entity.SourceEntities += $sourceEntity;
                }

			    #Fields
			    foreach($_field in $_entity.Fields)
			    {
			        $field = CreateEmpty-FieldObject;
			        $field.Id = $_field.Id;
			        $field.FieldName = $_field.FieldName;
			        $field.BusinessDescription = $_field.BusinessDescription;
			        $field.TechnicalDescription = $_field.TechnicalDescription;
			        $field.Status = $_field.Status;
			        $field.DataType = $_field.DataType;

			        #SourceFields
                    #$_sourceFieldIds = $_dataMart.Bindings[$_dentinationEntityIndexes].BindingDependencies.FieldMappings[(IndexOfAll -arr $_dataMart.Bindings[$_dentinationEntityIndexes].BindingDependencies.FieldMappings.DestinationFieldId -val $_field.Id)] | Select-Object SourceFieldId -Unique;
                    #
                    #foreach($_sourceFieldId in $_sourceFieldIds)
                    #{
                    #    $_sourceField = Get-DosData -Uri "$metadataServiceUrl/Fields($($_sourceFieldId.SourceFieldId))"
                    #
			        #    $sourceField = CreateEmpty-SourceFieldObject;
			        #    $sourceField.Id = $_sourceField.Id;
			        #    $sourceField.FieldName = $_sourceField.FieldName;
			        #    $sourceField.BusinessDescription = $_sourceField.BusinessDescription;
			        #    $sourceField.TechnicalDescription = $_sourceField.TechnicalDescription;
                    #
			        #    <#Permissions
                    #    #$sourceFieldPermission = CreateEmpty-PermissionObject;
                    #    #$sourceField.Permissions += $sourceFieldPermission;
                    #    #>
                    #
			        #    $field.SourceFields += $sourceField;
                    #}

			        #Notes
                    foreach($_fieldNote in $_field.Notes)
                    {
                        $fieldNote = CreateEmpty-NoteObject;
			            $fieldNote.Id = $_fieldNote.Id;
			            $fieldNote.NoteType = $_fieldNote.NoteType;
			            $fieldNote.NoteText = $_fieldNote.NoteText;
			            $fieldNote.User = $_fieldNote.User;
			            $fieldNote.NoteTimestamp = $_fieldNote.NoteTimestamp;

                        $field.Notes += $fieldNote;
                    }

			        <#Permissions
                    #$fieldPermission = CreateEmpty-PermissionObject;
                    #$field.Permissions += $fieldPermission;
                    #>
			    
			        $entity.Fields += $field;        
			    }


			    #Notes
                foreach($_entityNote in $_entity.Notes)
                {
                    $entityNote = CreateEmpty-NoteObject;
			        $entityNote.Id = $_entityNote.Id;
			        $entityNote.NoteType = $_entityNote.NoteType;
			        $entityNote.NoteText = $_entityNote.NoteText;
			        $entityNote.User = $_entityNote.User;
			        $entityNote.NoteTimestamp = $_entityNote.NoteTimestamp;

                    $entity.Notes += $entityNote;
                }

			    <#Permissions
                #$entityPermission = CreateEmpty-PermissionObject;
                #$entity.Permissions += $entityPermission;
                #>
			
			    $dataMart.Entities += $entity;
			}

			#Notes
            foreach($_dataMartNote in $_dataMart.Notes)
            {
                $dataMartNote = CreateEmpty-NoteObject;
			    $dataMartNote.Id = $_dataMartNote.Id;
			    $dataMartNote.NoteType = $_dataMartNote.NoteType;
			    $dataMartNote.NoteText = $_dataMartNote.NoteText;
			    $dataMartNote.User = $_dataMartNote.User;
			    $dataMartNote.NoteTimestamp = $_dataMartNote.NoteTimestamp;

                $dataMart.Notes += $dataMartNote;
            }


			<#Permissions
            #$dataMartPermission = CreateEmpty-PermissionObject;
            #$dataMart.Permissions += $dataMartPermission;
            #>


			$dataMart | ConvertTo-Json -Depth 100 -Compress | Out-File "$($outputDirectory)\$($_dataMart.Id)_datamart_elastic_doc.json" -Encoding ascii -Force;
			#endregion
			
			$end = (Get-Date);
			$Msg = "Success ~ $(Get-Timepsan -start $start -end $end)"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg;
		}
	}
}


#get the token and update the configuration file
$CONFIG | Add-Member -Type NoteProperty -Name TOKEN -Value (Get-AccessToken);
foreach($property in $CONFIG.FILES.PSObject.Properties){
    $property.Value = $property.Value.Replace("{{ROOT}}",$CONFIG.FILES.ROOT)
}

#get all of the data
Get-Datamarts -metadataServiceUrl $CONFIG.METADATA_SERVICE_URL -outputDirectory $CONFIG.FILES.OUTPUT_DIRECTORY -dataMartIds $CONFIG.DATAMARTS;

#setup the atlas mappings
$Msg = "Updating elastic...($($CONFIG.ELASTIC.SERVICE_URL)/$($CONFIG.ELASTIC.INDEX)/$($CONFIG.ELASTIC.MAPPING))..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg;
$mappings = Get-Content $CONFIG.FILES.MAPPING_FILE;

try
{
    #check if this index exists already
    Invoke-RestMethod -Uri "$($CONFIG.ELASTIC.SERVICE_URL)/$($CONFIG.ELASTIC.INDEX)" -ContentType "application/json" -Method "HEAD" | Out-Null
    $Msg = "$(" " * 4)Deleting ""$($CONFIG.ELASTIC.INDEX)"" index because one already existed..."; Write-Host $Msg -ForegroundColor White -NoNewline; Write-Verbose $Msg;
    Invoke-RestMethod -Uri "$($CONFIG.ELASTIC.SERVICE_URL)/$($CONFIG.ELASTIC.INDEX)" -ContentType "application/json" -Method "DELETE" | Out-Null
    $Msg = "Success"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg;
}
catch
{
}
Invoke-RestMethod -Uri "$($CONFIG.ELASTIC.SERVICE_URL)/$($CONFIG.ELASTIC.INDEX)" -ContentType "application/json" -Method "PUT" -Body $mappings | Out-Null
$Msg = "$(" " * 4)Creating ""$($CONFIG.ELASTIC.INDEX)"" with mappings..."; Write-Host $Msg -ForegroundColor White -NoNewline; Write-Verbose $Msg;
$Msg = "Success"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg;


#load all of the data
$Msg = "Loading data into ElasticSearch...($($CONFIG.ELASTIC.SERVICE_URL)/$($CONFIG.ELASTIC.INDEX)/$($CONFIG.ELASTIC.MAPPING))..."; Write-Host $Msg -ForegroundColor Gray; Write-Verbose $Msg;
$dataMartFiles = Get-ChildItem $CONFIG.FILES.OUTPUT_DIRECTORY -Include *_datamart_elastic_doc.json -Recurse;
foreach($dataMartFile in $dataMartFiles){
    $id = $dataMartFile.Name.Split("_")[0];        
    $Msg = "$(" " * 4)_id : $($id)..."; Write-Host $Msg -ForegroundColor White -NoNewline; Write-Verbose $Msg;
    $data = Get-Content $dataMartFile;
    Invoke-RestMethod -Uri "$($CONFIG.ELASTIC.SERVICE_URL)/$($CONFIG.ELASTIC.INDEX)/$($CONFIG.ELASTIC.MAPPING)/$($id)" -ContentType "application/json" -Method "POST" -Body $data | Out-Null
    $Msg = "Success"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg;
}

$end = (Get-Date);
$Msg = "`nComplete ~ TOTAL DURATION: $(Get-Timepsan -start $start -end $end)"; Write-Host $Msg -ForegroundColor Green; Write-Verbose $Msg;