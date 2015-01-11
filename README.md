# ex-nihilo #
Ex-nihilo provides a framework for managing, configuring and applying re-usable bits of Powershell DSC called *roles*. A collection of roles and their dependencies are grouped together into *sources*. Roles from one or many sources can be combined into *rolemaps*.

Roles can be configured to require other roles, so that prerequisites can be standardized and shared across any number of rolemaps. For example, the server role might define things like common windows features, a utilities share, mandatory applications, etc. The dns_server role and the web_server role could both require the server role, so that regardless of what the server does, it has that common base.

## Basic usage ##
This example demonstrates the bare minimum to use ex-nihilo to build and apply a DSC configuration on the local machine

    #Import the PowerShell module
	Import-Module exnihilo.psm1
    
	#Initialize the global configuration object
    Initialize-DSCConfiguration

	#Import the exnihilo source
	Initialize-DSCSource .\sources\exnihilo

	#Build the DSC configuration and MOF file
	New-DSCConfiguration -actualRoles @('exnihilo/consistency') -generateMOF

	#Apply the configuration
	Set-DscLocalConfigurationManager -Path $configuration.mofDirectory
	Start-DscConfiguration -Wait -Verbose -Path $configuration.mofDirectory

The consistency role in the exnihilo source actually disables the scheduled tasks for running the DSC consistency engine automatically. There is obviously a lot more you can do, but if you're eager to just dive in, this is a good way to start.

## Learning more ##
There is an example source which contains an example role that demonstrates all the available functions. If you want to create your own source, just copy that and rename the relevant bits.
