# 新生回访系统 (Freshman Follow-up System) 架构与实施规范

## 1. 项目定位与技术栈

本系统面向厦目大学心理咨询中心新生回访与预约工作，提供学生助理使用的移动端优先回访与排班系统。

- **后端**：Rust (Axum + Sea-ORM)
- **数据库**：PostgreSQL
- **前端**：Vue 3 + Vite + Pinia + Vue Router + Tailwind CSS / 轻量移动端组件库
- **设计风格**：浅色背景（Light mode）、清爽极简、移动端优先（适配手机端触控、抽屉、弹窗与 PC 宽屏）

---

## 2. 数据库设计 (DDL)

```sql
-- 1. 账号表
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(64) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL
);

-- 2. 可选排班日期表（由管理员预先写入）
CREATE TABLE available_dates (
    date DATE PRIMARY KEY,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3. 老师排班表
-- 08:00 - 22:00，每 30 分钟一个 slot，全天共 28 个 slot (0..27)
-- slot 0: 08:00-08:30 ... slot 27: 21:30-22:00
CREATE TABLE teacher_schedules (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    slot_index SMALLINT NOT NULL CHECK (slot_index >= 0 AND slot_index < 28),
    teacher_name VARCHAR(32) NOT NULL,
    student_id VARCHAR(64) DEFAULT NULL, -- NULL 为空闲；非 NULL 表示已被该学生预约

    CONSTRAINT uk_date_slot_teacher UNIQUE (date, slot_index, teacher_name)
);

CREATE INDEX idx_schedules_date ON teacher_schedules(date);

-- 4. 学生名单表
CREATE TABLE students (
    id VARCHAR(64) PRIMARY KEY,       -- 原始导入编号 (UTF-8)
    name VARCHAR(64) NOT NULL,
    student_no VARCHAR(32) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    college VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT '未联系' 
        CHECK (status IN ('未联系', '空号', '拒绝回访', '暂时没空', '成功预约', '其它')),
    remarks TEXT NOT NULL DEFAULT '', -- 无论何种状态均可填写的备注
    schedule_id INT DEFAULT NULL,    -- 逻辑关联 teacher_schedules.id
    updated_by VARCHAR(64) DEFAULT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 状态与排班强一致性约束
    CONSTRAINT chk_status_schedule CHECK (
        (status = '成功预约' AND schedule_id IS NOT NULL) OR
        (status <> '成功预约' AND schedule_id IS NULL)
    )
);

CREATE INDEX idx_students_college ON students(college);
CREATE INDEX idx_students_status ON students(status);

-- 5. 通用操作审计日志表
CREATE TABLE operation_logs (
    id SERIAL PRIMARY KEY,
    user_name VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event JSONB NOT NULL
);
```

---

## 3. 核心交互与业务逻辑

### 3.1 账号与鉴权
- 无注册、无修改密码、无后台用户管理 UI，账号密码由管理员通过 SQL 导入。
- 助理权限平权。
- 登录返回 Token（载荷 `username`），请求头携带 Token，中间件解析 `username` 并存入请求上下文。
- 任何数据写操作必须在 `operation_logs` 中插入一条审计记录（包含操作人、时间、变更详情 JSONB）。

### 3.2 老师排班模块
- 日期下拉：取 `available_dates` 中激活的日期（业务上预设两个周末，共 4 天可选）。
- 时间轴布局：**页面纵轴**整齐排列全天 28 个半小时时段（08:00 - 22:00，半小时一档）。
- 单个时段硬编码上限 8 位老师。
- 老师标签颜色算法：名字字符串哈希转 HSL（色相 0~359，饱和度 70%，亮度 50%），确保非灰、非黑、非白。
- 排班操作与防误删保护：点击时段格子弹窗增加或删除排班；**已经有预约的排班不可被删除**（`student_id IS NOT NULL` 时禁用并拦截删除）。

### 3.3 学生预约与状态流转
- 学生列表展示：姓名、学号、手机号（支持一键拨号 `tel:` 协议）、学院、状态、备注。
- 检索与筛选：支持按学院、按状态筛选，支持输入**姓名/学号/编号**快速搜索。
- 状态修改规则与二次确认：
  - 点击状态按钮弹出选项（未联系、空号、拒绝回访、暂时没空、其它、成功预约），选择后弹窗二次确认。
  - **成功预约强绑定**：选择“成功预约”时，界面唤起排班选择器，必须选定一位空闲老师排班后方可确认提交（若未选排班禁止保存）。
  - **预约改期与自动解绑**：若学生后续状态变更（如从“成功预约”改为“暂时没空”或改选其他时间段），在同一个事务中**自动释放原占用的老师排班**（将其 `student_id` 置回 NULL 恢复为空闲），以供其他助理即刻选用。
- 排班选择器交互：
  - 结构同排班表，已预约老师强制渲染为浅灰（`#D1D5DB`）且不可点击；未预约老师渲染专属颜色，点击即可选中。
  - 选中某老师时段后弹出确认框：“确认将学生 [xxx] 预约在 [日期 时段 老师] 吗？”，确认后原子提交。
  - 原子占用排班：`UPDATE teacher_schedules SET student_id = $id WHERE id = $schedule_id AND student_id IS NULL`。若影响行数为 0，说明被并发抢占，报错拦截。
- 备注修改：所有学生均可随时编辑并独立提交文本备注。
