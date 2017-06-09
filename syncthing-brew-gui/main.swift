//
//  main.swift
//  syncthing-brew-gui
//
//  Created by Jonas Höchst on 09.06.17.
//  Copyright © 2017 Jonas Höchst. All rights reserved.
//

import Cocoa

autoreleasepool { () -> () in
    let app = NSApplication.shared()
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
