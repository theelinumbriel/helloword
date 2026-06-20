on run
	launchHelloWord(missing value)
end run

on open theFiles
	repeat with f in theFiles
		launchHelloWord(POSIX path of f)
	end repeat
end open

on launchHelloWord(posixPath)
	-- The bundle lives inside the repo; the repo dir is the bundle's parent.
	-- `dirname` of a path ending in "/" drops the last component, so
	-- dirname ".../md_editor/HelloWord.app/" == ".../md_editor".
	set repoDir to do shell script "dirname " & quoted form of (POSIX path of (path to me))
	set launcher to repoDir & "/launch.command"
	if posixPath is missing value then
		do shell script quoted form of launcher
	else
		do shell script quoted form of launcher & " " & quoted form of posixPath
	end if
end launchHelloWord
