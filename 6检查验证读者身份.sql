-- 1. 首先检查表结构
SELECT COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Administrator';

-- 2. 只添加缺失的字段
-- 修改Reader表，添加密码和状态字段（如果不存在）
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Reader') AND name = 'readerPassword')
BEGIN
    ALTER TABLE Reader
    ADD readerPassword varchar(50);
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Reader') AND name = 'readerStatus')
BEGIN
    ALTER TABLE Reader
    ADD readerStatus varchar(20) DEFAULT '正常';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Administrator') AND name = 'adminStatus')
BEGIN
    ALTER TABLE Administrator
    ADD adminStatus varchar(20) DEFAULT '在职';
END

-- 3. 为现有用户添加测试密码（如果需要）
UPDATE Reader
SET readerPassword = 'password123',
    readerStatus = '正常'
WHERE readerNumber IN ('R20230001', 'R20230002', 'R20230003');

UPDATE Administrator
SET adminStatus = '在职'
WHERE adminNo = '123jianzhu';

-- 4. 修改后的登录验证存储过程
CREATE OR ALTER PROCEDURE sp_user_login
    @userType varchar(20),    -- 'reader' 或 'admin'
    @userId char(10),
    @password varchar(50),
    @currentTime datetime,
    @sessionId uniqueidentifier OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @sessionId = NEWID();

    -- 根据用户类型验证登录
    IF @userType = 'reader'
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM Reader 
            WHERE readerNumber = @userId 
            AND readerPassword = @password
            AND readerStatus = '正常'
        )
        BEGIN
            INSERT INTO UserLoginLog(userType, userId, loginTime, loginStatus, sessionId)
            VALUES('reader', @userId, @currentTime, '成功', @sessionId);

            SELECT 
                r.readerNumber,
                r.userName,
                r.readerType,
                @sessionId as sessionId,
                'SUCCESS' as loginResult,
                '读者登录成功' as message
            FROM Reader r
            WHERE r.readerNumber = @userId;
            RETURN;
        END
    END
    ELSE IF @userType = 'admin'
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM Administrator 
            WHERE adminNo = @userId 
            AND adminPassword = @password
            AND adminStatus = '在职'
        )
        BEGIN
            INSERT INTO UserLoginLog(userType, userId, loginTime, loginStatus, sessionId)
            VALUES('admin', @userId, @currentTime, '成功', @sessionId);

            SELECT 
                a.adminNo,
                a.adminName,
                @sessionId as sessionId,
                'SUCCESS' as loginResult,
                '管理员登录成功' as message
            FROM Administrator a
            WHERE a.adminNo = @userId;
            RETURN;
        END
    END

    -- 登录失败
    INSERT INTO UserLoginLog(userType, userId, loginTime, loginStatus, sessionId)
    VALUES(@userType, @userId, @currentTime, '失败', @sessionId);

    SELECT 
        NULL as userId,
        NULL as userName,
        NULL as sessionId,
        'FAILED' as loginResult,
        '用户名或密码错误' as message;
END;
GO

-- 5. 测试登录功能
DECLARE @currentTime datetime = '2025-04-01 01:27:03';
DECLARE @readerSessionId uniqueidentifier;
DECLARE @adminSessionId uniqueidentifier;

-- 读者登录测试
EXEC sp_user_login 'reader', 'R20230001', 'password123', @currentTime, @readerSessionId OUTPUT;

-- 管理员登录测试
EXEC sp_user_login 'admin', '123jianzhu', '123456', @currentTime, @adminSessionId OUTPUT;

-- 查看登录日志
SELECT 
    userType as '用户类型',
    userId as '用户ID',
    loginTime as '登录时间',
    logoutTime as '登出时间',
    loginStatus as '登录状态',
    sessionId as '会话ID'
FROM UserLoginLog
ORDER BY loginTime DESC;