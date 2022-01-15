//
//  ViewController.swift
//  HTSQLiteExample
//
//  Created by hublot on 2022/1/15.
//

import UIKit
import HTSQLite

class ViewController: UIViewController {

    lazy var dataManager: HTDataManager = {
        let dataManager = HTDataManager()
        return dataManager
    }()

    lazy var tableView: UITableView = {
        let tableView = UITableView.init(frame: CGRect.zero)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: NSStringFromClass(UITableViewCell.self))
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        initDataSource()
        initUserInterface()
    }

    func initDataSource() {
        dataManager.selectDataModelList()
        if dataManager.modelArray.count <= 0 {
            dataManager.appendDataModel()
            dataManager.appendDataModel()
            dataManager.appendDataModel()
            dataManager.selectDataModelList()
        }
        tableView.reloadData()
    }

    func initUserInterface() {
        tableView.frame = view.bounds
        view.addSubview(tableView)
        navigationItem.leftBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .trash, target: self, action: #selector(removeAllBarItemDidTouch))
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .add, target: self, action: #selector(appendBarItemDidTouch))
    }

    @objc func appendBarItemDidTouch() {
        dataManager.appendDataModel()
        dataManager.selectDataModelList()
        tableView.reloadData()
    }

    @objc func removeAllBarItemDidTouch() {
        dataManager.removeAllDataModel()
        dataManager.selectDataModelList()
        tableView.reloadData()
    }


}

extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataManager.modelArray.count
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {
            return
        }
        dataManager.removeDataModelIndex(indexPath.row)
        dataManager.selectDataModelList()
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dataManager.editDataModelIndex(indexPath.row)
        dataManager.selectDataModelList()
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(UITableViewCell.self), for: indexPath)
        let model = dataManager.modelArray[indexPath.row]
        cell.textLabel?.text = "\(model["name"] as? String ?? "")\t\(model["score"] as? String ?? "")\t\t\(model["birthday"] as? String ?? "")"
        return cell
    }

}
