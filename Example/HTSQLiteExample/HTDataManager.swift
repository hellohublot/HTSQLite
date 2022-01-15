//
//  HTDataManager.swift
//  HTSQLiteExample
//
//  Created by hublot on 2022/1/15.
//

import Foundation
import HTSQLite


class HTDataManager {

    lazy var modelArray: [[String: Any]] = {
        let modelArray = [[String: Any]]()
        return modelArray
    }()

    lazy var sqlite: SQLite = {
        let path = NSHomeDirectory() + "/student.db"
        let create = """
            create table if not exists student (
                id integer primary key autoincrement,
                name varchar(50) default '' not null,
                score int default -1 not null,
                birthday timestamp default (datetime('now', 'localtime')) not null,
                createtime timestamp default (datetime('now', 'localtime')) not null,
                updatetime timestamp default (datetime('now', 'localtime')) not null
            );
        """
        let sqlite = SQLite.init(path: path, create: create)
        return sqlite
    }()

    func appendDataModel() {
        let prefixNameList = ["赵", "钱", "孙", "李", "周", "吴", "郑", "王"]
        let suffixNameList = ["一", "二", "三", "四", "五"]
        let name = prefixNameList[Int(arc4random_uniform(UInt32(prefixNameList.count)))] + suffixNameList[Int(arc4random_uniform(UInt32(suffixNameList.count)))]
        let score = Int(arc4random_uniform(80) + 20)
        let birthday = TimeInterval(arc4random_uniform(400000000) + 947946501)

        let sql = "insert into student " + SQLBind.insert([
            "name": name,
            "score": score,
            "birthday": Date.init(timeIntervalSince1970: birthday)
        ])
        sqlite.execute(sql)
    }

    func removeDataModelIndex(_ index: Int) {
        let model = modelArray[index]
        let id = Int(model["id"] as? String ?? "")
        let sql = "delete from student where " + SQLBind.whereEqual([
            "id": id
        ])
        sqlite.execute(sql)
    }

    func removeAllDataModel() {
        sqlite.execute("delete from student")
    }

    func selectDataModelList() {
        let modelArray = sqlite.execute("select * from student") ?? [[String: String]]()
        self.modelArray = modelArray
    }

    func editDataModelIndex(_ index: Int) {
        let model = modelArray[index]
        let id = Int(model["id"] as? String ?? "")
        let score = Int(arc4random_uniform(80) + 20)
        if index % 2 == 0 {
            let sql = "update student set " + SQLBind.update([
                "score": score,
            ]) + " where " + SQLBind.whereEqual([
                "id": id
            ])
            sqlite.execute(sql)
        } else {
            sqlite.transaction {
                let success = sqlite.update(tableName: "student", array: [[
                    "id": id,
                    "score": score
                ]])
                return success
            }
        }
    }


}
