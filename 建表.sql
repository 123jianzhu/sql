
/* ======================= 第一部分：创建表 ======================= */
-- 1. 管理员表
CREATE TABLE Administrator (
    adminNo char(10) PRIMARY KEY,
    adminPassword varchar(20) NOT NULL,
    adminName varchar(20) NOT NULL,
    phone varchar(15) NOT NULL
);

-- 2. 读者类型表
CREATE TABLE ReaderType (
    readerType varchar(20) PRIMARY KEY,
    borrowRange varchar(50) NOT NULL,    -- 借阅范围（书库）
    maxCount int NOT NULL,               -- 最大借书数量
    dateDeadline int NOT NULL            -- 借书期限（天）
);

-- 3. 读者表
CREATE TABLE Reader (
    readerNumber char(10) PRIMARY KEY,   -- 借书证号
    userName varchar(20) NOT NULL,       -- 姓名
    sex char(2) NOT NULL,               -- 性别
    birthday date NOT NULL,             -- 出生日期
    idNumber varchar(18) NOT NULL,      -- 身份证号
    workplace varchar(50) NOT NULL,      -- 单位
    address varchar(100) NOT NULL,       -- 通讯地址
    postcode char(6) NOT NULL,          -- 邮政编码
    phone varchar(15) NOT NULL,         -- 联系电话
    createDate datetime NOT NULL,        -- 办证日期
    readerType varchar(20) NOT NULL,    -- 读者类型
    photo varbinary(max) NULL,          -- 照片
    work varchar(50) NOT NULL,          -- 职业
    status char(1) NOT NULL DEFAULT '1', -- 状态（1-有效 0-注销）
    CONSTRAINT FK_Reader_Type FOREIGN KEY (readerType) 
        REFERENCES ReaderType(readerType)
);

-- 4. 图书表
CREATE TABLE Book (
    bookNumber char(10) PRIMARY KEY,     -- 书号
    bookName varchar(100) NOT NULL,      -- 书名
    author varchar(50) NOT NULL,         -- 作者
    publisher varchar(50) NOT NULL,      -- 出版单位
    publishDate date NOT NULL,           -- 出版日期
    version int NOT NULL,                -- 版次
    price decimal(10,2) NOT NULL,        -- 单价
    summary varchar(500) NOT NULL,       -- 内容提要
    classNumber varchar(20) NOT NULL,    -- 分类号
    callNumber varchar(20) NOT NULL,     -- 索书号
    totalCount int NOT NULL,             -- 藏书总数
    currentCount int NOT NULL,           -- 当前可借数量
    registerNumber varchar(20) NOT NULL, -- 图书馆藏注册号
    stackRoom varchar(20) NOT NULL,      -- 所在书库
    inDate datetime NOT NULL,            -- 入库日期
    status char(1) NOT NULL DEFAULT '1'  -- 状态（1-在库 0-注销）
);

-- 5. 图书管理日志表
CREATE TABLE Admin_Book (
    logId int IDENTITY(1,1) PRIMARY KEY,
    adminNo char(10) NOT NULL,
    bookNumber char(10) NOT NULL,
    operationDate datetime NOT NULL,
    operationType varchar(20) NOT NULL,   -- 操作类型
    reason varchar(200) NOT NULL,
    CONSTRAINT FK_Admin_Book_Admin FOREIGN KEY (adminNo) REFERENCES Administrator(adminNo),
    CONSTRAINT FK_Admin_Book_Book FOREIGN KEY (bookNumber) REFERENCES Book(bookNumber)
);

-- 6. 读者管理日志表
CREATE TABLE Admin_Reader (
    logId int IDENTITY(1,1) PRIMARY KEY,
    adminNo char(10) NOT NULL,
    readerNumber char(10) NOT NULL,
    operationDate datetime NOT NULL,
    operationType varchar(20) NOT NULL,   -- 操作类型
    reason varchar(200) NOT NULL,
    approval varchar(20) NOT NULL,        -- 审批记录
    CONSTRAINT FK_Admin_Reader_Admin FOREIGN KEY (adminNo) REFERENCES Administrator(adminNo),
    CONSTRAINT FK_Admin_Reader_Reader FOREIGN KEY (readerNumber) REFERENCES Reader(readerNumber)
);

-- 7. 借书表
CREATE TABLE Borrow (
    borrowId int IDENTITY(1,1) PRIMARY KEY,
    readerNumber char(10) NOT NULL,
    bookNumber char(10) NOT NULL,
    borrowDate datetime NOT NULL,
    returnDeadline datetime NOT NULL,     -- 应还日期
    adminNo char(10) NOT NULL,
    CONSTRAINT FK_Borrow_Reader FOREIGN KEY (readerNumber) REFERENCES Reader(readerNumber),
    CONSTRAINT FK_Borrow_Book FOREIGN KEY (bookNumber) REFERENCES Book(bookNumber),
    CONSTRAINT FK_Borrow_Admin FOREIGN KEY (adminNo) REFERENCES Administrator(adminNo)
);

-- 8. 还书表
CREATE TABLE ReturnBook (
    returnId int IDENTITY(1,1) PRIMARY KEY,
    borrowId int NOT NULL,
    returnDate datetime NOT NULL,
    adminNo char(10) NOT NULL,
    CONSTRAINT FK_ReturnBook_Borrow FOREIGN KEY (borrowId) REFERENCES Borrow(borrowId),
    CONSTRAINT FK_ReturnBook_Admin FOREIGN KEY (adminNo) REFERENCES Administrator(adminNo)
);
GO