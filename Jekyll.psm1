$script:jekylljobs = @()
[string[]] $script:requiredPaths = @("ruby\bin","devkit\bin","Python\App","devkit\mingw\bin","curl\bin")
[string] $script:certFilePath = "curl\bin\cacert.pem"
[string] $script:loadedEnvironment = "none"



#region Internal Functions

function Update-Path {
  <#
    .SYNOPSIS
      Adds an array of directories to the Current Path
    .DESCRIPTION
      Add an array of directories to the current path. This is useful for
      temporary changes to the path or, when run from your
      profile, for adjusting the path within your powershell
      prompt. The changes to your path are only within
      the contect of this PowerShell Session.
      Inspired by https://github.com/adrianhall
    .EXAMPLE
      Update-Path -Paths @("C:\Program Files\Notepad++","C:/Temp/Notes")
    .PARAMETER Paths
      The array of directories to add to the current path.
  #>

  [CmdletBinding()]
  param (
    [Parameter(
      Mandatory=$True,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True,
      HelpMessage='Array of Directories to add to the current path')]
    [string[]]$Paths
  )
  PROCESS {
    $expandedPath = $env:PATH.Split(';')

    foreach ($dir in $Paths) {
      if (-not (Test-Path $dir -PathType Container)) {
        Write-Verbose "$dir can not be found in the filesystem"
      } else {
        if ($expandedPath -contains $dir) {
        Write-Verbose "$dir is already in PATH"
        } else {
          $expandedPath += $dir
        }
      }
    }
    $env:PATH = [String]::Join(';', $expandedPath)
  }
}

Function Add-JekyllPaths([string] $portableJekyllRoot){

         $paths = Get-JekyllPaths $portableJekyllRoot
         Update-Path -Paths $paths
        $env:SSL_CERT_FILE = (Join-Path $portableJekyllRoot $Script:certFilePath)
}

Function Get-JekyllPaths([string] $portableJekyllRoot){
        $paths = @()
        $Script:requiredPaths | ForEach-Object { $paths+= (Join-Path $portableJekyllRoot  $_)}
        return $paths
}

Function Test-JekyllEnvironment([string] $EnvironmentRoot){

        $validRoot = $true
        $paths =  Get-JekyllPaths $portableJekyllRoot

        $resourceFound = Test-Path -Path $paths -PathType Container
        $resourceFound += Test-Path -Path (Join-Path $portableJekyllRoot $Script:certFilePath) -PathType Leaf

        $resourceFound | ForEach-Object {if($_ -eq $false){$validRoot = $false}}

        return $validRoot
}

#endregion Internal Functions


<#
 .Synopsis
  Registers a Portable Jekyll install for later use.

 .Description
  Validates and registers a Portable Jekyll install location for
  to allow easy invocation later. The location is stored in the
  Environment varible PortableJekyllRoot.

 .Parameter PathToProtableJekyllRoot
    The root directory of a portable jekyll install.

.Parameter AllUsers
    If the AllUsers flag is use the Jekyll location is stored in a
    Machine Environment varible. Otherwise a User level varible is used.

 .Example
   Register-JekyllEnvironment -PathToProtableJekyllRoot "D:\Jekyll"
   Register-JekyllEnvironment -PathToProtableJekyllRoot "D:\Jekyll" -AllUsers
#>
Function Register-JekyllEnvironment{
    param (
        [Parameter(
            Mandatory=$True)]
        [Alias('path')]
        [string]$PathToProtableJekyllRoot,
        [switch]$AllUsers
    )
    if(Test-JekyllEnvironment -EnvironmentRoot $PathToProtableJekyllRoot  ){
        if($AllUsers){
            [Environment]::SetEnvironmentVariable("PortableJekyllRoot", "$PathToProtableJekyllRoot", "Machine")
        } else{
            [Environment]::SetEnvironmentVariable("PortableJekyllRoot", "$PathToProtableJekyllRoot", "User")
        }
    }
}
Export-ModuleMember -Function Register-JekyllEnvironment

<#
 .Synopsis
  Loads a Portable Jekyll install into the Path.

 .Description
  Loads a Portable Jekyll install into the Path of
  the current PowerShell Session. If you need to switch
  Jekyll Installs you will need a new PowerShell Session.

 .INPUTS
  Optionally pass in path to the root of a Portable
  Jekyll install. If no input is supplied it looks for
  the environment varible created by Register-JekyllEnvironment.

 .Example
   Invoke-JekyllEnvironment
   Invoke-JekyllEnvironment -$PathToProtableJekyllRoot "D:\Jekyll"
#>
Function Invoke-JekyllEnvironment{
    param (
        [Parameter(HelpMessage='What is the path to the Portable Jekyll root directory?')]
        [Alias('root')]
        [string]$PathToProtableJekyllRoot,
        [switch] $Force
    )
    if(($script:loadedEnvironment -eq "none") -or $Force){
      if($PathToProtableJekyllRoot){
          if(Test-JekyllEnvironment -EnvironmentRoot $PathToProtableJekyllRoot){
              Add-JekyllPaths $PathToProtableJekyllRoot
              $Script:loadedEnvironment = $PathToProtableJekyllRoot
          }else{
              return "Supplied Portable Jekyll root was invalid, unable to find required directories."
          }
      } else {
          if($env:PortableJekyllRoot){
              Add-JekyllPaths $env:PortableJekyllRoot
              $Script:loadedEnvironment = $env:PortableJekyllRoot
          } else {
            return "No valid Portable Jekyll root provided. If you just registered one try rebooting."
          }
      }
    }else{
      return "Environment Already Invoked"
    }

}
Export-ModuleMember -Function Invoke-JekyllEnvironment


<#
 .Synopsis
  Creates a new Jekyll blog.

 .Description
  Creates a new Jekyll blog.

 .Parameter Path
  Path to create the blog at. If left blank current directory is used.

 .Example
  cd c:\blogs\MyNewBlog
  New-JekyllBlog

 .Example
  New-JekyllBlog c:\blogs\MyNewBlog
#>
function New-JekyllBlog {
    param([string]$path=".")

    Invoke-JekyllEnvironment
    &jekyll.bat new $path
    $env:path = $oldPath
}

Export-ModuleMember -Function New-JekyllBlog


<#
 .Synopsis
  Restarts a Jekyll Server

 .Description
  Terminates existing Jekyll Server and starts a new one with the same properties.

 .INPUTS
  Pass in Jekyll server object to restart.

 .OUPUTS
  New Jekyll server object.

 .Example
   $MyBlog = $MyBlog | Reset-JekyllServer
#>
function Reset-JekyllServer {
    param([Parameter(ValueFromPipeline=$true, Position=0, ValueFromPipelineByPropertyName=$false, Mandatory=$true)]$Object)

    $para = @{
        Name = $Object.Name;
        Path = $Object.Path;
        Port = $Object.Port;
        Drafts = $Object.Drafts;
        Future = $Object.Future;
        NoWatch = $Object.NoWatch;
        BuildOnly = $false
    }

    $Object | Stop-JekyllServer

    Start-JekyllServer @para
}

Export-ModuleMember -Function Reset-JekyllServer

<#
 .Synopsis
  Displays the output from the Jekyll server.

 .Description
  Displays the output from the Jekyll server till you press ctrl + c.

  Note: Pressing crtl + c will not terminate the server, you must use Stop-JekyllServer.

 .INPUTS
  Jekyll server object to disaply output from.

 .Example
   Get-JekyllServer | where name -eq MyBlog | Watch-JekyllServer
#>
function Watch-JekyllServer {
    param([Parameter(ValueFromPipeline=$true, Position=0, ValueFromPipelineByPropertyName=$false, Mandatory=$true)]$Object)

    Receive-Job -Job $Object.Job -Wait

}

Export-ModuleMember -Function Watch-JekyllServer


<#
 .Synopsis
  Gets all running Jekyll Servers.

 .Description
  Gets all running Jekyll Servers that have been started in this session of powershell.

 .OUTPUTS
  Returns Jekyll Server objects for all servers currently running.

 .Example
   Get-JekyllServer

 .Example
  #Get server named MyBlog
  Get-JekyllServer | where Name -eq MyBlog
#>
function Get-JekyllServer {
    $Script:jekylljobs
}

Export-ModuleMember -Function Get-JekyllServer



<#
 .Synopsis
  Starts a JekyllServer

 .Description
  Starts a Jekyll Server in target directory as a background job. If you wish to see the server console output see Watch-JekllServer cmdlet.

 .Parameter Name
  Name of the Jekyll Server session. This is to identify the server when using Get-JekyllServer.

 .Parameter Path
  Location of Jekyll instance to serve.

 .Parameter Port
  Port Jekyll server will serve http from.

 .Parameter Drafts
  Jekyll server will also include documents in _draft folder. See Jekyll documentation for more details.

 .Parameter Future
  Jekyll server will also include posts marked in the future. See Jekyll documentation for more details.

 .Parameter NoWatch
  This switch instructs the Jekyll server to not watch for file system changes.

 .Parameter BuildOnly
  This switch will cause Jekyll to build static content but not serve it via http.

 .Example
  # Starts JekyllServer using the current directory as the path.
  Start-JekyllServer

 .Example
  # Starts JekyllServer using a path and port. Also uses all Future and Draft posts.
  Start-JekyllServer -Name MyBlog -Path c:\blog\MyBlog -Port 5000 -Drafts -Future

 .Example
  # Starts JekyllServer without watching the file system.
  Start-JekyllServer -Name MyBlog -NoWatch

 .Example
  # Builds static content.
  Start-JekyllServer -Path c:\blog\MyBlog -BuildOnly
#>
function Start-JekyllServer {

    param([string]$Name="", [string]$Path=(Get-Location), [int]$Port=0, [switch]$Drafts, [switch]$Future, [switch]$NoWatch, [switch]$BuildOnly)

    Invoke-JekyllEnvironment

    if($BuildOnly) {
        $env:path = $PathUpdate
        $currentdir = Get-Location
        cd $Path
        &jekyll.bat build
        cd $currentdir
        $env:path = $oldPath
    }else{

        if($Name -eq "") { $Name = Split-Path (Resolve-Path $Path) -Leaf }

        $command = "&jekyll.bat serve "

        if($Drafts) { $command += "--drafts " }
        if($Future) { $command += "--future " }
        if($NoWatch) {$command += "--no-watch " }

        if($Port -ne 0) {
            $command += "--port $Port "
        }

        $jobdetails = New-Object PSObject
        $jobdetails | Add-Member -MemberType NoteProperty -Name Name -Value $Name
        $jobdetails | Add-Member -MemberType NoteProperty -Name Path -Value $Path
        $jobdetails | Add-Member -MemberType NoteProperty -Name Port -Value $Port
        $jobdetails | Add-Member -MemberType NoteProperty -Name Drafts -Value $Drafts
        $jobdetails | Add-Member -MemberType NoteProperty -Name Future -Value $Future
        $jobdetails | Add-Member -MemberType NoteProperty -Name NoWatch -Value $NoWatch
        $jobdetails | Add-Member -MemberType NoteProperty -Name Job -Value $null
        $jobdetails | Add-Member -MemberType ScriptProperty -Name State -Value {
            $this.Job.State
        }

        $jobdetails.Job = Start-Job -Name $Name -ArgumentList @($PathUpdate, $Path, $command) -ScriptBlock {
            $args
            $env:path += $args[0]
            cd $args[1]
            Invoke-Expression $args[2]
        }

        $Script:jekylljobs += $jobdetails

        $jobdetails
    }
}

Export-ModuleMember -Function Start-JekyllServer


<#
 .Synopsis
  Stops Jekyll Servers.

 .Description
  Stops Jekyll Servers.

 .Parameter All
  Terminates all running Jekyll servers.

 .INPUTS
  Jekyll server objects to stop.

 .Example
  Stop-JekyllServer -All

 .Example
  Get-JekyllServer | where Name -eq MyBlog | Stop-JekyllServer
#>
function Stop-JekyllServer {
    [CmdletBinding()]
    param([switch]$All, [Parameter(ValueFromPipeline=$true, Position=0, ValueFromPipelineByPropertyName=$false)]$object)

    begin {
        if($All) {
            foreach($obj in $Script:jekylljobs) {
                Stop-Job $obj.Job | Out-Null
                Remove-Job $obj.Job | Out-Null
            }

            $Script:jekylljobs = @()
            return
        }
    }

    process{
        if($_ -eq $null) { return }
        if($_.Job -eq $null) { return }
        Stop-Job $_.Job | Out-Null
        Remove-Job $_.Job | Out-Null
        $Script:jekylljobs = $Script:jekylljobs -ne $_
    }
}

Export-ModuleMember -Function Stop-JekyllServer
