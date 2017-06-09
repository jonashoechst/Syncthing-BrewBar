//
//  AppDelegate.swift
//  syncthing-brew-gui
//
//  Created by Jonas Höchst on 08.06.17.
//  Copyright © 2017 Jonas Höchst. All rights reserved.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, XMLParserDelegate {

// MARK: - menu items
    let barItem = NSStatusBar.system().statusItem(withLength: -2)
    let statusItem = NSMenuItem(title: "Syncthing: status unknown", action: nil, keyEquivalent: "")
    let startItem = NSMenuItem(title: "Start Syncthing", action: #selector(AppDelegate.startSyncthing), keyEquivalent: "s")
    let stopItem = NSMenuItem(title: "Stop Syncthing", action: #selector(AppDelegate.stopSyncthing), keyEquivalent: "s")
    let restartItem = NSMenuItem(title: "Restart Syncthing", action: #selector(AppDelegate.restartSyncthing), keyEquivalent: "")
    let browserItem = NSMenuItem(title: "Open WebUI", action: #selector(AppDelegate.openBrowser(sender:)), keyEquivalent: "n")
    let folderOffset = 6
    
// MARK: - syncthing variables and locations
    let config_xml = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]+"/Syncthing/config.xml"
    var syncthingStatus = "undefined"
    var guiConfiguration: Dictionary<String, String> = [:]
    var xmlLocation: Array<String> = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApplication.shared().windows.last!.close()
        
        if let button = barItem.button {
            button.image = NSImage(named: "baricon")
        }
        
        let menu = NSMenu()
        menu.addItem(statusItem)
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(restartItem)
        menu.addItem(browserItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.shared().terminate(_:)), keyEquivalent: "q"))
        barItem.menu = menu
        
        restartItem.isHidden = true

        updateUIStatus()
    }
    
// MARK: - brew service handling
    func execCmd(launchPath: String, arguments: [String]) -> String {
        let pipe = Pipe()
        
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
        
        return output!
    }
    
    func startSyncthing() {
        let execString = execCmd(launchPath: "/usr/local/bin/brew", arguments: ["services", "start", "syncthing"])
        print(execString)
        
        updateUIStatus()
    }
    
    func stopSyncthing() {
        let execString = execCmd(launchPath: "/usr/local/bin/brew", arguments: ["services", "stop", "syncthing"])
        print(execString)
        
        updateUIStatus()
    }
    
    func restartSyncthing() {
        let execString = execCmd(launchPath: "/usr/local/bin/brew", arguments: ["services", "restart", "syncthing"])
        print(execString)
        
        updateUIStatus()
    }
    
    func getSyncthingStatus() -> String {
        let execString = execCmd(launchPath: "/usr/local/bin/brew", arguments: ["services", "list"])
        execString.enumerateLines { line, _ in
            if line.hasPrefix("syncthing") {
                var statusArr = line.characters.split{$0 == " "}.map(String.init)
                self.syncthingStatus = statusArr[1]
            }
        }
        
        return self.syncthingStatus
    }

// MARK: - Menu - status config
    func updateUIStatus() {
        let running = getSyncthingStatus()
        
        if running == "started" {
            startItem.isHidden = true
            stopItem.isHidden = false

            restartItem.isEnabled = true
            reloadConfigValues()
        } else {
            startItem.isHidden = false
            stopItem.isHidden = true
            
            restartItem.isEnabled = false
            wipeConfigValues()
        }
        
        statusItem.title = "Syncthing: "+running
    }
    
// MARK: Menu - folder configuration
    func wipeConfigValues() {
        let menu = barItem.menu!
        
        // wipe current menu
        for _ in 0..<(menu.numberOfItems - (folderOffset + 2)) {
            barItem.menu!.removeItem(at: folderOffset)
        }
        
    }
    
    func reloadConfigValues() {
        wipeConfigValues()
        
        let config_url = URL(fileURLWithPath: config_xml)
        let parser = XMLParser(contentsOf:(config_url))!
        parser.delegate = self
        parser.parse()
    }
    
// MARK: - XMLParserDelegate implementation
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let menu = barItem.menu!
        
        if xmlLocation == ["configuration"] && elementName == "folder" {
            let pos = menu.numberOfItems - (folderOffset + 2)
            let folderItem = NSMenuItem(title: attributeDict["path"]!, action: #selector(AppDelegate.openFolder(sender:)), keyEquivalent: String(pos))
            barItem.menu!.insertItem(folderItem, at: folderOffset + pos)
        }
        
        if xmlLocation == ["configuration"] && elementName == "gui" {
            guiConfiguration = attributeDict
        }
        
        xmlLocation.append(elementName)
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        xmlLocation.removeLast()
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if xmlLocation == ["configuration", "gui", "address"] {
            guiConfiguration["address"] = string
        }
        
        if xmlLocation == ["configuration", "gui", "user"] {
            guiConfiguration["user"] = string
        }
        
    }

// MARK: - Helper functions OS interaction
    func openFolder(sender: NSMenuItem) {
        NSWorkspace.shared().selectFile(nil, inFileViewerRootedAtPath: sender.title)
    }
    
    func openBrowser(sender: NSMenuItem) {
        var urlstring = ""
        if guiConfiguration["tls"] == "true" {
            urlstring += "https://"
        } else {
            urlstring += "http://"
        }
        urlstring += guiConfiguration["user"]! + "@"
        urlstring += guiConfiguration["address"]!
        
        let url = URL(string: urlstring)
        NSWorkspace.shared().open(url!)
    }
}

