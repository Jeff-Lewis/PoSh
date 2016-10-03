<#
.SYNOPSIS
Get the default domain naming context.
.DESCRIPTION
Get DirectoryEntry from rootDSE.
.INPUTS
You can`t pipe objects to this cmdlet
.OUTPUTS
System.DirectoryServices.DirectoryEntry
.EXAMPLE
$root = Get-DefaultDomainNamingContext;
#>
function Get-DefaultDomainNamingContext {
	[CmdletBinding()]
	param()
	process {
		return [adsi]('LDAP://' + ([adsi]'LDAP://rootdse').defaultNamingContext);
	}
}

<#
.SYNOPSIS
Search object in domain
.DESCRIPTION
Executes the search and returns a collection of the entries or only the first entry that are found.
.PARAMETER directoryEntry
The node in the Active Directory Domain Services hierarchy where the search starts.
.PARAMETER filter
Sets a value indicating the Lightweight Directory Access Protocol (LDAP) format filter string.
By default (objectClass=*) - it is all objects find
NOTES
The filter uses the following guidelines:
The string must be enclosed in parentheses.
Expressions can use the relational operators: <, <=, =, >=, and >.An example is "(objectClass=user)".Another example is "(lastName>=Davis)".
Compound expressions are formed with the prefix operators & and |.An example is "(&(objectClass=user)(lastName= Davis))".Another example is "(&(objectClass=printer)(|(building=42)(building=43)))".
When the filter contains an attribute of ADS_UTC_TIME type, its value must be of the yyyymmddhhmmssZ format where y, m, d, h, m, and s stand for year, month, day, hour, minute, and second, respectively.The seconds (ss) value is optional.The final letter Z means there is no time differential.In this format, "10:20:00 A.M. May 13, 1999" becomes "19990513102000Z".Note that Active Directory Domain Services stores date and time as Coordinated Universal Time (Greenwich Mean Time).If you specify a time with no time differential, you are specifying the time in GMT time.
If you are not in the Coordinated Universal Time time zone, you can add a differential value to the Coordinated Universal Time (instead of specifying Z) to specify a time according to your time zone.The differential is based on the following: differential = Coordinated Universal Time- Local.To specify a differential, use the following format: yyyymmddhhmmss[+/-]hhmm.For example, "8:52:58 P.M. March 23, 1999" New Zealand Standard Time (the differential is 12 hours) is specified as "19990323205258.0+1200".
For more information about the LDAP search string format, see "Search Filter Syntax" in the MSDN Library at http://msdn.microsoft.com/library.
.PARAMETER searchScope
Sets a value indicating the scope of the search that is observed by the server.
NOTES
Base - Limits the search to the base object. The result contains a maximum of one object. When the AttributeScopeQuery property is specified for a search, the scope of the search must be set to Base.
OneLevel - Searches the immediate child objects of the base object, excluding the base object.
Subtree - Searches the whole subtree, including the base object and all its child objects. If the scope of a directory search is not specified, a Subtree type of search is performed.
.PARAMETER properties
Sets a value indicating the list of properties to retrieve during the search.
NOTES
The default is an empty object StringCollection, which corresponds to the recovery of all the properties.
.PARAMETER propertyNamesOnly
Sets a value indicating whether the search retrieves only the names of attributes to which values have been assigned.
.PARAMETER findAll
Switch to find a collection  of the entries in active directory.
.PARAMETER attributeScopeQuery
Sets the LDAP display name of the distinguished name attribute to search in. Only one attribute can be used for this type of search.
.PARAMETER pageSize
Sets a value indicating the page size in a paged search.
.INPUTS 
You can pipe objects to this cmdlet
.OUTPUTS
System.DirectoryServices.SearchResultCollection
.EXAMPLE
Search-ADSI -filter "(user=test123)" -findAll
#>
function Search-ADSI {
	[CmdletBinding()]
	param(
		[Parameter()]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry,
		
		[Parameter(ValueFromPipeline = $true)]
		[string]$filter = '(objectClass=*)',

		[parameter()]
		[ValidateSet('Base', 'OneLevel', 'Subtree')]
		[string]$searchScope = 'Subtree',

		<#
		По умолчанию используется пустой объект StringCollection, что соответствует извлечению всех свойств.

		Чтобы извлечь определенные свойства, добавьте их в эту коллекцию, прежде чем начинать поиск.
		Например, searcher.PropertiesToLoad.Add("phone"); добавит свойство телефона к списку свойств для извлечения в ходе поиска.
		Свойство "ADsPath" всегда извлекается в ходе поиска.В Windows 2000 и более ранних операционных системах учетная запись, 
		выполняющая поиск, должна быть членом группы "Администраторы" для извлечения свойства ntSecurityDescriptor.Если это не так, 
		для ntSecurityDescriptor будет возвращено значение свойства null.
		Дополнительные сведения см. в разделе "NT-Security-Descriptor" библиотеки MSDN по адресу http://msdn.microsoft.com/ru-ru/library/default.aspx.
		#>
		[parameter()]
		[string[]]$properties,

		[parameter()]
		[switch]$propertyNamesOnly,

		[parameter()]
		[switch]$findAll,

		[parameter()]
		[string]$attributeScopeQuery,

		[parameter()]
		[int]$pageSize = 1000

	)

	process {
		$searcher = $null;
		if($directoryEntry -ne $null) {
			$searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher($directoryEntry);
		}
		else {
			$searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher(Get-DefaultDomainNamingContext);
		}

		$searcher.SearchScope = $searchScope;
		if (![System.String]::IsNullOrEmpty($attributeScopeQuery)) {
			$searcher.SearchScope = 'Base';
			$searcher.AttributeScopeQuery = $attributeScopeQuery;
		}
		$searcher.Asynchronous = $false;
		$properties | ForEach-Object -Process{
			$searcher.PropertiesToLoad.Add($_);
		}
		$searcher.PropertyNamesOnly = $propertyNamesOnly.IsPresent;

		$searcher.Filter = $filter;
		$searcher.PageSize = $pageSize;

		$findArr = $null;
		if ($findAll.IsPresent) {
			return $findArr = $searcher.FindAll();
		}
		else {
			return $findArr = $searcher.FindOne();
		}
	}
}

<#
.SYNOPSIS
Get directory entry object
.DESCRIPTION
Get directory entry object from search result.
.PARAMETER object
Object include System.DirectoryServices.SearchResult as element
.INPUTS
You can pipe objects in this cmdlet
.OUTPUTS
System.DirectoryServices.DirectoryEntry
.EXAMPLE
Search-ADSI -filter "(user=test123)" -findAll | Get-ADSIDirectoryEntry
#>
function Get-ADSIDirectoryEntry {
	[CmdletBinding()]
	param(
		[parameter(ValueFromPipeline = $true)]
		[System.Object]$object
	)
	
	begin {
		$array = @();
	}
	
	process {
		$object | ForEach-Object -Process {
			if ($_ -is [System.DirectoryServices.SearchResult]) {
				$array = $array + $_.GetDirectoryEntry();
			}
		}
	}
	
	end {
		return $array;
	}
}

<#
.SYNOPSIS
Get the entries that are member property of the Active Directories object
.DESCRIPTION
It works by finding the Search-Root directory entry and examining one of its attributes.
.PARAMETER directoryEntry
Directory entry 
.PARAMETER pageSize
Sets a value indicating the page size in a paged search.
.INPUTS
You can pipe DirectoryEntry to this cmdlet
.OUTPUTS
System.DirectoryServices.SearchResultCollection
.EXAMPLE
Search-ADSI -filter "(name=STR-GR-QUIKeFX-IFT)" -searchScope Subtree -findAll | Get-ADSIDirectoryEntry | Get-ADSIDirectoryMember
#>
function Get-ADSIDirectoryMember {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true)]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry,

		[Parameter()]
		[int]$pageSize
	)	

	process {
		return Search-ADSI -directoryEntry $directoryEntry -searchScope Base -attributeScopeQuery 'Member' -findAll -pageSize $pageSize;
	}
}

<#
.SYNOPSIS
Get the entries that are memberOf property of the Active Directories object
.DESCRIPTION
It works by finding the Search-Root directory entry and examining one of its attributes.
.PARAMETER directoryEntry
Directory entry 
.PARAMETER pageSize
Sets a value indicating the page size in a paged search.
.INPUTS
You can pipe DirectoryEntry to this cmdlet
.OUTPUTS
System.DirectoryServices.SearchResultCollection
.EXAMPLE
Search-ADSI -filter "(name=sbt-chistyakov-vv)" | Get-ADSIDirectoryEntry | Get-ADSIDirectoryMemberOf
#>
function Get-ADSIDirectoryMemberOf {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true)]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry,

		[parameter()]
		[int]$pageSize
	)

	process {
		return Search-ADSI -directoryEntry $directoryEntry -searchScope Base -attributeScopeQuery 'MemberOf' -findAll -pageSize $pageSize;
	}
}

<#
.SYNOPSIS
Get relation of objects.
.DESCRIPTION
Getting involved of assets Directory objects that are stored in the specified object property.
.PARAMETER directoryEntry
Directory entry
.PARAMETER property
Attribute name  of object.
.PARAMETER filter
Filter of finding objects.
.PARAMETER pageSize
Sets a value indicating the page size in a paged search. 
.INPUTS
You can pipe DirecroryEntry objects to cmdlt/ 
.OUTPUTS
System.DirectoryServices.DirectoryEntry
.EXAMPLE
Search-ADSI -filter "(name=STR-GR-QUIKeFX-IFT)" | Get-ADSIDirectoryEntry  | Get-ADSIReleation -property 'member'
#>
function Get-ADSIReleation {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true)]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry,

		[Parameter()]
		[string]$property,

		[Parameter()]
		[string]$filter = '(objectClass=*)',

		[Parameter()]
		[int]$pageSize
	)
		
	process {
		return (Search-ADSI -directoryEntry $directoryEntry -searchScope	Base -attributeScopeQuery $property -filter $filter -findAll -pageSize $pageSize | 
			Get-ADSIDirectoryEntry);
	}
}

<#
.SYNOPSIS
Get member entries in group
.DESCRIPTION
Search objects in member properties of Active Directory group
.PARAMETER groupName
Group name.
.PARAMETER pageSize
Sets a value indicating the page size in a paged search.
.INPUTS
You can pipe groupname  to this cmdlet
.OUTPUTS
System.DirectoryServices.DirectoryEntry
.EXAMPLE
Get-ADSIGroupMemberEntry -groupName 'str-gr-quikefx-ift'
#>
function Get-ADSIGroupMemberEntry {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true)]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry,

		[Parameter()]
		[string]$groupName,

		[Parameter()]
		[int]$pageSize
	)
		
	process {
		return (Search-ADSI -directoryEntry $directoryEntry -filter "(&(name=$groupName)(objectClass=group))"  -pageSize $pageSize| 
			Get-ADSIDirectoryEntry | 
				Get-ADSIReleation -property 'Member');
	}
}
