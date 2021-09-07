//
//  ReportViewController.swift
//  TraccarManager
//
//  Created by Sergey Kruzhkov on 30.09.2017.
//  Copyright © 2017 Sergey Kruzhkov. All rights reserved.
//

import Foundation
import UIKit

class ReportViewController: UITableViewController {
    
    var devices: [Device] = []
    var geofences: [Geofence] = []
    var fromDate = Date()
    var toDate = Date()
    var tableSummary = [Summary]()
    var tableEvent = Dictionary<Int, [Event]>()
    var nameColumns = [String]()
    var keyColumns = [String]()
    var devicesCheck = [Bool]()
    var typeReport = typeReports.Summary

    override func viewDidLoad() {
        super.viewDidLoad()
    
        refreshControl?.addTarget(self, action: #selector(self.getRequestStart), for: UIControlEvents.valueChanged)
        
        let buttonFilter = UIBarButtonItem(image: #imageLiteral(resourceName: "Image_filter"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(self.getFilter))
        let buttonMap = UIBarButtonItem(image: #imageLiteral(resourceName: "Image_placeholder"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(self.getMapDetail))
        if typeReport == typeReports.Summary {
            self.navigationItem.rightBarButtonItems = [buttonFilter]
        } else if typeReport == typeReports.Events {
            self.navigationItem.rightBarButtonItems = [buttonFilter, buttonMap]
        }
        //if no records
        buttonMap.isEnabled = false
        
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        fromDate = Calendar.current.date(from: c)!
        
        toDate = Calendar.current.startOfDay(for: Date())
        toDate = Calendar.current.date(byAdding: Calendar.Component.day, value: 1, to: toDate)!
        toDate = Calendar.current.date(byAdding: Calendar.Component.second, value: -1, to: toDate)!
        
        setKeyColumns()
        setMainTitle()
        
        refreshControl?.beginRefreshing()
        refreshGeofence()
        refreshDevices()
        
    }
    
    func setKeyColumns() {
        if typeReport == typeReports.Summary {
            nameColumns = ["Name Device", "Distance", "Adverage Speed", "Maximum Speed", "Engine Hours"]
            keyColumns = ["devicename", "distance", "averageSpeed", "maxSpeed", "engineHours"]
        } else if typeReport == typeReports.Events {
            nameColumns = ["Time", "Type", "Geofence", "Attributes"]
            keyColumns = ["eventTime", "Type", "Geofence", "Attributes"]
        }
    }
    
    func setMainTitle() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd' 'HH:mm"
        
        if Definitions.isRunningOniPad {
            self.title = typeReport.rawValue + " " + formatter.string(from: fromDate) + "-" + formatter.string(from: toDate)
        } else {
            self.title = typeReport.rawValue
        }
    }
    
    @objc func getFilter() {
        self.performSegue(withIdentifier: "ShowFilter", sender: self)
    }
    
    @objc func getMapDetail() {
        let vc = self.storyboard!.instantiateViewController(withIdentifier: "DetailMapViewStoryboard")  as! DetailMapViewController
        for indexPath in tableView.indexPathsForSelectedRows! {
            let key = Array(tableEvent.keys)[indexPath.section]
            vc.SelectedEvents.append(tableEvent[key]![indexPath.row])
        }
        navigationController!.pushViewController(vc, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowFilter" {
            let vc = segue.destination as? FilterViewController
            vc?.devices = devices
            vc?.fromDate = fromDate
            vc?.toDate = toDate
            vc?.devicesCheck = devicesCheck
            vc?.delegate = self
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        
        var cell: UITableViewCell!
        if typeReport == typeReports.Summary {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellSummary")!
        } else if Definitions.isRunningOniPad && typeReport == typeReports.Events {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellEvents")!
        } else if typeReport == typeReports.Events {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellEventsHeader")!
        } else {
            cell  = tableView.dequeueReusableCell(withIdentifier: "cellSummary")!
        }
        
        if Definitions.isRunningOniPad {
            if typeReport == typeReports.Summary {
                for i in 0...nameColumns.count - 1 {
                    (cell.viewWithTag(i + 1) as! UILabel).text = nameColumns[i]
                }
            } else if typeReport == typeReports.Events {
                let key = Array(tableEvent.keys)[section]
                (cell.viewWithTag(1) as! UILabel).text = WebService.sharedInstance.deviceById(key)?.name
                (cell.viewWithTag(2) as! UILabel).text = String(tableEvent[key]!.count) + " events"
                (cell.viewWithTag(3) as! UILabel).text = ""
            }
        } else {
            if typeReport == typeReports.Summary {
                (cell.viewWithTag(1) as! UILabel).text = tableSummary[section].deviceName
                (cell.viewWithTag(2) as! UILabel).text = ""
            } else if typeReport == typeReports.Events {
                let key = Array(tableEvent.keys)[section]
                (cell.viewWithTag(1) as! UILabel).text = WebService.sharedInstance.deviceById(key)?.name
                (cell.viewWithTag(2) as! UILabel).text = String(tableEvent[key]!.count) + " events"
            }
        }
      
        cell.backgroundColor = UIColor.init(red: 235/255, green: 235/255, blue: 241/255, alpha: 1)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell!
        if typeReport == typeReports.Summary {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellSummary", for: indexPath) as UITableViewCell
        } else if typeReport == typeReports.Events {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellEvents", for: indexPath) as UITableViewCell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "cellSummary", for: indexPath) as UITableViewCell
        }
        
        if Definitions.isRunningOniPad {
            
            for i in 0...keyColumns.count - 1 {
                if typeReport == typeReports.Summary {
                    (cell.viewWithTag(i + 1) as! UILabel).text = tableSummary[indexPath.row].valueString(forKey: keyColumns[i])
                } else if typeReport == typeReports.Events {
                    var desc = ""
                    let key = Array(tableEvent.keys)[indexPath.section]
                    if keyColumns[i] == "Attributes" {
                        continue
                    } else if keyColumns[i] == "Geofence"{
                        let countattr = ((tableEvent[key] as [Event]!)[indexPath.row].attributes?.AttributeName.count)! - 1
                        if countattr > 0 {
                            for i in 0...countattr {
                                desc = desc + " "
                                    + ((tableEvent[key] as [Event]!)[indexPath.row].attributes?.AttributeName[i])! + " = "
                                    + ((tableEvent[key] as [Event]!)[indexPath.row].attributes?.AttributeValue[i])!
                            }
                        }
                    }
                    
                    (cell.viewWithTag(i + 1) as! UILabel).text = (tableEvent[key] as [Event]!)[indexPath.row].valueString(forKey: keyColumns[i]) + desc
                }
            }
            
        } else {
        
            if typeReport == typeReports.Summary {
                (cell.viewWithTag(1) as! UILabel).text = nameColumns[indexPath.row + 1]
                (cell.viewWithTag(2) as! UILabel).text = tableSummary[indexPath.section].valueString(forKey: keyColumns[indexPath.row  + 1])
            } else if typeReport == typeReports.Events {
                let key = Array(tableEvent.keys)[indexPath.section]
                (cell.viewWithTag(1) as! UILabel).text = "Time"
                (cell.viewWithTag(3) as! UILabel).text = "Type"
                (cell.viewWithTag(5) as! UILabel).text = "Geofence"
                (cell.viewWithTag(7) as! UILabel).text = "Attributes"
                (cell.viewWithTag(2) as! UILabel).text = (tableEvent[key] as [Event]!)[indexPath.row].valueString(forKey: "Time")
                (cell.viewWithTag(4) as! UILabel).text = (tableEvent[key] as [Event]!)[indexPath.row].valueString(forKey: "Type")
                (cell.viewWithTag(6) as! UILabel).text = (tableEvent[key] as [Event]!)[indexPath.row].valueString(forKey: "Geofence")
                (cell.viewWithTag(8) as! UILabel).text = (tableEvent[key] as [Event]!)[indexPath.row].valueString(forKey: "Attributes")
            }
            
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch typeReport {
        case .Summary:
            tableView.deselectRow(at: indexPath, animated: true)
        case .Events:
            //enable button map
            if tableView.indexPathsForSelectedRows?.count != 0 {
                let key = Array(tableEvent.keys)[indexPath.section]
                if tableEvent[key]![indexPath.row].positionId == 0 {
                    tableView.deselectRow(at: indexPath, animated: true)
                    self.showToast(message: "Сoordinates not found", withDuration: 3.0, width: 220.0)
                    self.dismiss(animated: true, completion: nil)
                } else {
                    self.navigationItem.rightBarButtonItems![1].isEnabled = true
                }
            }
        case .Route:
            tableView.deselectRow(at: indexPath, animated: true)
        case .Trips:
            tableView.deselectRow(at: indexPath, animated: true)
        case .Chart:
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
        if typeReport == .Events {
            //disable button map
            if tableView.indexPathsForSelectedRows == nil || tableView.indexPathsForSelectedRows?.count == 0 {
                self.navigationItem.rightBarButtonItems![1].isEnabled = false
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if Definitions.isRunningOniPad && typeReport == typeReports.Summary {
            return  (tableSummary.count == 0) ? 0 : 1
        } else if typeReport == typeReports.Summary {
            return tableSummary.count
        } else if typeReport == typeReports.Events {
            return tableEvent.count
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if Definitions.isRunningOniPad && typeReport == typeReports.Summary {
            return tableSummary.count
        } else if typeReport == typeReports.Events {
            let key = Array(tableEvent.keys)[section]
            return (tableEvent[key]?.count)!
        } else if typeReport == typeReports.Summary {
            return (tableSummary.count == 0) ? 0 : 4
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if !Definitions.isRunningOniPad && typeReport == typeReports.Events {
            return 70.0
        } else {
            return 50.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !Definitions.isRunningOniPad && typeReport == typeReports.Events {
            return 110.0
        } else {
            return 44.0
        }
    }
    
    @objc func getRequestStart() {
        
        tableSummary = [Summary]()
        tableEvent = Dictionary<Int, [Event]>()
        tableView.reloadData()
        
        refreshControl?.beginRefreshing()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        let from = formatter.string(from: fromDate)
        let to = formatter.string(from: toDate)
        
        var dev = "?"
        for i in  0...devicesCheck.count - 1 {
            if devicesCheck[i] {
                dev += "deviceId=" + String(devices[i].id!) + "&"
            }
        }
        
        let strReq = dev + "from=" + from + "&to=" + to
        
        var urlPoint = ""
        if self.typeReport == typeReports.Summary {
            urlPoint = "reports/summary"
        } else if self.typeReport == typeReports.Events {
            urlPoint = "reports/events"
        }
        
        WebService.sharedInstance.getDataServer(filter: strReq, urlPoint: urlPoint, onFailure: { errorString in
            
            DispatchQueue.main.async(execute: {
             
                let ac = UIAlertController(title: "Error request", message: errorString, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                ac.addAction(okAction)
                self.present(ac, animated: true, completion: nil)
                
                self.refreshControl?.endRefreshing()
                self.tableView.reloadData()
                
            })
            
            }, onSuccess: { (data) in
            
            DispatchQueue.main.async(execute: {
                
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                if self.typeReport == typeReports.Summary {
                    self.tableSummary = try! decoder.decode([Summary].self, from: data)
                } else if self.typeReport == typeReports.Events {
                    let te = try! decoder.decode([Event].self, from: data)
                    self.tableEvent = Dictionary(grouping: te, by: { (element: Event) -> Int in
                        return element.deviceId!
                    })
                }
                    
                self.refreshControl?.endRefreshing()
                self.tableView.reloadData()
            
            })
        })
        
    }
    
    @objc func refreshDevices() {
        
        WebService.sharedInstance.fetchDevices(onSuccess: { (newDevices) in
            self.devices = newDevices
            
            self.devicesCheck = [Bool]()
            for _ in self.devices {
                self.devicesCheck.append(false)
            }
            
            self.performSegue(withIdentifier: "ShowFilter", sender: self)
        })
        
    }
    
    @objc func refreshGeofence() {
        
        WebService.sharedInstance.fetchGeofences(onSuccess: { (newGeofences) in
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            self.geofences = newGeofences
        })
        
    }
}
