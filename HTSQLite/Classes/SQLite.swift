//
//  SQLite.swift
//  Alamofire
//
//  Created by hublot on 2017/12/21.
//

import Foundation
import SQLite3

open class SQLite {
	
    public static var queue = DispatchQueue.init(label: "com.hublot.sqlite.queue")
	
	open var sqlite: OpaquePointer?
	
    public static func cString(_ sString: String?) -> [Int8] {
		guard let string = sString, string.count > 0 else {
			return [Int8]()
		}
		let c: [Int8] = {
			if var c = string.cString(using: .utf8) {
				if c.count > 0 {
					c.removeLast()
				}
				return c
			} else {
				let count = string.maximumLengthOfBytes(using: .ascii)
				var buffer = [Int8].init(repeating: 0, count: count)
				string.withCString({ start in
					for i in 0..<count {
						buffer[i] = start.advanced(by: i).pointee
					}
				})
				return buffer
			}
		}()
		return c
	}
	
    public static func cString(_ data: Data?) -> [Int8] {
		let count = data?.count ?? 0
		var buffer = [Int8].init(repeating: 0, count: count)
        data?.withUnsafeBytes({ (start: UnsafeRawBufferPointer) in
            guard let startAddress = start.bindMemory(to: Int8.self).baseAddress else {
                return
            }
            for i in 0..<count {
                buffer[i] = startAddress.advanced(by: i).pointee
            }
        })
		return buffer
	}
	
    public static func sString(_ point: UnsafeRawPointer?) -> String {
		var s: String?
		if let point = unsafeBitCast(point, to: UnsafePointer<Int8>?.self) {
			s = String.init(cString: point, encoding: .utf8)
		}
		return s ?? ""
	}
	
	public init(path: String, create: String? = nil) {
		let path = type(of: self).cString(path)
		sqlite3_open(path, &sqlite)
		if let create = create {
			execute(SQLBind.init(create))
		}
	}

	@discardableResult
	open func execute(_ sql: String) -> [[String:String]]? {
		return execute(SQLBind.init(sql))?.map { datakeyvalue -> [String: String] in
			var stringkeyvalue = [String: String]()
			for (key, value) in datakeyvalue {
				stringkeyvalue[key] = String.init(data: value, encoding: .utf8)
			}
			return stringkeyvalue
		}
	}
	
	@discardableResult
	open func execute(_ bind: SQLBind) -> [[String:Data]]? {
		guard let pointer = sqlite else {
			return nil
		}
		let selfclass = type(of: self)
		let sql = selfclass.cString(bind.sql)
		var stmt: OpaquePointer?
		
		
		guard sqlite3_prepare_v2(pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
			return nil
		}
		
		var bufferlist = [[Int8]]()
		
		for (rekey, value) in bind.list {
			let index = sqlite3_bind_parameter_index(stmt, SQLite.cString(rekey))
			var bindresult = SQLITE_OK
			switch value.self {
			case let double as Double:
				bindresult = sqlite3_bind_double(stmt, index, double)
				break
			case let int as Int:
				bindresult = sqlite3_bind_int(stmt, index, Int32(int))
				break
			case let data as Data:
				let buffer = SQLite.cString(data)
				let count = Int32(buffer.count)
				bufferlist.append(buffer)
				bindresult = sqlite3_bind_blob(stmt, index, buffer, count, nil)
				break
			case let date as Date:
				let string = SQLBind.dateformatter.string(from: date)
				let buffer = SQLite.cString(string)
				let count = Int32(buffer.count)
				bufferlist.append(buffer)
				bindresult = sqlite3_bind_text(stmt, index, buffer, count, nil)
				break
			default:
				let string = "\(value ?? SQLite.nullString)"
				let buffer = SQLite.cString(string)
				let count = Int32(buffer.count)
				bufferlist.append(buffer)
				bindresult = sqlite3_bind_text(stmt, index, buffer, count, nil)
				break
			}
			guard bindresult == SQLITE_OK else {
				return nil
			}
		}
		
		
		var result: [[String:Data]]? = nil
		let step = sqlite3_step(stmt)
		if step == SQLITE_DONE {
			result = [[String:Data]]()
		} else if (step == SQLITE_ROW) {
			result = [[String:Data]]()
			repeat {
				let column = sqlite3_column_count(stmt)
				var dictionary = [String:Data]()
				for i in 0..<column {
					let name = sqlite3_column_name(stmt, i)
					let key = selfclass.sString(name)
					let blob = sqlite3_column_text(stmt, i)
					let count = sqlite3_column_bytes(stmt, i)
					if let blob = blob {
						let value = Data.init(bytes: blob, count: Int(count))
						dictionary[key] = value
					}
				}
				result?.append(dictionary)
			} while (sqlite3_step(stmt) == SQLITE_ROW)
		}
		sqlite3_clear_bindings(stmt)
		sqlite3_finalize(stmt)
		return result
	}
	
	open func close() {
		guard let pointer = sqlite else {
			return
		}
		sqlite3_close(pointer)
	}
	
}

public protocol AllowValue {
	
}
extension String: AllowValue { }
extension Double: AllowValue { }
extension Int: AllowValue { }
extension Data: AllowValue { }
extension Date: AllowValue { }

open class SQLBind {
	
    public let sql: String
	
    public let list: [String: AllowValue?]
	
	private static var flag = 0
	
	public init(_ key: String, _ value: AllowValue?) {
		let rekey = ":" + "\(type(of: self).flag)" + "_" + key
		type(of: self).flag += 1
		self.sql = rekey
		var list = [String: AllowValue?]()
		list[rekey] = value
		self.list = list
	}
	
	public init(_ sql: String) {
		self.sql = sql
		self.list = [String: AllowValue?]()
	}
	
	private init(_ sql: String, _ list: [String: AllowValue?]) {
		self.sql = sql
		self.list = list
	}
	
	public static func insert(_ dictionary: [String: AllowValue?]) -> SQLBind {
		guard dictionary.count > 0 else {
			return SQLBind.init("")
		}
		var keyArray = [String]()
		var valueArray = [String]()
		var bindlist = [String: AllowValue?]()
		for (key, value) in dictionary {
			let bind = SQLBind.init(key, value)
			if let (rekey, value) = bind.list.first {
				bindlist[rekey] = value
				keyArray.append(key)
				valueArray.append(rekey)
			}
		}
		let keyString = "(" + keyArray.joined(separator: ", ") + ")"
		let valueString = "(" + valueArray.joined(separator: ", ") + ")"
		let sql = keyString + " values " + valueString
		let bind = SQLBind.init(sql, bindlist)
		return bind
	}
	
	private static func keyValue(_ dictionary: [String: AllowValue?], _ separator: String) -> SQLBind {
		guard dictionary.count > 0 else {
			return SQLBind.init("")
		}
		var bindlist = [String: AllowValue?]()
		var keyValueArray = [String]()
		for (key, value) in dictionary {
			let bind = SQLBind.init(key, value)
			if let (rekey, value) = bind.list.first {
				bindlist[rekey] = value
				keyValueArray.append("\(key) = " + rekey)
			}
		}
		let sql = keyValueArray.joined(separator: separator)
		let bind = SQLBind.init(sql, bindlist)
		return bind
	}
	
	public static func update(_ dictionary: [String: AllowValue?]) -> SQLBind {
		return keyValue(dictionary, ", ")
	}
	
	public static func whereEqual(_ dictionary: [String: AllowValue?]) -> SQLBind {
		return keyValue(dictionary, " and ")
	}
	
	public static func + (value: String, other: SQLBind) -> SQLBind {
		let sql = value + other.sql
		return SQLBind.init(sql, other.list)
	}
	
	public static func + (this: SQLBind, value: String) -> SQLBind {
		let sql = this.sql + value
		return SQLBind.init(sql, this.list)
	}
	
	public static func + (this: SQLBind, other: SQLBind) -> SQLBind {
		let sql = this.sql + other.sql
		var list = this.list
		for (rekey, value) in other.list {
			list[rekey] = value
		}
		return SQLBind.init(sql, list)
	}
	
	public static let dateformatter: DateFormatter = {
		let dateformatter = DateFormatter()
		dateformatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
		return dateformatter
	}()
	
}

extension SQLite {
	
    public static let nullString = "null"
	
	open class TableColumn {

		var name: String = ""

		var type: String = ""

		var notnull: Int = 0

		var dfltValue: String? = ""

		var pk: Int = 0

		public static func packModel(name: String, type: String, notnull: String, dfltValue: String?, pk: String) -> TableColumn {
            let model = TableColumn()
//            model.dfltValue = dfltValue
			model.name = name
			model.type = type
			model.notnull = Int(notnull) ?? 1
			model.pk = Int(pk) ?? 0
            return model
		}
	}
	
	open func tableInfo(tableName: String) -> [TableColumn] {
		var columnArray = [TableColumn]()
		let sql = "pragma table_info('\(tableName)')"
		let result = execute(sql) ?? [[String: String]]()
		for row in result {
			let name = row["name"] ?? ""
			let type = row["type"] ?? ""
			var notnull = row["notnull"] ?? ""
			var dflt_value: String?
			if let defaultValue = row["dflt_value"] {
				dflt_value = defaultValue
			}
			let pk = row["pk"] ?? ""

			if type.caseInsensitiveCompare("INTEGER").rawValue == 0 {
				notnull = "0"
			}
            let model = TableColumn.packModel(name: name, type: type, notnull: notnull, dfltValue: dflt_value, pk: pk)
			columnArray.append(model)
		}
		return columnArray
	}
	
	open func validate(columnArray: [TableColumn], dictionary: [String: AllowValue?]) -> Bool {
		for column in columnArray {
			let value = dictionary[column.name] ?? nil
			var isnull = false
			if let value = value as? String, value == SQLite.nullString {
				isnull = true
			} else if (value == nil) {
				isnull = true
			}
			if (isnull && column.notnull != 0 && nil == column.dfltValue) {
				return false
			}
		}
		return true
	}

    public func transaction(_ transactionBlock: (() -> Bool)) {
        execute("begin;")
        let success = transactionBlock()
        if success {
            execute("commit;")
        } else {
            execute("rollback;")
        }
    }
	
	@discardableResult
	open func update(tableName: String, columnArray: [TableColumn], dictionary: [String:AllowValue?]) -> Bool {
//		guard validate(columnArray: columnArray, dictionary: dictionary) else {
//			return false
//		}
		var whereDictionary = [String:AllowValue?]()
		var keyValeuDictionary = [String:AllowValue?]()
		for column in columnArray {
			let key = column.name
			let value = dictionary[column.name]
			keyValeuDictionary[key] = value
			if column.pk == 1 {
				whereDictionary[key] = value
			}
		}
		
		let whereBind = SQLBind.whereEqual(whereDictionary)
		
		let existRow: Bool = {
			var exist = false
			if whereBind.list.count > 0 {
				let bind = "select * from \(tableName) where " + whereBind + " limit 1 offset 0"
				if (execute(bind)?.count ?? 0) > 0 {
					exist = true
				}
			}
			return exist
		}()
		
		if existRow {
			let updateBind = SQLBind.update(keyValeuDictionary)
			let bind = "update \(tableName) set " + updateBind + " where " + whereBind
			return execute(bind) != nil
		} else {
			let insertBind = SQLBind.insert(keyValeuDictionary)
			let bind = "insert into " + tableName + " " + insertBind
			return execute(bind) != nil
		}
	}
	
	@discardableResult
	open func update(tableName: String, array: [[String:AllowValue?]]) -> Bool {
		let columnArray = tableInfo(tableName: tableName)
		for dictionary in array {
			let success = update(tableName: tableName, columnArray: columnArray, dictionary: dictionary)
			if success == false {
				return false
			}
		}
		return true
	}

}
