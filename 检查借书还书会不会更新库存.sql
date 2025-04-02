
-- 1. 首先查看初始库存状态
SELECT bookNumber, bookName, totalCount, currentCount
FROM Book
WHERE bookNumber IN ('B20230001', 'B20230002');

-- 2. 执行借书操作
INSERT INTO Borrow(readerNumber, bookNumber, borrowDate, returnDeadline, adminNo)
VALUES
('R20230001', 'B20230001', '2025-03-31 12:50:11', 
DATEADD(day, 30, '2025-03-31 12:50:11'), '123jianzhu');

-- 3. 检查借书后的库存变化
SELECT bookNumber, bookName, totalCount, currentCount
FROM Book
WHERE bookNumber IN ('B20230001', 'B20230002');

-- 4. 执行还书操作
INSERT INTO ReturnBook(borrowId, returnDate, adminNo)
SELECT borrowId, '2025-03-31 13:00:11', '123jianzhu'
FROM Borrow
WHERE bookNumber = 'B20230001'
AND readerNumber = 'R20230001'
AND NOT EXISTS (SELECT 1 FROM ReturnBook rb WHERE rb.borrowId = Borrow.borrowId);

-- 5. 检查还书后的库存变化
SELECT bookNumber, bookName, totalCount, currentCount
FROM Book
WHERE bookNumber IN ('B20230001', 'B20230002');

-- 6. 显示完整的借还记录和库存变化
SELECT 
    b.bookNumber as '图书编号',
    b.bookName as '图书名称',
    b.totalCount as '总库存',
    b.currentCount as '当前可借',
    bo.borrowDate as '借出时间',
    rb.returnDate as '归还时间',
    r.userName as '借阅人',
    a.adminName as '操作员'
FROM Book b
LEFT JOIN Borrow bo ON b.bookNumber = bo.bookNumber
LEFT JOIN ReturnBook rb ON bo.borrowId = rb.borrowId
LEFT JOIN Reader r ON bo.readerNumber = r.readerNumber
LEFT JOIN Administrator a ON bo.adminNo = a.adminNo
WHERE b.bookNumber IN ('B20230001', 'B20230002')
ORDER BY bo.borrowDate DESC;

-- 7. 显示图书操作日志
SELECT 
    ab.operationDate as '操作时间',
    b.bookNumber as '图书编号',
    b.bookName as '图书名称',
    ab.operationType as '操作类型',
    ab.reason as '操作原因',
    a.adminName as '操作员'
FROM Admin_Book ab
JOIN Book b ON ab.bookNumber = b.bookNumber
JOIN Administrator a ON ab.adminNo = a.adminNo
WHERE b.bookNumber IN ('B20230001', 'B20230002')
ORDER BY ab.operationDate DESC;