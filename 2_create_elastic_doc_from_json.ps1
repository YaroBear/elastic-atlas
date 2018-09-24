Set-Location C:\Users\spencer.nicol\Desktop\metadata

$rawDataMarts = Get-Content -Path .\datamart_1103.json | ConvertFrom-Json

#region FUNCTIONS FOR DATAMART OBJECT CREATION
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
{ $true
}
function N
{ $false
}
#endregion

foreach($rawDataMart in $rawDataMarts)
{
	$datamart = New-Object PSObject;
	$datamart | Add-Member -Type NoteProperty -Name data-mart -Value (CreateEmpty-DatamartObject);

    $dataMart.'data-mart'.name = $rawDataMart.Name;
    $dataMart.'data-mart'.description = $rawDataMart.Description;
    $dataMart.'data-mart'.type = $rawDataMart.DataMartType;
    $dataMart.'data-mart'.'is-hidden' = & $rawDataMart.IsHidden;

    foreach($rawEntity in $rawDataMart.Entities[0])
    {
	    $entity = CreateEmpty-EntityObject;
        $entity.name = $rawEntity.EntityName;
        $entity.'business-description' = $rawEntity.BusinessDescription;
        $entity.'technical-description' = $rawEntity.TechnicalDescription;
        $entity.'is-public' = $rawEntity.IsPublic;
        $entity.'allows-data-entry' = $rawEntity.AllowsDataEntry;
        $entity.'last-successful-load' = $rawEntity.LastSuccessfulLoadTimestamp;
        $entity.database = $rawEntity.AttributeValues[$rawEntity.AttributeValues.AttributeName.IndexOf('DatabaseName')].AttributeValue;
        $entity.schema = $rawEntity.AttributeValues[$rawEntity.AttributeValues.AttributeName.IndexOf('SchemaName')].AttributeValue;

        foreach($rawField in $rawEntity.Fields)
        {
            $field = CreateEmpty-FieldObject;
            $field.name = $rawField.FieldName;
            $field.'business-description' = $rawField.BusinessDescription;
            $field.'technical-description' = $rawField.TechnicalDescription;
            $field.status = $rawField.Status;
            $field.'data-type' = $rawField.DataType;

            $entity.fields += $field;        
        }

        $dataMart.'data-mart'.entities += $entity;
    }
}

$dataMart | ConvertTo-Json -Depth 100 | Out-File "C:\Users\spencer.nicol\Desktop\metadata\elastic_doc.json" -Force