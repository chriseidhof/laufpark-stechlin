//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport


let x = "Laufpark Stechlin - Wabe Gelb/Strecke 1".drop(while: { $0 != "/" }).dropFirst()
x
