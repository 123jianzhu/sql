/* ======================= 第五部分：功能测试查询 ======================= */

-- 1. 查看当前正在借阅的图书
SELECT 
    r.userName as '读者姓名',
    r.readerType as '读者类型',
    b.bookName as '图书名称',
    bo.borrowDate as '借阅日期',
    bo.returnDeadline as '应还日期',
    CASE 
        WHEN GETDATE() > bo.returnDeadline THEN '已逾期'
        ELSE '正常'
    END as '状态'
FROM Borrow bo
JOIN Reader r ON bo.readerNumber = r.readerNumber
JOIN Book b ON bo.bookNumber = b.bookNumber
WHERE NOT EXISTS (
    SELECT 1 FROM ReturnBook rb WHERE rb.borrowId = bo.borrowId
);

-- 2. 查看各书库的图书统计
SELECT 
    stackRoom as '书库',
    COUNT(*) as '图书种类',
    SUM(totalCount) as '总藏书量',
    SUM(currentCount) as '当前可借数量',
    SUM(totalCount - currentCount) as '借出数量'
FROM Book
GROUP BY stackRoom;

-- 3. 查看读者借阅历史
SELECT 
    r.userName as '读者姓名',
    r.readerType as '读者类型',
    b.bookName as '图书名称',
    CONVERT(varchar, bo.borrowDate, 120) as '借阅日期',
    CASE 
        WHEN rb.returnDate IS NULL THEN '未归还'
        ELSE CONVERT(varchar, rb.returnDate, 120)
    END as '归还日期',
    CASE 
        WHEN rb.returnDate IS NULL AND GETDATE() > bo.returnDeadline THEN '已逾期'
        WHEN rb.returnDate IS NULL THEN '借阅中'
        ELSE '已归还'
    END as '状态'
FROM Borrow bo
JOIN Reader r ON bo.readerNumber = r.readerNumber
JOIN Book b ON bo.bookNumber = b.bookNumber
LEFT JOIN ReturnBook rb ON bo.borrowId = rb.borrowId
ORDER BY r.userName, bo.borrowDate DESC;

-- 4. 查看图书操作日志
SELECT 
    ab.operationDate as '操作时间',
    a.adminName as '操作员',
    b.bookName as '图书名称',
    ab.operationType as '操作类型',
    ab.reason as '操作原因'
FROM Admin_Book ab
JOIN Administrator a ON ab.adminNo = a.adminNo
JOIN Book b ON ab.bookNumber = b.bookNumber
ORDER BY ab.operationDate DESC;

-- 5. 查看读者操作日志
SELECT 
    ar.operationDate as '操作时间',
    a.adminName as '操作员',
    r.userName as '读者姓名',
    ar.operationType as '操作类型',
    ar.reason as '操作原因',
    ar.approval as '审批状态'
FROM Admin_Reader ar
JOIN Administrator a ON ar.adminNo = a.adminNo
JOIN Reader r ON ar.readerNumber = r.readerNumber
ORDER BY ar.operationDate DESC;

-- 6. 查看各类型读者的借阅统计
SELECT 
    r.readerType as '读者类型',
    COUNT(DISTINCT r.readerNumber) as '读者人数',
    COUNT(bo.borrowId) as '借阅总次数',
    COUNT(rb.returnId) as '归还总次数',
    COUNT(bo.borrowId) - COUNT(rb.returnId) as '未归还数量'
FROM Reader r
LEFT JOIN Borrow bo ON r.readerNumber = bo.readerNumber
LEFT JOIN ReturnBook rb ON bo.borrowId = rb.borrowId
GROUP BY r.readerType;

-- 7. 检查逾期借阅
SELECT 
    r.userName as '读者姓名',
    r.readerType as '读者类型',
    b.bookName as '图书名称',
    bo.borrowDate as '借阅日期',
    bo.returnDeadline as '应还日期',
    DATEDIFF(day, bo.returnDeadline, GETDATE()) as '逾期天数'
FROM Borrow bo
JOIN Reader r ON bo.readerNumber = r.readerNumber
JOIN Book b ON bo.bookNumber = b.bookNumber
WHERE NOT EXISTS (
    SELECT 1 FROM ReturnBook rb WHERE rb.borrowId = bo.borrowId
)
AND GETDATE() > bo.returnDeadline
ORDER BY bo.returnDeadline;

-- 8. 查看热门图书（借阅次数最多）
SELECT TOP 10
    b.bookName as '图书名称',
    b.author as '作者',
    b.publisher as '出版社',
    b.stackRoom as '所在书库',
    COUNT(bo.borrowId) as '借阅次数'
FROM Book b
LEFT JOIN Borrow bo ON b.bookNumber = bo.bookNumber
GROUP BY b.bookNumber, b.bookName, b.author, b.publisher, b.stackRoom
ORDER BY COUNT(bo.borrowId) DESC;