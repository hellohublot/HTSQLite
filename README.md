## Features

- The sqlite3 is encapsulated, the dictionary is directly passed, and bound to sql, including blob data can also be bound to sql
- support updateOrInsert
- Support transaction transaction

## Usage

[Example](./Example/HTSQLiteExample/HTDataManager.swift)

```ruby
pod 'HTSQLite', :git => 'https://github.com/hellohublot/HTSQLite.git'
```
```swift

// create
let path = NSHomeDirectory() + "/student.db"
let create = """
    create table if not exists student (
        id integer primary key autoincrement,
        name varchar(50) default '' not null,
        score int default -1 not null,
    );
"""
let sqlite = SQLite.init(path: path, create: create)

// insert
let insert = "insert into student " + SQLBind.insert([
    "name": name,
    "score": score
])
sqlite.execute(insert)

// update
let update = "update student set " + SQLBind.update([
    "score": score,
]) + " where " + SQLBind.whereEqual([
    "id": id
])
sqlite.execute(update)

// transaction + updateOrInsert
sqlite.transaction {
    let success = sqlite.update(tableName: "student", array: [[
        "id": id,
        "score": score
    ]])
    return success
}


```

## Author

hellohublot, hublot@aliyun.com
