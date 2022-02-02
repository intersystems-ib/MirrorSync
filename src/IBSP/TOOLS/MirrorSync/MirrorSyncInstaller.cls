/// 
/// Installer for MirrorSync
/// 
/// See README.md for installation instructions
/// 
Class IBSP.TOOLS.MirrorSync.Installer
{

/// Create environment
/// Use this option when you need to automate the creation of an environment (e.g. a test namespace and databases)
Parameter CreateEnvironment = "no";

/// Namespace (used when CreateEnvironment)
Parameter Namespace = "MIRROR-SYNC";

/// Base application path (used when CreateEnvironment)
Parameter BasePath = "/opt/mirror-sync/app";

/// Data db path (used when CreateEnvironment)
Parameter DataDBPath = "/opt/mirror-sync/db/data";

/// Code db path (used when CreateEnvironment)
Parameter CodeDBPath = "/opt/mirror-sync/db/code";

ClassMethod Run(path As %String = "") As %Status
{
	set ret = $$$OK
	set retTxt = "OK"

  	if path="" $$$ThrowStatus($$$ERROR($$$GeneralError,"SharedPath cannot be empty"))

	try {
		do ..Log("MirrorSync Installer started")
		
		if $system.Mirror.IsMember() {
			$$$THROWONERROR(tSC, ..DeleteGlobals())
			$$$THROWONERROR(tSC, ..Install(path))
		}else{
			set retTxt = "NOT INSTALLED: The instance is not a Mirror member"
		}
	} catch ex {
		set ret = ex.AsStatus()
		set retTxt = $system.Status.GetOneErrorText(ret)
	}
	do ..Log("MirrorSync Installer ended")
	do ..Log("Status="_retTxt)
	quit ret
}

ClassMethod Install(SharedPath As %String = "") As %Status
{
	set ret = $$$OK
	try {
		//Check SharedPath
		if SharedPath="" $$$ThrowStatus($$$ERROR($$$GeneralError,"SharedPath cannot be empty"))
		
		//Enable Audit
		set system=##class(Security.System).%OpenId("SYSTEM")
		set system.AuditEnabled=1
		do system.%Save()
		do ..Log("Audit Enabled")
		
		//Enable Audit events
		do ..Log("   ...enabling events")
		set event=##class(Security.Events).%OpenId("%system||%security||resourcechange")
		set event.Enabled=1
		do event.%Save()
		do ..Log("%System||%Security||ResourceChange: Enabled")
		
		set event=##class(Security.Events).%OpenId("%system||%security||rolechange")
		set event.Enabled=1
		do event.%Save()
		do ..Log("%System||%Security||RoleChange: Enabled")
		
		set event=##class(Security.Events).%OpenId("%system||%security||userchange")
		set event.Enabled=1
		do event.%Save()
		do ..Log("%System||%Security||UserChange: Enabled")
		
		set event=##class(Security.Events).%OpenId("%system||%security||applicationchange")
		set event.Enabled=1
		do event.%Save()
		do ..Log("%System||%Security||ApplicationChange: Enabled")
		
		set event=##class(Security.Events).%OpenId("%system||%security||sslconfigchange")
		set event.Enabled=1
		do event.%Save()
		do ..Log("%System||%Security||SSLConfigChange: Enabled")
		
		do ..Log("   ...disabling events")
		set event=##class(Security.Events).%OpenId("%system||%security||auditreport")
		set event.Enabled=0
		do event.%Save()
		do ..Log("%System||%Security||AuditReport: Disabled")
		
		set event=##class(Security.Events).%OpenId("%system||%system||configurationchange")
		set event.Enabled=0
		do event.%Save()
		do ..Log("%System||%System||ConfigurationChange: Disabled")

		
		//Create Task
		
		//First, check if exist already a Task with the same name. If so, delete it.
		do ..DeleteTaskByName("MirrorSync")
		
		do ..Log("   ...creating tasks")
		set task=##class(%SYS.Task).%New()
		set task.Name="MirrorSync"
		set task.Description="Export/Import settings in a Mirror configuration"
		set task.NameSpace="%SYS"
		

		// Schedule 
		set task.DailyFrequencyTime=0 // 0 = minutes
		set task.DailyFrequency=1 // 1 minute
		set task.DailyIncrement=1 // 1 minutes between runs
		set task.DailyStartTime=0 // Time for tasks to start running in $H format($p($h,",",2))
		// Start from now
		set task.StartDate = $p($h,",",1)
		// Run on Any Mirror member regardless of status
		set task.MirrorStatus = 3
		// Task definition
		set task.TaskClass="IBSP.TOOLS.MirrorSync.Task"
		//set task.Settings=$LB("SharedPath", SharedPath)
		set taskdef= ##class(IBSP.TOOLS.MirrorSync.Task).%New()
		do taskdef.SetSharedPath(SharedPath)
		do task.AssignSettings(taskdef)
		do task.%Save()
		
		do ..Log("Task ""MirrorSync"" scheduled:")
		do ..Log("Start date:"_$zdate(task.StartDate)_", now.")
		do ..Log("Run automatically every "_task.DailyFrequency_" minute")
	
	} catch ex {
		set ret = ex.AsStatus()
	}
	quit ret
}

/// Uninstalls MirrorSync.
/// *WARNING* it actually deletes classes!!
ClassMethod Uninstall() As %Status
{
	set ret = $$$OK
	try {
		do ..Log("Deleting MirrorSync routines...")
		$$$ThrowOnError(##class(%RoutineMgr).Delete("MirrorSync.mac"))

		do ..Log("Deleting MirrorSync classes...")
		$$$ThrowOnError($system.OBJ.DeletePackage("MirrorSync"))
		
		w !
		do ..Log("Deleting MirrorSync globals...")
		$$$ThrowOnError(obj.DeleteGlobals())
		
		do ..Log("Deleting MirrorSync tasks...")
		$$$ThrowOnError(obj.DeleteTaskByName("MirrorSync"))
		
		do ..Log("MirrorSync succesfully uninstalled")
	} catch ex {
		set ret = ex.AsStatus()
	}
	quit ret
}

ClassMethod DeleteTaskByName(name As %String) As %Status
{
	set ret = $$$OK
	try {
		//Check if exist already Tasks with the same name. If so, delete them.
		set rs=##class(%ResultSet).%New("%SYS.Task:QuickTaskList")
		do rs.Execute()
		while rs.Next() {
			if rs.Get("Task Name") = name {
				do ##class(%SYS.Task).%DeleteId(rs.Get("ID"))
				do ..Log("Task named "_rs.Get("Task Name")_": deleted")
			}
		}
	} catch ex {
		set ret = ex.AsStatus()
	}
	quit ret
}

/// Manifest: Create Environment
XData CreateEnvironmentManifest
{
<Manifest>
	<Log Text="Creating namespace ${Namespace}" Level="0"/> 
	<Namespace Name="${Namespace}" Create="yes" Ensemble="1"> 
		<Configuration> 
			<Database Name="${Namespace}-DATA" Dir="${DataDBPath}" Create="yes" MountRequired="true" Resource="%DB_DEFAULT" PublicPermissions="RW" MountAtStartup="true"/> 
			<Database Name="${Namespace}-APP" Dir="${CodeDBPath}" Create="yes" MountRequired="true" Resource="%DB_DEFAULT" PublicPermissions="RW" MountAtStartup="true"/> 
		</Configuration>
	</Namespace>
</Manifest>
}

ClassMethod DeleteGlobals() As %Status
{
	set ret = $$$OK
	try {
		if $d(^MirrorSync){
			k ^MirrorSync
		}
		
	} catch ex {
		set ret = ex.AsStatus()
	}
	quit ret
}

ClassMethod RunCreateEnvironmentManifest(ByRef pVars, pLogLevel As %Integer = 3, pInstaller As %Installer.Installer, pLogger As %Installer.AbstractLogger) As %Status [ CodeMode = objectgenerator, Internal ]
{
   Quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "CreateEnvironmentManifest")
}

/// Installer entry point.
/// Use this when you need to control all installation parameters.
/// 
/// You can pass parameters using vars:
/// - CreateEnvironment, Namespace, BasePath, DataDBPath, CodeDBPath 
ClassMethod RunWithParams(ByRef vars) As %Status
{
	set ret = $$$OK
	set previousNamespace = $namespace

    try { 
        do ..Log("START INSTALLER") 

		// set default values for installer variables
        for ivar="CreateEnvironment","Namespace","BasePath","DataDBPath","CodeDBPath" {
            if '$data(vars(ivar)) set vars(ivar)=$parameter($classname(), ivar)
        }
		
		// create environment
		if vars("CreateEnvironment") = "yes" {
			$$$ThrowOnError(..RunCreateEnvironmentManifest(.vars))
		}

        do ..Log("INSTALLER SUCCESS")

    } catch ex { 
        set sc = ex.AsStatus() 
        write $System.Status.GetErrorText(sc),! 
        do $SYSTEM.Process.Terminate($JOB,1) 
    }

	set $namespace = previousNamespace
    quit ret
}

ClassMethod MirrorSetup(hostname) As %Status
{
  // Eliminate Carrier return
  set hostname = $P(hostname,$c(10),1) 

  do ..Log("SETTING UP THE MIRROR ON HOST "_hostname_"...")
  if $system.Mirror.IsMember() {
		do ..Log("This system is already configured as a mirror member")
 	}else{
    	do ..Log("Setup for host: "_hostname)
    
    // Enable mirror: 
    do ..enableMirrorService()
    do ..Log("Mirror Enabled for host : "_hostname)
      
    if (hostname="mirror-sync1") {
      do ..Log("Configuring "_hostname_"...")
      do ..createMirror("mirror-sync1")
    } else {
      // Allow some time to create mirror in primary
      h 2
      do ..Log("Joining "_hostname_" as failover")
      do ..joinAsFailover("mirror-sync2","mirror-sync1")
    }
    // Create DB and add it to mirror
    do ..createMirrorDB()
    }
  quit $$$OK
}

ClassMethod enableMirrorService() As %Status
{
  set previousNamespace = $namespace	
  set $namespace="%SYS"
  do ..Log("Changing to namaspace %SYS...")
  do ##class(Security.Services).Get("%Service_Mirror", .svcProps)
  set svcProps("Enabled") = 1
  do ##class(Security.Services).Modify("%Service_Mirror", .svcProps)
  do ..Log("Enabling mirror service...")
  set $namespace = previousNamespace
}

ClassMethod createMirror(hostname) As %Status
{
  set previousNamespace = $namespace
  set $namespace="%SYS"
  set mirrorName="MIRRORSET"
  do ..Log("Creating mirror "_mirrorName_"...")
  // Create mirror:
  set mirror("UseSSL") = 0
  set sc = ##class(SYS.Mirror).CreateNewMirrorSet(mirrorName, hostname, .mirror)
  if 'sc {do $system.OBJ.DisplayError(sc)} else {do ..Log("Created mirror "_mirrorName_"...")}
  set $namespace = previousNamespace
  quit sc
}

ClassMethod joinAsFailover(hostnameFrom, hostnameTo) As %Status
{
  set previousNamespace = $namespace
  set mirrorName="MIRRORSET"
  set instanceName="IRIS"
  
  // Join as failover:
  s sc=##class(SYS.Mirror).JoinMirrorAsFailoverMember(mirrorName,hostnameTo,instanceName,hostnameFrom,,.MirrorInfo)
  do ..Log("Jonining mirror "_mirrorName_"...")
  if 'sc do $system.OBJ.DisplayError(sc)
  set $namespace = previousNamespace
  quit sc
}

ClassMethod createMirrorDB() As %Status
{
  set dir="/opt/"
  set dirName="mirror-sync-DB"
  set mirDBName="MIRRORDB"
  set mirrorName="MIRRORSET"
  set mirNSName="MIRRORSYNC"
  
  do ..Log("Creating databases and NS "_mirNSName)
  
  // Create the directory
  do ##class(%Library.File).CreateNewDir(dir,dirName)
  // Add DB to config
  set Properties("Directory")=dir_dirName
  do ##class(Config.Databases).Create(mirDBName,.Properties)
  // Set the DB properties
  set Properties("Directory")=dir_dirName
  set rc = ##class(SYS.Database).CreateDatabase(dir_dirName,,,,,,mirDBName,mirrorName)
  if 'rc { 
    do ..Log("Database creation failed!")
    do $system.OBJ.DisplayError(rc)
    quit rc
  }
  
  // Create namespace for mirrored database
  set ns("Globals")=mirDBName
  set ns("Routines")=mirDBName
  do ##class(Config.Namespaces).Create(mirNSName,.ns)
  set rc = ##class(Config.Namespaces).Exists(mirNSName,.obj,.status)
  if 'rc {
    do ..Log("NS creation failed.")
    do $system.OBJ.DisplayError(rc)
    quit rc
  }
    
  quit $$$OK
}

/// Log a message
/// pText - Text message
/// pTimeStamp - Add a timestamp
/// pNewLine - Add a new line
ClassMethod Log(pText As %String, pTimeStamp As %Boolean = 1, pNewLine As %Boolean = 1)
{
	write $case(pTimeStamp,1:"["_$zdt($h,3)_"] ",:"")_pText_$case(pNewLine,1:$$$NL,:"")
}

Storage Default
{
<Data name="InstallerDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>SharedPath</Value>
</Value>
</Data>
<DataLocation>^IBSP.TOOLS.Mirro228A.InstallerD</DataLocation>
<DefaultData>InstallerDefaultData</DefaultData>
<IdLocation>^IBSP.TOOLS.Mirro228A.InstallerD</IdLocation>
<IndexLocation>^IBSP.TOOLS.Mirro228A.InstallerI</IndexLocation>
<StreamLocation>^IBSP.TOOLS.Mirro228A.InstallerS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
