Class IBSP.TOOLS.MirrorSync.Task Extends %SYS.Task.Definition
{

/// SharedPath references a path accesible to both Mirror failover members.
Property SharedPath As %String;

Parameter TaskName = "MirrorSync";

Method SetSharedPath(path)
{
	set ..SharedPath=path
}

Method OnTask() As %Status
{
	do ^MirrorSync(..SharedPath)
	Quit $$$OK
}

}
