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
    WHERE borrowDate >= '2025-03-31 13:10:32'
);
DELETE FROM Borrow WHERE borrowDate >= '2025-03-31 13:10:32';

-- 1. 显示测试标题
SELECT '=== 测试数据信息 ===' AS '测试步骤';

-- 2. 显示测试用的读者和图书信息
SELECT '读者信息' as '信息类型', 
    readerNumber as '编号',
    userName as '姓名',
    readerType as '类型'
FROM Reader 
WHERE readerNumber IN ('R20230001', 'R20230003')
UNION ALL
SELECT '图书信息',
    bookNumber,
    bookName,
    stackRoom
FROM Book
WHERE bookNumber IN ('B20230001', 'B20230005');

-- 3. 测试1: 松山湖校区学生借松山湖校区的书(应该成功)
SELECT '=== 测试1: 松山湖校区学生借松山湖校区的书(应该成功) ===' AS '测试步骤';
BEGIN TRY
    INSERT INTO Borrow(readerNumber, bookNumber, borrowDate, returnDeadline, adminNo)
    VALUES('R20230001', 'B20230001', '2025-03-31 13:10:32', 
    DATEADD(day, 30, '2025-03-31 13:10:32'), '123jianzhu');
    
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230001', 'B20230001', '2025-03-31 13:10:32', 1, NULL);
    
    SELECT '测试1结果: 借阅成功' AS '执行结果';
END TRY
BEGIN CATCH
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230001', 'B20230001', '2025-03-31 13:10:32', 0, ERROR_MESSAGE());
    
    SELECT '测试1结果: 借阅失败' AS '执行结果';
    SELECT '错误信息: ' + ERROR_MESSAGE() AS '错误详情';
END CATCH

-- 4. 测试2: 松山湖校区学生借莞城校区的书(应该失败)
SELECT '=== 测试2: 松山湖校区学生借莞城校区的书(应该失败) ===' AS '测试步骤';
BEGIN TRY
    INSERT INTO Borrow(readerNumber, bookNumber, borrowDate, returnDeadline, adminNo)
    VALUES('R20230001', 'B20230005', '2025-03-31 13:10:32', 
    DATEADD(day, 30, '2025-03-31 13:10:32'), '123jianzhu');
    
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230001', 'B20230005', '2025-03-31 13:10:32', 1, NULL);
    
    SELECT '测试2结果: 借阅成功（不应该出现此结果）' AS '执行结果';
END TRY
BEGIN CATCH
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230001', 'B20230005', '2025-03-31 13:10:32', 0, ERROR_MESSAGE());
    
    SELECT '测试2结果: 借阅失败' AS '执行结果';
    SELECT '错误信息: ' + ERROR_MESSAGE() AS '错误详情';
END CATCH

-- 5. 测试3: 莞城校区学生借莞城校区的书(应该成功)
SELECT '=== 测试3: 莞城校区学生借莞城校区的书(应该成功) ===' AS '测试步骤';
BEGIN TRY
    INSERT INTO Borrow(readerNumber, bookNumber, borrowDate, returnDeadline, adminNo)
    VALUES('R20230003', 'B20230005', '2025-03-31 13:10:32', 
    DATEADD(day, 30, '2025-03-31 13:10:32'), '123jianzhu');
    
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230003', 'B20230005', '2025-03-31 13:10:32', 1, NULL);
    
    SELECT '测试3结果: 借阅成功' AS '执行结果';
END TRY
BEGIN CATCH
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230003', 'B20230005', '2025-03-31 13:10:32', 0, ERROR_MESSAGE());
    
    SELECT '测试3结果: 借阅失败' AS '执行结果';
    SELECT '错误信息: ' + ERROR_MESSAGE() AS '错误详情';
END CATCH

-- 6. 测试4: 莞城校区学生借松山湖校区的书(应该失败)
SELECT '=== 测试4: 莞城校区学生借松山湖校区的书(应该失败) ===' AS '测试步骤';
BEGIN TRY
    INSERT INTO Borrow(readerNumber, bookNumber, borrowDate, returnDeadline, adminNo)
    VALUES('R20230003', 'B20230001', '2025-03-31 13:10:32', 
    DATEADD(day, 30, '2025-03-31 13:10:32'), '123jianzhu');
    
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230003', 'B20230001', '2025-03-31 13:10:32', 1, NULL);
    
    SELECT '测试4结果: 借阅成功（不应该出现此结果）' AS '执行结果';
END TRY
BEGIN CATCH
    INSERT INTO #BorrowAttempts(readerNumber, bookNumber, attemptTime, isSuccess, errorMessage)
    VALUES('R20230003', 'B20230001', '2025-03-31 13:10:32', 0, ERROR_MESSAGE());
    
    SELECT '测试4结果: 借阅失败' AS '执行结果';
    SELECT '错误信息: ' + ERROR_MESSAGE() AS '错误详情';
END CATCH

-- 7. 显示完整的测试结果（包括成功和失败的尝试）
SELECT '=== 所有借阅尝试结果汇总 ===' AS '测试步骤';

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

-- 8. 显示当前图书库存状态
SELECT '=== 当前图书库存状态 ===' AS '测试步骤';

SELECT 
    bookNumber as '图书编号',
    bookName as '图书名称',
    stackRoom as '所在书库',
    totalCount as '总数量',
    currentCount as '当前可借数量'
FROM Book
WHERE bookNumber IN ('B20230001', 'B20230005');

-- 9. 显示权限规则
SELECT '=== 当前系统权限规则 ===' AS '测试步骤';

SELECT 
    rt.readerType as '读者类型',
    rt.borrowRange as '允许借阅范围',
    rt.maxCount as '最大借阅数量',
    rt.dateDeadline as '借阅期限(天)'
FROM ReaderType rt
ORDER BY rt.readerType;

-- 删除临时表
DROP TABLE #BorrowAttempts;