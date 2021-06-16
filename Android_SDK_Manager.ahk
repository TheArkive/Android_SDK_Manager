; AHK v2
; Unzipper CLI Example:   "D:\7-Zip\7z.exe" x -spe -o"D:\SDK\platform-tools" [zipFile]
;   The above command will use 7z.exe to unzip the downloaded file to "D:\SDK\platform-tools".
;   To get the most out of this script, you need to specify the location of your 7z.exe and the
;   location of your Android SDK folder.
;
; Source for downloading older versions of platform-tools:
;   Link: https://stackoverflow.com/questions/53453640/is-there-a-way-to-install-an-older-version-of-android-platform-tools

#INCLUDE lib\TheArkive_CliSAK.ahk
#INCLUDE lib\_JXON.ahk
#INCLUDE lib\_GuiCtlExt.ahk

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

(!Settings.Has("RootFolder"))    ? Settings["RootFolder"]    := "" : ""
(!Settings.Has("ThePath"))       ? Settings["ThePath"]       := "" : ""
(!Settings.Has("Link"))          ? Settings["Link"]          := "https://developer.android.com/studio#command-tools" : ""
(!Settings.Has("PlatOld"))       ? Settings["PlatOld"]       := [] : ""
(!Settings.Has("PlatOldRecent")) ? Settings["PlatOldRecent"] := "" : ""
(!Settings.Has("Unzipper"))      ? Settings["Unzipper"]      := "" : ""
(!Settings.Has("Updates"))       ? Settings["Updates"]       := "" : ""

If !FileExist(A_ScriptDir "\files") ; create dir for downloads
    DirCreate "files"

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
    g.Add("Button", "vUpdate x+10 yp hp","Update Packages").OnEvent("click",gui_events)
    
    g.Add("Button", "vPathInst x+10 yp hp","Set User %PATH%").OnEvent("click",gui_events)
    g.Add("Button", "vShowUpdates x+10 yp hp","Show Updates").OnEvent("click",gui_events)
    g.Add("Button", "vScriptDir x+10 yp hp","Script Dir").OnEvent("click",gui_events)
    
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
    
    g.Add("Text","xm y+10","Older platform-tools:")
    PlatOld := g.Add("ComboBox","vPlatOld x+0 yp-3 w100 Sort")
    PlatOld.OnEvent("change",gui_events)
    
    g.Add("Button","vDownload x+20","Download").OnEvent("click",gui_events)
    g.Add("Button","vInstall x+0","Install").OnEvent("click",gui_events)
    g.Add("Button","vDelete x+0","Delete").OnEvent("click",gui_events)
    g.Add("Button","vUnzipper x+0","Set Unzipper CLI").OnEvent("click",gui_events)
    g.Add("Button","vRevs x+0","Revisions").OnEvent("click",gui_events)
    
    g.Add("Text","x" x " yp","Filter:")
    g.Add("Edit", "vFilterAll x+0 yp-3 w200").OnEvent("change",gui_events)
    g.Add("Button","vFilterAllClear x+0 w30 hp","X").OnEvent("Click",gui_events)
    
    ctl := g.Add("ListView", "xm vAllList h400 w1050", ["Description", "Version", "Path"])
    ctl.OnEvent("DoubleClick", gui_events)
    ctl.ModifyCol(1, 500)
    ctl.ModifyCol(2, 100)
    ctl.ModifyCol(3, 400)
    
    UpdateFileList(g)
    
    g.Add("StatusBar", "vStats")
    g.Show("")
    
    Settings["gui"] := g
    list_packages()
}

UpdateFileList(g) {
    Global Settings
    
    PlatOld := g["PlatOld"]
    PlatOld.Delete()
    PlatOldArr := []
    Loop Files A_ScriptDir "\files\platform-tools*.zip"
        PlatOldArr.Push(RegExReplace(A_LoopFileName,"(platform\-tools_r|\-windows\.zip)"))
    PlatOld.Add(PlatOldArr.Length?PlatOldArr:[""])
    PlatOld.Text := Settings["PlatOldRecent"]
}

list_packages() {
    Global Settings
    
    sdkmgr := Settings["RootFolder"] "\cmdline-tools\latest\bin\sdkmanager.bat"
    Settings["output"] := ""
    
    Settings["gui"]["InstalledList"].Delete()
    Settings["gui"]["AllList"].Delete()
    
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
    
    If (pkg = "platform-tools")
        RunWait("adb kill-server",,"hide")
    
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
    Static q := Chr(34)
    
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
    } Else If (ctl.name = "PlatOld") {
        Settings["PlatOldRecent"] := ctl.Text
    } Else if (ctl.name = "Unzipper") {
        obj := InputBox("Enter cli command to unzip:","Unzip CLI",,Settings["Unzipper"])
        If obj.value
            Settings["Unzipper"] := obj.value
    } Else if (ctl.name = "Download") {
        If !(ver := ctl.gui["PlatOld"].Text) {
            Msgbox "Select a version first."
            return
        }
        
        ctl.gui["Stats"].SetText("Downloading...")
        dl_file := "https://dl.google.com/android/repository/platform-tools_r" ver "-windows.zip"
        destFile := "platform-tools_r" ver "-windows.zip"
        
        If !FileExist(destFile)
            Download(dl_file,A_ScriptDir "\files\" destFile)
        Else {
            Msgbox "File already exists:`r`n`r`n    " destFile
            return
        }
        
        ctl.gui["Stats"].SetText("")
        test := FileRead("files\" destFile)
        If InStr(test,"<!DOCTYPE html>") {
            Msgbox "Download failed."
            FileDelete "files\" destFile
            return
        } Else
            Msgbox "Download successful."
        
        UpdateFileList(ctl.gui)
    } Else If (ctl.name = "Install") {
        If DirExist(Settings["RootFolder"] "\platform-tools") {
            Msgbox "Uninstall current platform-tools first."
            return
        } Else If !(ver := ctl.gui["PlatOld"].Text) {
            Msgbox "Select a version first."
            return
        }
        
        destFile := "files\platform-tools_r" ver "-windows.zip"
        
        ctl.gui["Stats"].SetText("Extracting...")
        cmd := StrReplace(Settings["Unzipper"],"[zipFile]",destFile)
        
        RunWait(cmd,,"hide")
        
        ctl.gui["Stats"].SetText("")
        list_packages()
    } Else If (ctl.name = "Delete") {
        If !(ver := ctl.gui["PlatOld"].Text) {
            Msgbox "Select a version first."
            return
        }
        
        delFile := "files\platform-tools_r" ver "-windows.zip"
        
        If (MsgBox("Deleting file:`r`n`r`n" delFile "`r`n`r`nContinue?","DELETE FILE",4) = "No")
            return
        FileDelete delFile
        MsgBox "File deleted."
        UpdateFileList(ctl.gui)
    } Else If (ctl.name = "ShowUpdates") {
        upd_win()
    } Else If (ctl.name = "Revs")
        Run("https://developer.android.com/studio/releases/platform-tools#revisions")
    Else if (ctl.name = "ScriptDir")
        Run("explorer.exe " q A_ScriptDir q)
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
    s3 := InStr(data,"Available Updates:")
    
    Settings["all"] := []
    Settings["installed"] := []
    
    If (!s3)
        all := SubStr(data,s2), updates := ""
    Else
        all := SubStr(data,s2,s3-s2-1)
      , updates := SubStr(data,s3)
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
    
    If (updates)
        upd_store(updates)
}

upd_store(txt,show:=false) {
    list_upd := ""
    Loop Parse txt, "`n", "`r"
        If (A_Index >= 2 && A_LoopField)
            list_upd .= (list_upd?"`r`n":"") A_LoopField
    
    Settings["Updates"] := list_upd
    
    If show
        upd_win()
}

upd_win() {
    g := Gui("-DPIScale -MinimizeBox -MaximizeBox Owner" Settings["gui"].hwnd,"Available Updates")
    g.OnEvent("close",upd_close)
    g.OnEvent("escape",upd_close)
    
    upd := Settings["Updates"] ? Settings["Updates"] : "No Updates"
    g.SetFont(,"Consolas")
    g.Add("Text",,upd)
    g.Show("w300")
}

upd_close(g) {
    g.Destroy()
}

dbg(in_str) {
    OutputDebug "AHK: " in_str
}