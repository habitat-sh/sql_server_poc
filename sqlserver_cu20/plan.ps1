$pkg_name = "sqlserver"
$pkg_origin = "mwrock"
$pkg_version = "14.0.3294"
$pkg_maintainer = "The Habitat Maintainers "
$pkg_deps=@("core/dsc-core")
$pkg_exports=@{
    port     ="port"
    password ="app_password"
    username ="app_user"
    instance ="instance"
}
$pkg_description = "Microsoft SQL Server 2017"
$pkg_upstream_url = "https://www.microsoft.com/en-us/sql-server/sql-server-2017"
$pkg_source="https://download.microsoft.com/download/C/4/F/C4F908C9-98ED-4E5F-88D5-7D6A5004AEBD/SQLServer2017-KB4541283-x64.exe"
$pkg_shasum="90677f7d8ff04691bd5bd7653b9e2498eeccac1ad331b1dd12249190b4f442fc"
$pkg_bin_dirs = @("bin")

function Invoke-Unpack { }

function Invoke-Install {
    Copy-Item "$HAB_CACHE_SRC_PATH/SQLServer2017-KB4541283-x64.exe" "$pkg_prefix/bin/" -Force
}
