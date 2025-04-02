-- 创建存储过程以查询某个读者的所有借书记录
CREATE PROCEDURE sp_get_reader_borrow_records
    @readerNumber char(10)
AS
BEGIN
    SET NOCOUNT ON;

    -- 查询该读者的所有借书记录
    SELECT 
        r.userName as '读者姓名',
        r.readerNumber as '读者编号',
        b.bookName as '图书名称',
        bo.bookNumber as '图书编号',
        CONVERT(varchar, bo.borrowDate, 120) as '借阅时间',
        CONVERT(varchar, bo.returnDeadline, 120) as '应还时间',
        CASE 
            WHEN rb.returnId IS NOT NULL THEN '已还'
            WHEN GETDATE() > bo.returnDeadline THEN '已超期'
            ELSE '借阅中'
        END as '借阅状态'
    FROM Borrow bo
    JOIN Reader r ON bo.readerNumber = r.readerNumber
    JOIN Book b ON bo.bookNumber = b.bookNumber
    LEFT JOIN ReturnBook rb ON bo.borrowId = rb.borrowId
    WHERE r.readerNumber = @readerNumber
    ORDER BY bo.borrowDate DESC;
END;
GO


-- 查询某个读者的所有借书记录
EXEC sp_get_reader_borrow_records @readerNumber = 'R20230001';



-- 修改存储过程，添加管理员身份验证
CREATE OR ALTER PROCEDURE sp_get_reader_borrow_records
    @adminNo char(10),            -- 管理员编号
    @adminSessionId uniqueidentifier,  -- 管理员会话ID
    @readerNumber char(10),       -- 要查询的读者编号
    @currentTime datetime         -- 当前时间
AS
BEGIN
    SET NOCOUNT ON;

    -- 首先验证管理员身份
    IF NOT EXISTS (
        SELECT 1 
        FROM UserLoginLog 
        WHERE userType = 'admin'
        AND userId = @adminNo 
        AND sessionId = @adminSessionId
        AND loginStatus = '成功'
        AND logoutTime IS NULL
        AND DATEDIFF(HOUR, loginTime, @currentTime) < 24
    )
    BEGIN
        -- 如果验证失败，返回错误信息
        RAISERROR ('管理员未登录或会话已过期，请重新登录', 16, 1);
        RETURN;
    END

    -- 验证通过后，查询读者借书记录
    SELECT 
        '=== 读者基本信息 ===' as '信息类型';

    -- 显示读者基本信息
    SELECT 
        r.readerNumber as '读者编号',
        r.userName as '读者姓名',
        r.readerType as '读者类型',
        rt.maxCount as '最大可借数量',
        rt.dateDeadline as '借阅期限(天)'
    FROM Reader r
    JOIN ReaderType rt ON r.readerType = rt.readerType
    WHERE r.readerNumber = @readerNumber;

    SELECT 
        '=== 借阅记录明细 ===' as '信息类型';

    -- 显示借阅记录
    SELECT 
        b.bookName as '图书名称',
        bo.bookNumber as '图书编号',
        b.stackRoom as '所在书库',
        CONVERT(varchar, bo.borrowDate, 120) as '借阅时间',
        CONVERT(varchar, bo.returnDeadline, 120) as '应还时间',
        CASE 
            WHEN rb.returnId IS NOT NULL THEN 
                '已还 - ' + CONVERT(varchar, rb.returnDate, 120)
            WHEN @currentTime > bo.returnDeadline THEN 
                '已超期' + CAST(DATEDIFF(day, bo.returnDeadline, @currentTime) as varchar) + '天'
            ELSE '借阅中'
        END as '借阅状态',
        a.adminName as '经办管理员'
    FROM Borrow bo
    JOIN Reader r ON bo.readerNumber = r.readerNumber
    JOIN Book b ON bo.bookNumber = b.bookNumber
    JOIN Administrator a ON bo.adminNo = a.adminNo
    LEFT JOIN ReturnBook rb ON bo.borrowId = rb.borrowId
    WHERE r.readerNumber = @readerNumber
    ORDER BY bo.borrowDate DESC;

    -- 显示统计信息
    SELECT 
        '=== 借阅统计信息 ===' as '信息类型';

    SELECT 
        COUNT(bo.borrowId) as '总借阅次数',
        SUM(CASE WHEN rb.returnId IS NULL THEN 1 ELSE 0 END) as '当前在借数量',
        SUM(CASE 
            WHEN rb.returnId IS NULL AND @currentTime > bo.returnDeadline THEN 1 
            ELSE 0 
        END) as '逾期未还数量'
    FROM Borrow bo
    LEFT JOIN ReturnBook rb ON bo.borrowId = rb.borrowId
    WHERE bo.readerNumber = @readerNumber;
END;
GO

-- 使用示例：先进行管理员登录
DECLARE @adminNo char(10) = '123jianzhu';
DECLARE @currentTime datetime = '2025-04-02 02:46:34';
DECLARE @adminSessionId uniqueidentifier;

-- 管理员登录
EXEC sp_user_login 'admin', @adminNo, '123456', @currentTime, @adminSessionId OUTPUT;

-- 使用登录成功后的会话ID查询读者借书记录
IF @adminSessionId IS NOT NULL
BEGIN
    -- 查询指定读者的借书记录
    EXEC sp_get_reader_borrow_records 
        @adminNo = '123jianzhu',
        @adminSessionId = @adminSessionId,
        @readerNumber = 'R20230001',
        @currentTime = '2025-04-02 02:46:34';
END
ELSE
BEGIN
    PRINT '管理员登录失败，无法查询读者借书记录';
END;
