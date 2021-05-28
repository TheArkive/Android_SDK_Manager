; AHK v2

#INCLUDE lib\TheArkive_CliSAK.ahk
#INCLUDE lib\_JXON.ahk

#NoTrayIcon

OnExit(on_exit)

If FileExist("settings.json.blank") && !FileExist("settings.json")
    FileMove "settings.json.blank", "settings.json"

SettingsTxt := FileExist("settings.json") ? FileRead("settings.json") : ""
Settings := SettingsTxt ? jxon_load(&SettingsTxt) : Map()

Settings["output"] := ""
Settings["loading"] := false
Settings["listing"] := false
Settings["all"] := []
Settings["installed"] := []

(!Settings.Has("RootFolder")) ? Settings["RootFolder"] := "" : ""
(!Settings.Has("ThePath"))    ? Settings["ThePath"]    := "" : ""
(!Settings.Has("Link"))       ? Settings["Link"]       := "https://developer.android.com/studio#command-tools" : ""

make_gui()

OnMessage(0x200,WM_MOUSEMOVE)
OnMessage(0x208,WM_MBUTTONUP)

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    Global Settings
    g := Settings["gui"]
    
    If (hwnd = g["AllList"].hwnd)
        Tooltip "Double-Click to install."
    Else If (hwnd = g["InstalledList"].hwnd)
        Tooltip "Double-Click to uninstall."
    Else If (hwnd = g["Link1"].hwnd)
        Tooltip "Middle-Click to load a web page and download command-line tools.`r`n`r`n"
              . "You can update this URL as needed.`r`n`r`n"
              . "Command-line toosl are the foundation of this window.  The Folder`r`n"
              . "above points to the location where the command-line tools have`r`n"
              . "been unzipped."
    Else
        Tooltip
}

WM_MBUTTONUP(wParam, lParam, msg, hwnd) {
    Global Settings
    MouseGetPos ,,,&ctlHwnd,2
    If (ctlHwnd = hwnd)
        Run Settings["Link"]
}

make_gui() {
    Global Settings
    Static q := Chr(34)
    
    g := Gui("-DPIScale","Android SDK Manager")
    g.SetFont("s10","Consolas")
    g.OnEvent("Close",gui_close)
    
    g.Add("Text", "xm y15", "Folder:")
    g.Add("Edit", "vRootFolder x+5 yp-3 w400", Settings["RootFolder"])
    g.Add("Button", "vRootBrowse x+0 hp" ,"...").OnEvent("Click", gui_events)
    g.Add("Button", "vOpen x+0 hp","Open").OnEvent("click",gui_events)
    g.Add("Button", "vUpdate x+20 yp hp","Update Packages").OnEvent("click",gui_events)
    
    g.Add("Button", "vPathInst x+20 yp hp","Set User %PATH%").OnEvent("click",gui_events)
    
    ctl := g.Add("Edit", "vLink1 xm y+10 w400 Center",Settings["Link"])
    ctl.SetFont("s8")
    ctl.OnEvent("change",gui_events)
    
    x := 1050 - 250 + 10 - 30
    g.Add("Text","x" x " yp+3","Filter:")
    g.Add("Edit", "vFilterInstalled x+0 yp-3 w200").OnEvent("change",gui_events)
    g.Add("Button","vFilterInstalledClear x+0 w30 hp","X").OnEvent("Click",gui_events)
    
    ctl := g.Add("ListView", "xm vInstalledList h200 w1050", ["Description", "Version", "Path", "Location"])
    ctl.OnEvent("DoubleClick",gui_events)
    ctl.ModifyCol(1, 500)
    ctl.ModifyCol(2, 100)
    ctl.ModifyCol(3, 200)
    ctl.ModifyCol(4, 200)
    
    g.Add("Text","x" x " y+10","Filter:")
    g.Add("Edit", "vFilterAll x+0 yp-3 w200").OnEvent("change",gui_events)
    g.Add("Button","vFilterAllClear x+0 w30 hp","X").OnEvent("Click",gui_events)
    
    ctl := g.Add("ListView", "xm vAllList h400 w1050", ["Description", "Version", "Path"])
    ctl.OnEvent("DoubleClick",gui_events)
    ctl.ModifyCol(1, 500)
    ctl.ModifyCol(2, 100)
    ctl.ModifyCol(3, 400)
    
    g.Add("StatusBar", "vStats")
    
    g.Show("")
    
    Settings["gui"] := g
    list_packages()
}

list_packages() {
    Global Settings
    
    sdkmgr := Settings["RootFolder"] "\cmdline-tools\latest\bin\sdkmanager.bat"
    Settings["output"] := ""
    
    Settings["gui"]["Stats"].SetText("Please Wait...")
    c := cli(sdkmgr " --list", "ID:ListAll")
}

install(pkg) {
    Global Settings
    
    sdkmgr := Settings["RootFolder"] "\cmdline-tools\latest\bin\sdkmanager.bat"
    Settings["output"] := ""
    
    Settings["gui"]["Stats"].SetText("Please Wait...")
    c := cli(sdkmgr " --install " pkg, "ID:Install")
}

uninstall(pkg) {
    Global Settings
    
    sdkmgr := Settings["RootFolder"] "\cmdline-tools\latest\bin\sdkmanager.bat"
    Settings["output"] := ""
    
    Settings["gui"]["Stats"].SetText("Please Wait...")
    c := cli(sdkmgr " --uninstall " pkg, "ID:Uninstall")
}

update() {
    sdkmgr := Settings["RootFolder"] "\cmdline-tools\latest\bin\sdkmanager.bat"
    Settings["output"] := ""
    
    Settings["gui"]["Stats"].SetText("Please Wait...")
    c := cli(sdkmgr " --update","ID:Update")
}

gui_events(ctl, info) {
    Global Settings
    g := Settings["gui"]
    
    If (ctl.name = "RootBrowse") {
        If !(dir := FileSelect("D2", Settings["RootFolder"]))
            return
        g["RootFolder"].value := Settings["RootFolder"] := dir
    } Else If (ctl.name = "FilterAll") || (ctl.name = "FilterInstalled") {
        str := ctl.value, LV := g[(cat := StrReplace(ctl.name,"Filter","")) "List"]
        LV.Delete(), LV.Opt("-Redraw")
        
        cat := StrLower(cat)
        If !str {
            For i, arr in Settings[cat]
                LV.Add(,arr[1], arr[2], arr[3])
        } Else {
            For i, arr in Settings[cat]
                If InStr(arr[1], str) || InStr(arr[2], str) || InStr(arr[3], str)
                    LV.Add(,arr[1], arr[2], arr[3])
        }
        
        LV.Opt("+Redraw")
    } Else If RegExMatch(ctl.name,"^Filter(\w+)Clear$",&match) {
        g["Filter" match[1]].Value := ""
        gui_events(g["Filter" match[1]], "")
    } Else If RegExMatch(ctl.name,"(\w+)List",&match) {
        row := ctl.getNext()
        pkg := ctl.GetText(row,3)
        
        If match[1] = "All"
            install(pkg)
        Else
            uninstall(pkg)
    } Else If (ctl.name = "Open") {
        Run "explorer.exe " Chr(34) Settings["RootFolder"] Chr(34)
    } Else If (ctl.name = "update") {
        update()
    } Else If (ctl.name = "PathInst") {
        LV := g["InstalledList"]
        pathVar := RegRead("HKEY_CURRENT_USER\Environment","Path")
        arr := StrSplit(pathVar,";")
        root := Settings["RootFolder"]
        
        Loop LV.GetCount() {
            path := root "\" (item := RTrim(LV.GetText(A_Index,4),"\"))
            If RegExMatch(item,"^cmdline")
                Continue
            
            For i, val in arr
                If (dupe := (val=path))
                    Break
            
            If !dupe {
                pathVar := pathVar ";" root "\" item
                RegWrite pathVar, "REG_SZ", "HKEY_CURRENT_USER\Environment", "Path"
            }
        }
        
        Msgbox "Path values added."
    } Else If (ctl.name = "Link1") {
        Settings["Link"] := ctl.value
    }
}

gui_close(_gui) {
    ExitApp
}

on_exit(ExitReason, ExitCode) {
    Global Settings
    
    Settings.Delete("gui")
    Settings.Delete("output")
    Settings.Delete("listing")
    Settings.Delete("loading")
    Settings.Delete("all")
    Settings.Delete("installed")
    
    stxt := jxon_dump(Settings, 4)
    
    If FileExist("settings.json")
        FileDelete "settings.json"
    FileAppend stxt, "settings.json", "UTF-8"
}

StdOutCallback(data,ID,c) {
    Global Settings
    g := Settings["gui"]
    
    If (ID = "ListAll") {
        If InStr(data, "Loading local repository...")
            Settings["loading"] := true
        Else If Settings["loading"] {
            str := SubStr(data, 1, InStr(data,"`r") - 1)
            g["Stats"].SetText(str)
        } 
    }
    
    If (ID = "ListAll") && (pos := InStr(data,"Available Packages:")) {
        Settings["loading"] := false
        Settings["listing"] := true
        
        pos += StrLen("Available Packages:") + 2
        Settings["output"] := SubStr(data, pos)
        g["Stats"].SetText("")
    }
    
    If (ID = "Install") || (ID = "Uninstall") || (ID = "Update"){
        str := SubStr(data, 1, InStr(data,"`r") - 1)
        
        If InStr(data,"Warning: Failed to delete package location")
            msgbox "Warning:`r`n`r`n"
                 . "The package you tried to uninstall was not completely removed.  You probably still have some processes running from that package.`r`n`r`n"
                 . "End those processes and then manually delete the rest of that folder."
        
        If RegExMatch(data, "i)Installing in (.*?) instead.",&match)
            Msgbox "The package you tried to install could not be installed to it's usual location.`r`n`r`n"
                 . "New Location:`r`n     " match[1] "`r`n`r`n"
                 . "Please rename this folder so it doesn't include the '-2' in the end of the title.  You may need to delete the original folder."
        
        g["Stats"].SetText(str)
    }
}

PromptCallback(prompt,ID,c) {
    Global Settings
    g := Settings["gui"]
    
    If (ID = "ListAll") && (c.ready) {
        Settings["listing"] := false
        
        txt := c.clean_lines(c.stdout)
        txt := c.clean_lines(txt, "`r")
        proc_list(txt)
        
        c.close()
    }
    
    If (ID = "Install" || ID = "Uninstall" || ID = "Update") && (c.ready) {
        g["Stats"].SetText("")
        c.close()
        sleep 200
        list_packages()
    }
}

proc_list(data) {
    Global Settings
    g := Settings["gui"]
    LV_all := g["AllList"]
    LV_inst := g["InstalledList"]
    LV_all.Delete()
    LV_inst.Delete()
    LV_all.Opt("-Redraw")
    
    s1 := InStr(data,"Installed Packages:")
    s2 := InStr(data,"Available Packages:")
    
    Settings["all"] := []
    Settings["installed"] := []
    
    all := SubStr(data,s2)
    installed := SubStr(data, s1, s2-s1)
    
    Loop Parse all, "`n", "`r"
    {
        If (A_Index >= 4 && A_LoopField) {
            line := StrSplit(A_LoopField,"|"," ") ; ["Description", "Version", "Path", "Location"] / Path | Version | Description | Location
            LV_all.Add(, line[3], line[2], line[1])
            Settings["all"].Push([line[3], line[2], line[1]])
        }
    }
    
    LV_all.Opt("+Redraw")
    
    Loop Parse installed, "`n", "`r"
    {
        If (A_Index >= 4 && A_LoopField) {
            line := StrSplit(A_LoopField,"|"," ") ; ["Description", "Version", "Path", "Location"] / Path | Version | Description | Location
            LV_inst.Add(, line[3], line[2], line[1], line[4])
            Settings["installed"].Push([line[3], line[2], line[1], line[4]])
        }
    }
}

dbg(in_str) {
    OutputDebug "AHK: " in_str
}