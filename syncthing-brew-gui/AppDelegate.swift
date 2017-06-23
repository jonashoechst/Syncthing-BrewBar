//
//  AppDelegate.swift
//  syncthing-brew-gui
//
//  Created by Jonas Höchst on 08.06.17.
//  Copyright © 2017 Jonas Höchst. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, XMLParserDelegate {

// MARK: - menu items
    let barItem = NSStatusBar.system().statusItem(withLength: -2)
    let statusItem = NSMenuItem(title: "Syncthing: status unknown", action: nil, keyEquivalent: "")
    let startItem = NSMenuItem(title: "Start Syncthing", action: #selector(AppDelegate.startSyncthing), keyEquivalent: "")
    let stopItem = NSMenuItem(title: "Stop Syncthing", action: #selector(AppDelegate.stopSyncthing), keyEquivalent: "")
    let restartItem = NSMenuItem(title: "Restart Syncthing", action: #selector(AppDelegate.restartSyncthing), keyEquivalent: "R")
    let browserItem = NSMenuItem(title: "Open WebUI", action: #selector(AppDelegate.openBrowser(sender:)), keyEquivalent: "n")
    var folderOffset = 0
    
// MARK: - syncthing variables and locations
    let config_xml = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]+"/Syncthing/config.xml"
    var syncthingStatus = "undefined"
    var guiConfiguration: Dictionary<String, String> = [:]
    var xmlLocation: Array<String> = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let barButton = barItem.button!
        barButton.image = NSImage(named: "syncthing-bar")
        
        let menu = NSMenu()
        menu.addItem(statusItem)
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(restartItem)
        menu.addItem(browserItem)
        
        // Folder Items will go here
        folderOffset = menu.numberOfItems
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.shared().terminate(_:)), keyEquivalent: "q"))
        
        statusItem.isEnabled = false
        menu.autoenablesItems = false
//        barItem.action = #selector(updateUIAsync)
        barItem.menu = menu

        // Set unknown status and trigger status update
        updateUIStatus("...")
        updateUIAsync(sender: self)
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
    
    func execAsyncAndUpdate(launchPath: String, arguments: [String]) {
        DispatchQueue.global(qos: .background).async {
            let execString = self.execCmd(launchPath: launchPath, arguments: arguments)
            print(execString)
            
            let running = self.getSyncthingStatus()
            DispatchQueue.main.async {
                self.updateUIStatus(running)
            }
        }
    }
    
    func startSyncthing() {
        updateUIStatus("starting...")
        execAsyncAndUpdate(launchPath: "/usr/local/bin/brew", arguments: ["services", "start", "syncthing"])
    }
    
    func stopSyncthing() {
        updateUIStatus("stopping...")
        execAsyncAndUpdate(launchPath: "/usr/local/bin/brew", arguments: ["services", "stop", "syncthing"])
    }
    
    func restartSyncthing() {
        updateUIStatus("restarting...")
        execAsyncAndUpdate(launchPath: "/usr/local/bin/brew", arguments: ["services", "restart", "syncthing"])
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
    func updateUIStatus(_ running: String) {
        
        if running == "started" || running == "error" {
            startItem.isHidden = true
            stopItem.isHidden = false

            restartItem.isEnabled = true
            browserItem.isEnabled = true
            reloadConfigValues()
            
        } else if running == "stopped" {
            startItem.isHidden = false
            stopItem.isHidden = true
            
            restartItem.isEnabled = false
            browserItem.isEnabled = false
            wipeConfigValues()
        } else {

            startItem.isHidden = true
            stopItem.isHidden = true
            
            restartItem.isEnabled = false
            browserItem.isEnabled = false
            wipeConfigValues()
        }
        
        statusItem.title = "Syncthing: " + running
    }
    
    func updateUIAsync(sender: AnyObject) {
        DispatchQueue.global(qos: .background).async {
            let running = self.getSyncthingStatus()
            self.updateUIStatus(running)
            print("Updated async")
        }
    }
    
// MARK: Menu - folder configuration
    func wipeConfigValues() {
        let menu = barItem.menu!
        
        // wipe current menu
        for _ in folderOffset..<(menu.numberOfItems - 2) {
            menu.removeItem(at: folderOffset)
        }
    }
    
    func reloadConfigValues() {
        wipeConfigValues()
        
        let config_url = URL(fileURLWithPath: config_xml)
        let parser = XMLParser(contentsOf:(config_url))!
        parser.delegate = self
        parser.parse()
        
        let menu = barItem.menu!
        menu.insertItem(NSMenuItem.separator(), at: menu.numberOfItems - 1)
    }
    
// MARK: - XMLParserDelegate implementation
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let menu = barItem.menu!
        
        if xmlLocation == ["configuration"] && elementName == "folder" {
            let pos = menu.numberOfItems - folderOffset - 1
            let folderItem = NSMenuItem(title: attributeDict["path"]!, action: #selector(AppDelegate.openFolder(sender:)), keyEquivalent: String(pos))
            menu.insertItem(folderItem, at: folderOffset + pos)
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

