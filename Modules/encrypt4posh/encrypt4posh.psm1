#Расшифровывание пароля
function ConvertTo-PlainPass {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$encryptedPass
	)

	process {
		if(![String]::IsNullOrEmpty($encryptedPass)){
			#Генерим ключ шифрования
			$encryptionKey = Get-EncryptionKey;
			#Конвертируем полученый шифрованный пароль в тип SecureString
			$securePass = ConvertTo-SecureString -Key $encryptionKey  $encryptedPass;
			#Здесь есть несколько путей добывания обычного string из SecureString, ниже выбран самый короткий.
			$insecurePass = (New-Object System.Management.Automation.PSCredential 'N/A',$securePass).GetNetworkCredential().Password
			#Возвращаем полученый пароль
			return $insecurePass;
		}
		else {
			return $null;
		}
	}
}

#Генерим ключ для шифрования/расшифровки
#TODO Написать нормальный генератор, желательно на основе "seed-ов"
function Get-EncryptionKey{
	begin{
		#Ключ представляет из себя массив из 16, 32 или 64 байтов
		$encKey = New-Object Byte[] 32;
	}
	process{
		#Генерим 32 байта в массив.
		for($i = 0; $i -lt $encKey.length; $i++){
			$encKey[$i] = ($i*8+11)-($i*2);
		}
		return $encKey;
	}
}

#Шифрование пароля
function ConvertTo-EncryptedKey{
		[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$plainPass
	)
	begin{
		#Генерим ключ
		$encryptionKey = Get-EncryptionKey;
	}
	process{
		#Пароль превращается в SecureString, после чего из secureString добывается String с зашифрованным паролем.
		$secString = ConvertTo-SecureString -AsPlainText -Force $plainPass;
		$secKey = ConvertFrom-SecureString -Key $encryptionKey $secString;
		return $secKey;
	}
}