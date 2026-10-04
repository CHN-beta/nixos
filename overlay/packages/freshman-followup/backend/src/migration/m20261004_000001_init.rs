use chrono::Datelike;
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let db = manager.get_connection();

        // 1. 创建核心数据表
        db.execute_unprepared(
            r#"
            -- 1. 账号表
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(64) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL
            );

            -- 2. 可选排班日期表
            CREATE TABLE IF NOT EXISTS available_dates (
                date DATE PRIMARY KEY,
                is_active BOOLEAN NOT NULL DEFAULT TRUE
            );

            -- 3. 老师排班表 (08:00 - 22:00, 28 slots, 8 columns)
            CREATE TABLE IF NOT EXISTS teacher_schedules (
                id SERIAL PRIMARY KEY,
                date DATE NOT NULL,
                slot_index SMALLINT NOT NULL CHECK (slot_index >= 0 AND slot_index < 28),
                column_index SMALLINT NOT NULL CHECK (column_index >= 0 AND column_index < 8),
                teacher_name VARCHAR(32) NOT NULL,
                student_id VARCHAR(64) DEFAULT NULL,

                CONSTRAINT uk_date_slot_teacher UNIQUE (date, slot_index, teacher_name),
                CONSTRAINT uk_date_slot_column UNIQUE (date, slot_index, column_index)
            );

            CREATE INDEX IF NOT EXISTS idx_schedules_date ON teacher_schedules(date);

            -- 4. 学生名单表
            CREATE TABLE IF NOT EXISTS students (
                id VARCHAR(64) PRIMARY KEY,
                name VARCHAR(64) NOT NULL,
                student_no VARCHAR(32) NOT NULL,
                phone VARCHAR(32) NOT NULL,
                college VARCHAR(64) NOT NULL,
                status VARCHAR(32) NOT NULL DEFAULT '未联系'
                    CHECK (status IN ('未联系', '空号', '未接通', '拒绝回访', '暂时没空', '成功预约', '其它')),
                remarks TEXT NOT NULL DEFAULT '',
                schedule_id INT DEFAULT NULL,
                updated_by VARCHAR(64) DEFAULT NULL,
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                CONSTRAINT chk_status_schedule CHECK (
                    (status = '成功预约' AND schedule_id IS NOT NULL) OR
                    (status <> '成功预约' AND schedule_id IS NULL)
                )
            );

            CREATE INDEX IF NOT EXISTS idx_students_college ON students(college);
            CREATE INDEX IF NOT EXISTS idx_students_status ON students(status);

            -- 5. 通用操作审计日志表
            CREATE TABLE IF NOT EXISTS operation_logs (
                id SERIAL PRIMARY KEY,
                user_name VARCHAR(64),
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                event JSONB NOT NULL
            );
            "#,
        )
        .await?;

        // 2. 插入初始用户账号 (密码 admin123 / 123456)
        db.execute_unprepared(
            r#"
            INSERT INTO users (username, password_hash)
            VALUES
                ('admin', '$2b$12$K1V5P3Zf8P0f6bHhHkZfCeJc9k4jN4V3vXwW5X4vV6zU7iYyUeC9u'),
                ('assistant1', '$2b$12$K1V5P3Zf8P0f6bHhHkZfCeJc9k4jN4V3vXwW5X4vV6zU7iYyUeC9u')
            ON CONFLICT (username) DO NOTHING;
            "#,
        )
        .await?;

        // 3. 计算本月 11, 17, 18, 24, 25 日
        let now = chrono::Local::now().date_naive();
        let year = now.year();
        let month = now.month();

        let date_11 = format!("{:04}-{:02}-11", year, month);
        let date_17 = format!("{:04}-{:02}-17", year, month);
        let date_18 = format!("{:04}-{:02}-18", year, month);
        let date_24 = format!("{:04}-{:02}-24", year, month);
        let date_25 = format!("{:04}-{:02}-25", year, month);

        let insert_dates_sql = format!(
            r#"
            INSERT INTO available_dates (date, is_active)
            VALUES
                ('{d11}', TRUE),
                ('{d17}', TRUE),
                ('{d18}', TRUE),
                ('{d24}', TRUE),
                ('{d25}', TRUE)
            ON CONFLICT (date) DO NOTHING;
            "#,
            d11 = date_11,
            d17 = date_17,
            d18 = date_18,
            d24 = date_24,
            d25 = date_25,
        );
        db.execute_unprepared(&insert_dates_sql).await?;

        // 4. 插入老师排班：只在 11 日给他们几个排班（张三老师、王五老师等）
        let insert_schedules_sql = format!(
            r#"
            INSERT INTO teacher_schedules (date, slot_index, column_index, teacher_name)
            VALUES
                ('{d11}', 0, 0, '张三老师'),
                ('{d11}', 1, 0, '张三老师'),
                ('{d11}', 2, 0, '张三老师'),
                ('{d11}', 0, 1, '李四老师'),
                ('{d11}', 1, 1, '李四老师'),
                ('{d11}', 4, 2, '王五老师'),
                ('{d11}', 5, 2, '王五老师'),
                ('{d11}', 6, 2, '王五老师'),
                ('{d11}', 8, 3, '赵六老师'),
                ('{d11}', 9, 3, '赵六老师')
            ON CONFLICT DO NOTHING;
            "#,
            d11 = date_11,
        );
        db.execute_unprepared(&insert_schedules_sql).await?;

        // 5. 插入几个学生（全部为未联系）
        db.execute_unprepared(
            r#"
            INSERT INTO students (id, name, student_no, phone, college, status, remarks)
            VALUES
                ('STU2026001', '陈思远', '2302026001', '13800000001', '信息学院', '未联系', ''),
                ('STU2026002', '林雨桐', '2302026002', '13800000002', '信息学院', '未联系', ''),
                ('STU2026003', '黄俊杰', '2302026003', '13800000003', '化学化工学院', '未联系', ''),
                ('STU2026004', '张若曦', '2302026004', '13800000004', '经济学院', '未联系', ''),
                ('STU2026005', '王梓涵', '2302026005', '13800000005', '管理学院', '未联系', ''),
                ('STU2026006', '刘子轩', '2302026006', '13800000006', '医学院', '未联系', ''),
                ('STU2026007', '吴佳琪', '2302026007', '13800000007', '法学院', '未联系', ''),
                ('STU2026008', '周皓轩', '2302026008', '13800000008', '物理科学与技术学院', '未联系', '')
            ON CONFLICT (id) DO NOTHING;
            "#,
        )
        .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let db = manager.get_connection();
        db.execute_unprepared(
            r#"
            DROP TABLE IF EXISTS operation_logs;
            DROP TABLE IF EXISTS students;
            DROP TABLE IF EXISTS teacher_schedules;
            DROP TABLE IF EXISTS available_dates;
            DROP TABLE IF EXISTS users;
            "#,
        )
        .await?;
        Ok(())
    }
}
