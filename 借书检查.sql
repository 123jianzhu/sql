-- 修改借书检查触发器
ALTER TRIGGER tr_borrow_check
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
            @stackRoom varchar(50),
            @readerType varchar(50);

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

    -- 获取读者类型和权限信息
    SELECT @readerType = r.readerType,
           @maxCount = rt.maxCount,
           @borrowRange = rt.borrowRange
    FROM Reader r
    JOIN ReaderType rt ON r.readerType = rt.readerType
    WHERE r.readerNumber = @readerNumber;

    -- 获取图书所在书库
    SELECT @stackRoom = stackRoom
    FROM Book
    WHERE bookNumber = @bookNumber;

    -- 检查读者类型是否存在
    IF @readerType IS NULL
    BEGIN
        RAISERROR ('读者类型信息不存在', 16, 1);
        RETURN;
    END

    -- 检查图书信息是否存在
    IF @stackRoom IS NULL
    BEGIN
        RAISERROR ('图书信息不存在', 16, 1);
        RETURN;
    END

    -- 检查书库权限（考虑去除空格后的精确匹配）
    DECLARE @hasPermission bit = 0;
    
    -- 分割借阅范围字符串并检查是否包含当前书库
    SELECT @hasPermission = 
        CASE WHEN EXISTS (
            SELECT 1 
            FROM STRING_SPLIT(@borrowRange, ',') 
            WHERE TRIM(value) = @stackRoom
        ) THEN 1 ELSE 0 END;

    IF @hasPermission = 0
    BEGIN
        RAISERROR ('该读者（%s）无权在%s借书，只能在%s借书', 16, 1, 
            @readerType, @stackRoom, @borrowRange);
        RETURN;
    END

    -- 检查当前借阅数量
    SELECT @currentBorrowed = COUNT(*)
    FROM Borrow b
    WHERE b.readerNumber = @readerNumber
    AND NOT EXISTS (
        SELECT 1 FROM ReturnBook rb WHERE rb.borrowId = b.borrowId
    );

    IF @currentBorrowed >= @maxCount
    BEGIN
        RAISERROR ('超出最大借阅数量限制，最多可借%d本', 16, 1, @maxCount);
        RETURN;
    END

    -- 检查图书是否可借
    IF NOT EXISTS (
        SELECT 1 FROM Book 
        WHERE bookNumber = @bookNumber AND currentCount > 0
    )
    BEGIN
        RAISERROR ('图书已全部借出，暂时无法借阅', 16, 1);
        RETURN;
    END

    -- 执行借书操作
    INSERT INTO Borrow(
        readerNumber, bookNumber, borrowDate, returnDeadline, adminNo
    )
    SELECT 
        i.readerNumber,
        i.bookNumber,
        '2025-04-01 00:43:21',
        DATEADD(day, 
            (SELECT dateDeadline FROM ReaderType rt 
             JOIN Reader r ON r.readerType = rt.readerType 
             WHERE r.readerNumber = i.readerNumber),
            '2025-04-01 00:43:21'),
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
        '2025-04-01 00:43:21',
        '借书',
        '借阅图书：' + @bookNumber,
        '已批准'
    );
END;
GO

-- 运行测试脚本
-- 创建临时表来记录所有测试尝试
CREATE TABLE #BorrowAttempts (
    attemptId INT IDENTITY(1,1) PRIMARY KEY,
    readerNumber char(10),
    bookNumber char(10),
    attemptTime datetime,
    isSuccess bit,
    errorMessage nvarchar(500)
);

-- 清理之前的测试数据
DELETE FROM ReturnBook WHERE borrowId IN (
    SELECT borrowId FROM Borrow 
    WHERE borrowDate >= '2025-04-01 00:43:21'
);
DELETE FROM Borrow WHERE borrowDate >= '2025-04-01 00:43:21';

-- 测试1: 松山湖校区学生借松山湖校区的书(应该成功)
SELECT '=== 测试1: 松山湖校区学生借松山湖校区的书(应该成功) ===' AS '测试步骤';
BEGIN TRY
    INSERT INTO Borrow(readerNumber, bookNumber, borrowDate, returnDeadline, adminNo)
    VALUES('R20230001', 'B20230001', '2025-04-01 00:43:21', 
    DATEADD(day, 30, '2025-04-01 00:43:21'), '123jianzhu');
    
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230001', 'B20230001', '2025-04-01 00:43:21', 1, NULL);
    
    SELECT '测试1结果: 借阅成功' AS '执行结果';
END TRY
BEGIN CATCH
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230001', 'B20230001', '2025-04-01 00:43:21', 0, ERROR_MESSAGE());
    
    SELECT '测试1结果: 借阅失败' AS '执行结果';
    SELECT '错误信息: ' + ERROR_MESSAGE() AS '错误详情';
END CATCH

-- 测试2: 松山湖校区学生借莞城校区的书(应该失败)
SELECT '=== 测试2: 松山湖校区学生借莞城校区的书(应该失败) ===' AS '测试步骤';
BEGIN TRY
    INSERT INTO Borrow(readerNumber, bookNumber, borrowDate, returnDeadline, adminNo)
    VALUES('R20230001', 'B20230005', '2025-04-01 00:43:21', 
    DATEADD(day, 30, '2025-04-01 00:43:21'), '123jianzhu');
    
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230001', 'B20230005', '2025-04-01 00:43:21', 1, NULL);
    
    SELECT '测试2结果: 借阅成功（不应该出现此结果）' AS '执行结果';
END TRY
BEGIN CATCH
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230001', 'B20230005', '2025-04-01 00:43:21', 0, ERROR_MESSAGE());
    
    SELECT '测试2结果: 借阅失败' AS '执行结果';
    SELECT '错误信息: ' + ERROR_MESSAGE() AS '错误详情';
END CATCH

-- 显示测试结果
SELECT '=== 借阅测试结果汇总 ===' AS '测试步骤';

SELECT 
    r.userName as '读者姓名',
    r.readerType as '读者类型',
    rt.borrowRange as '允许借阅范围',
    b.bookName as '图书名称',
    b.stackRoom as '所在书库',
    CONVERT(varchar, ba.attemptTime, 120) as '尝试时间',
    CASE 
        WHEN ba.isSuccess = 1 THEN '借阅成功'
        ELSE '借阅失败'
    END as '借阅结果',
    ba.errorMessage as '失败原因'
FROM #BorrowAttempts ba
JOIN Reader r ON ba.readerNumber = r.readerNumber
JOIN ReaderType rt ON r.readerType = rt.readerType
JOIN Book b ON ba.bookNumber = b.bookNumber
ORDER BY ba.attemptTime DESC;

-- 显示当前图书库存状态
SELECT '=== 当前图书库存状态 ===' AS '测试步骤';

SELECT 
    bookNumber as '图书编号',
    bookName as '图书名称',
    stackRoom as '所在书库',
    totalCount as '总数量',
    currentCount as '当前可借数量'
FROM Book
WHERE bookNumber IN ('B20230001', 'B20230005');

-- 删除临时表
DROP TABLE #BorrowAttempts;