$pkg_name="contosouniversity_ag"
$pkg_origin="mwrock"
$pkg_version="0.2.5"
$pkg_maintainer="Matt Wrock"
$pkg_license=@('MIT')
$pkg_description="A sample ASP.NET Full EFF IIS app"
$pkg_deps=@(
  "core/dotnet-45-runtime",
  "core/iis-webserverrole",
  "core/iis-aspnet4",
  "core/dsc-core"
)
$pkg_build_deps=@(
  "core/nuget",
  "core/dotnet-45-dev-pack",
  "core/visual-build-tools-2017"
)
$pkg_source="https://webpifeed.blob.core.windows.net/webpifeed/Partners/ASP.NET%20MVC%20Application%20Using%20Entity%20Framework%20Code%20First.zip"
$pkg_shasum="2259f86eb89fc921ce8481fc3297f3836815f4e2b3cab1f7353f799ec58ed2ef"

$pkg_binds=@{
  "database"="availability_group_name port"
}

function Invoke-Build {
  nuget restore "C#/contosouniversity/packages.config" -PackagesDirectory "$HAB_CACHE_SRC_PATH/$pkg_dirname/C#/packages" -Source "https://www.nuget.org/api/v2"
  nuget install MSBuild.Microsoft.VisualStudio.Web.targets -Version 14.0.0.3 -OutputDirectory $HAB_CACHE_SRC_PATH/$pkg_dirname/
  $env:TargetFrameworkRootPath="$(Get-HabPackagePath dotnet-45-dev-pack)\Program Files\Reference Assemblies\Microsoft\Framework"
  $env:VSToolsPath = "$HAB_CACHE_SRC_PATH/$pkg_dirname/MSBuild.Microsoft.VisualStudio.Web.targets.14.0.0.3/tools/VSToolsPath"
  MSBuild "C#/contosouniversity/contosouniversity.csproj" /t:Build
  if($LASTEXITCODE -ne 0) {
      Write-Error "dotnet build failed!"
  }
}

function Invoke-Install {
  MSBuild "C#/contosouniversity/contosouniversity.csproj" /t:WebPublish /p:WebPublishMethod=FileSystem /p:publishUrl=$pkg_prefix/www
  Remove-Item $pkg_prefix/www/Web.config
  (Get-Content "$pkg_prefix/www/views/home/Index.cshtml").replace("Welcome to Contoso University", "Welcome to Contoso University - $pkg_version") | Set-Content "$pkg_prefix/www/views/home/Index.cshtml"
}
