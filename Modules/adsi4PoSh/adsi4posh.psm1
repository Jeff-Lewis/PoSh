function Get-DefaultDomainNamingContext {
	[CmdletBinding()]
	param()
	process {
		return [adsi]('LDAP://' + ([adsi]'LDAP://rootdse').defaultNamingContext);
	}
}

function Search-ADSI {
	[CmdletBinding()]
	param(
		[Parameter()]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry,

		<#
		Строка фильтра поиска в формате LDAP; например "(objectClass=user)".
		По умолчанию используется фильтр "(objectClass=*)", задающий извлечение всех объектов.

		В отношении фильтров действуют следующие правила:
		Строка должна быть заключена в скобки.
		В выражениях можно использовать операторы отношений: <, <=, =, >= и >.
		Например: "(objectClass=user)".
		Другой пример: "(lastName>=Davis)".
		Допускаются составные выражения, образуемые с помощью префиксных операторов & и |.
		Например: "(&(objectClass=user)(lastName= Davis))".
		Другой пример: "(&(objectClass=printer)(|(building=42)(building=43)))".
		Если фильтр содержит атрибут типа ADS_UTC_TIME, его значение должно иметь формат yyyymmddhhmmssZ, 
		где y, m, d, h, m и s обозначают соответственно год, месяц, день, часы, минуты и секунды.
		Секунды (ss) указывать необязательно.Последняя буква Z означает, что значение задано без учета разницы 
		во времени.В данном формате: "10:20:00 A.M. 13 мая 1999 г." будет указано как "19990513102000Z".
		Обратите внимание, что доменные службы Active Directory хранят данные даты и времени в соответствии с 
		универсальным глобальным временем (по Гринвичу).Если время указывается без учета разницы во времени, 
		это означает, что оно определяется как время по Гринвичу.
		Если пользователь находится в часовом поясе, отличном от пояса универсального глобального времени, он может 
		задать местное время, добавив к значению разницу с универсальным глобальным временем (вместо буквы Z).Разница 
		рассчитывается следующим образом: разница = глобальное универсальное время – местное время.Чтобы указать разницу 
		во времени, используйте следующий формат: yyyymmddhhmmss[+/-]hhmm.Например: "8:52:58 P.M. 23 марта 1999 года по 
		новозеландскому времени (разница — 12 часов) будет записано как "19990323205258.0+1200".
		Дополнительные сведения о формате строки поиска LDAP приведены в разделе "Синтаксис фильтра поиска" в библиотеке 
		MSDN Library по адресу http://msdn.microsoft.com/ru-ru/library/default.aspx.
		#>
		[Parameter()]
		[string]$filter = '(objectClass=*)',

		<#
		Base - Ограничивает поиск базовым объектом.Результат содержит один объект (максимум). 
		Если свойство AttributeScopeQuery задано для поиска, для области поиска следует задать Base.

		OneLevel - Выполняется поиск ближайших дочерних объектов базового объекта, исключая сам базовый объект.

		Subtree - При поиске просматривается все поддерево, включая базовый объект и все его дочерние объекты.
		Если область поиска каталога не указана, выполняется поиска типа Subtree.
		#>
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
		[string]$attributeScopeQuery

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

		$findArr = $null;
		if ($findAll.IsPresent) {
			return $findArr = $searcher.FindAll();
		}
		else {
			return $findArr = $searcher.FindOne();
		}
	}
}

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

function Get-ADSIDirectoryMember {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true)]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry
	)	

	process {
		return Search-ADSI -directoryEntry $directoryEntry -searchScope Base -attributeScopeQuery 'Member' -findAll;
	}
}

function Get-ADSIDirectoryMemberOf {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true)]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry
	)

	process {
		return Search-ADSI -directoryEntry $directoryEntry -searchScope Base -attributeScopeQuery 'MemberOf' -findAll;
	}
}

function Get-ADSIReleation {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true)]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry,

		[Parameter()]
		[string]$property,

		[Parameter()]
		[string]$filter = '(objectClass=*)'
	)
		
	process {
		return (Search-ADSI -directoryEntry $directoryEntry -searchScope	Base -attributeScopeQuery $property -filter $filter -findAll | 
			Get-ADSIDirectoryEntry);
	}
}

function Get-ADSIGroupMemberEntry {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true)]
		[System.DirectoryServices.DirectoryEntry]$directoryEntry,

		[Parameter()]
		[string]$groupName
	)
		
	process {
		return (Search-ADSI -directoryEntry $directoryEntry -filter "(&(name=$groupName)(objectClass=group))" | 
			Get-ADSIDirectoryEntry | 
				Get-ADSIReleation -property 'Member');
	}
}
