/* ======================= 第三部分：创建触发器 ======================= */
-- 1. 图书操作触发器
CREATE TRIGGER tr_book_operation
ON Book
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 声明变量
    DECLARE @operationType varchar(20),
            @bookNumber char(10),
            @bookName varchar(100);

    -- 确定操作类型并获取图书信息
    IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @operationType = '入库';
        SELECT TOP 1 @bookNumber = bookNumber, @bookName = bookName FROM inserted;
    END
    ELSE IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @operationType = '修改';
        SELECT TOP 1 @bookNumber = bookNumber, @bookName = bookName FROM inserted;
    END
    ELSE IF EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @operationType = '注销';
        SELECT TOP 1 @bookNumber = bookNumber, @bookName = bookName FROM deleted;
    END
    ELSE
        RETURN;

    -- 确保获取到了必要的信息
    IF @bookNumber IS NOT NULL AND @bookName IS NOT NULL
    BEGIN
        INSERT INTO Admin_Book(adminNo, bookNumber, operationDate, operationType, reason)
        VALUES('123jianzhu', @bookNumber, '2025-03-31 12:25:08', @operationType, 
               @operationType + '图书：' + @bookName);
    END
END;
GO

-- 2. 读者操作触发器
CREATE TRIGGER tr_reader_operation
ON Reader
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 声明变量
    DECLARE @operationType varchar(20),
            @readerNumber char(10),
            @userName varchar(20);

    -- 确定操作类型并获取读者信息
    IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @operationType = '办证';
        SELECT TOP 1 @readerNumber = readerNumber, @userName = userName FROM inserted;
    END
    ELSE IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @operationType = '修改';
        SELECT TOP 1 @readerNumber = readerNumber, @userName = userName FROM inserted;
    END
    ELSE IF EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @operationType = '注销';
        SELECT TOP 1 @readerNumber = readerNumber, @userName = userName FROM deleted;
    END
    ELSE
        RETURN;

    -- 确保获取到了必要的信息
    IF @readerNumber IS NOT NULL AND @userName IS NOT NULL
    BEGIN
        INSERT INTO Admin_Reader(adminNo, readerNumber, operationDate, operationType, reason, approval)
        VALUES('123jianzhu', @readerNumber, '2025-03-31 12:25:08', @operationType, 
               @operationType + '读者：' + @userName, '已审批');
    END
END;
GO

-- 3. 借书检查触发器
CREATE TRIGGER tr_borrow_check
ON Borrow
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 声明变量
    DECLARE @readerNumber char(10),
            @bookNumber char(10),
            @adminNo char(10),
            @maxCount int,
            @currentBorrowed int,
            @borrowRange varchar(50),
            @stackRoom varchar(20);

    -- 获取要插入的借阅信息
    SELECT TOP 1 
           @readerNumber = readerNumber,
           @bookNumber = bookNumber,
           @adminNo = adminNo
    FROM inserted;

    -- 检查必要信息是否完整
    IF @readerNumber IS NULL OR @bookNumber IS NULL OR @adminNo IS NULL
    BEGIN
        RAISERROR ('借阅信息不完整', 16, 1);
        RETURN;
    END

    -- 检查读者权限
    SELECT @maxCount = rt.maxCount,
           @borrowRange = rt.borrowRange
    FROM Reader r
    JOIN ReaderType rt ON r.readerType = rt.readerType
    WHERE r.readerNumber = @readerNumber;

    -- 检查读者权限是否存在
    IF @maxCount IS NULL OR @borrowRange IS NULL
    BEGIN
        RAISERROR ('读者类型信息不存在', 16, 1);
        RETURN;
    END

    -- 检查当前借阅数量
    SELECT @currentBorrowed = COUNT(*)
    FROM Borrow b
    WHERE b.readerNumber = @readerNumber
    AND NOT EXISTS (
        SELECT 1 FROM ReturnBook rb WHERE rb.borrowId = b.borrowId
    );

    -- 检查书库权限
    SELECT @stackRoom = stackRoom
    FROM Book
    WHERE bookNumber = @bookNumber;

    -- 检查图书信息是否存在
    IF @stackRoom IS NULL
    BEGIN
        RAISERROR ('图书信息不存在', 16, 1);
        RETURN;
    END

    -- 验证借阅权限
    IF @currentBorrowed >= @maxCount
    BEGIN
        RAISERROR ('超出最大借阅数量限制', 16, 1);
        RETURN;
    END

    -- 验证书库权限
    IF @stackRoom NOT IN (SELECT value FROM STRING_SPLIT(@borrowRange, ','))
    BEGIN
        RAISERROR ('该读者无权在此书库借书', 16, 1);
        RETURN;
    END


    -- 执行借书操作
    INSERT INTO Borrow(
        readerNumber, bookNumber, borrowDate, returnDeadline, adminNo
    )
    SELECT 
        i.readerNumber,
        i.bookNumber,
        '2025-03-31 12:25:08',
        DATEADD(day, 
            (SELECT dateDeadline FROM ReaderType rt 
             JOIN Reader r ON r.readerType = rt.readerType 
             WHERE r.readerNumber = i.readerNumber),
            '2025-03-31 12:25:08'),
        i.adminNo
    FROM inserted i;

    -- 更新图书库存
    UPDATE Book
    SET currentCount = currentCount - 1
    WHERE bookNumber = @bookNumber;

    -- 记录操作日志
    INSERT INTO Admin_Reader(
        adminNo, readerNumber, operationDate, operationType, reason, approval
    )
    VALUES(
        @adminNo,
        @readerNumber,
        '2025-03-31 12:25:08',
        '借书',
        '借阅图书：' + @bookNumber,
        '已批准'
    );
END;
GO

-- 4. 还书处理触发器
CREATE TRIGGER tr_return_book
ON ReturnBook
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 声明变量
    DECLARE @borrowId int,
            @bookNumber char(10),
            @readerNumber char(10),
            @adminNo char(10);

    -- 获取还书信息
    SELECT @borrowId = i.borrowId,
           @adminNo = i.adminNo
    FROM inserted i;

    -- 确保获取到了必要信息
    IF @borrowId IS NULL OR @adminNo IS NULL
    BEGIN
        RAISERROR ('还书信息不完整', 16, 1);
        RETURN;
    END

    -- 获取借阅信息
    SELECT @bookNumber = b.bookNumber,
           @readerNumber = b.readerNumber
    FROM Borrow b
    WHERE b.borrowId = @borrowId;

    -- 检查借阅信息是否存在
    IF @bookNumber IS NULL OR @readerNumber IS NULL
    BEGIN
        RAISERROR ('借阅信息不存在', 16, 1);
        RETURN;
    END

    -- 更新图书库存
    UPDATE Book
    SET currentCount = currentCount + 1
    WHERE bookNumber = @bookNumber;

    -- 记录操作日志
    INSERT INTO Admin_Reader(
        adminNo, readerNumber, operationDate, operationType, reason, approval
    )
    VALUES(
        @adminNo,
        @readerNumber,
        '2025-03-31 12:25:08',
        '还书',
        '归还图书：' + @bookNumber,
        '已完成'
    );
END;
GO