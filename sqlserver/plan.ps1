$pkg_name = "sqlserver"
$pkg_origin = "mwrock"
$pkg_version = "14.0.1000"
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
$pkg_bin_dirs = @("bin")
