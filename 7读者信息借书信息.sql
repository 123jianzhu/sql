-- 检查管理员登录状态
DECLARE @adminNo char(10) = '123jianzhu';
DECLARE @currentTime datetime = GETDATE();  -- 使用实时时间
DECLARE @adminSessionId uniqueidentifier;

-- 管理员登录
EXEC sp_user_login 'admin', @adminNo, '123456', @currentTime, @adminSessionId OUTPUT;

-- 首先打印标题
SELECT '=== 读者基本信息 ===' AS '信息类型';

-- 查询并显示读者基本信息
SELECT 
    r.readerNumber as '读者编号',
    r.userName as '姓名',
    r.readerType as '读者类型',
    rt.maxCount as '最大可借数量',
    rt.dateDeadline as '借阅期限(天)',
    rt.borrowRange as '允许借阅范围',
    CASE ISNULL(r.readerStatus, '正常')
        WHEN '正常' THEN '正常'
        ELSE '异常'
    END as '读者状态'
FROM Reader r
JOIN ReaderType rt ON r.readerType = rt.readerType
ORDER BY r.readerNumber;

-- 打印借阅信息标题
SELECT '=== 当前借阅信息 ===' AS '信息类型';

-- 查询并显示当前借阅信息
SELECT 
    r.userName as '读者姓名',
    r.readerNumber as '读者编号',
    b.bookName as '图书名称',
    b.bookNumber as '图书编号',
    b.stackRoom as '所在书库',
    CONVERT(varchar, bo.borrowDate, 120) as '借阅时间',
    CONVERT(varchar, bo.returnDeadline, 120) as '应还时间',
    CASE 
        WHEN rb.returnId IS NOT NULL THEN '已还'
        WHEN @currentTime > bo.returnDeadline THEN '已超期'
        ELSE '借阅中'
    END as '借阅状态'
FROM Borrow bo
JOIN Reader r ON bo.readerNumber = r.readerNumber
JOIN Book b ON bo.bookNumber = b.bookNumber
LEFT JOIN ReturnBook rb ON bo.borrowId = rb.borrowId
ORDER BY bo.borrowDate DESC;

-- 打印借阅统计信息
SELECT '=== 借阅统计信息 ===' AS '信息类型';

-- 查询每个读者的借阅统计
SELECT 
    r.userName as '读者姓名',
    r.readerNumber as '读者编号',
    r.readerType as '读者类型',
    COUNT(DISTINCT b.borrowId) as '总借阅次数',
    SUM(CASE WHEN rb.returnId IS NULL THEN 1 ELSE 0 END) as '当前在借数量',
    SUM(CASE 
        WHEN rb.returnId IS NULL AND @currentTime > b.returnDeadline THEN 1 
        ELSE 0 
    END) as '逾期未还数量'
FROM Reader r
LEFT JOIN Borrow b ON r.readerNumber = b.readerNumber
LEFT JOIN ReturnBook rb ON b.borrowId = rb.borrowId
GROUP BY r.userName, r.readerNumber, r.readerType
ORDER BY r.readerNumber;

-- 打印逾期图书信息
SELECT '=== 逾期图书信息 ===' AS '信息类型';

-- 查询逾期的借阅记录
SELECT 
    r.userName as '读者姓名',
    r.readerNumber as '读者编号',
    b.bookName as '图书名称',
    bo.bookNumber as '图书编号',
    CONVERT(varchar, bo.borrowDate, 120) as '借阅时间',
    CONVERT(varchar, bo.returnDeadline, 120) as '应还时间',
    DATEDIFF(day, bo.returnDeadline, @currentTime) as '逾期天数'
FROM Borrow bo
JOIN Reader r ON bo.readerNumber = r.readerNumber
JOIN Book b ON bo.bookNumber = b.bookNumber
LEFT JOIN ReturnBook rb ON bo.borrowId = rb.borrowId
WHERE rb.returnId IS NULL 
AND @currentTime > bo.returnDeadline
ORDER BY bo.returnDeadline;